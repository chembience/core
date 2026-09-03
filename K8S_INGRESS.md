# Exposing a Chembience app over HTTPS

This guide connects a Chembience application deployed with `PROD/k8s/` to a
public domain such as `indigo.chembience.com`.

## Overview

```text
Internet → Ingress controller → Chembience Service → application pod
                    ↑
              cert-manager obtains and renews TLS certificates
```

The application chart creates an internal Kubernetes Service. An Ingress
controller is the shared cluster component that accepts public HTTP/HTTPS
traffic and routes it to that Service. cert-manager is the cluster component
that obtains and renews Let's Encrypt certificates.

Use a separate hostname for each application when possible, for example
`indigo.chembience.com` and `notebooks.chembience.com`.

## 1. Check the cluster first

Do not install a second Ingress controller if the cluster already has one.

```bash
kubectl get ingressclass
kubectl get pods -A | grep -Ei 'ingress|traefik'
kubectl get svc -A | grep -E 'LoadBalancer|NodePort'
```

The IngressClass name shown here is the value used as `ingress.className` in
the application configuration. Common names are `traefik` and `nginx`.

## 2. Install an Ingress controller if needed

For a managed/cloud cluster, Traefik is a straightforward choice:

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update

helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --wait
```

Check its public address:

```bash
kubectl -n traefik get service
kubectl get ingressclass
```

The Traefik Service needs an `EXTERNAL-IP`, not `<pending>`. Point the DNS
record for the application hostname at this address. Ports 80 and 443 must be
reachable from the internet.

On a self-hosted/bare-metal cluster, Kubernetes does not create an external
load balancer by itself. Provide one before continuing, for example through
MetalLB or an existing router/load balancer that forwards ports 80 and 443 to
the cluster. K3s, MicroK8s, and managed platforms may already provide this
piece.

Do not expose the Traefik dashboard publicly unless it is explicitly secured.

## 3. Install cert-manager

First check whether cert-manager is already present:

```bash
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager
```

If it is not installed:

```bash
helm upgrade --install cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait
```

cert-manager watches application Ingresses, requests certificates, stores the
certificate and private key in Kubernetes Secrets, and renews certificates
automatically.

## 4. Create the Let's Encrypt issuer

Create this once per cluster. Replace the email address and `nginx` with the
actual IngressClass name from step 1.

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: YOUR_EMAIL@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: nginx
EOF
```

The `ClusterIssuer` is a cluster-wide instruction for cert-manager: use Let's
Encrypt, identify the account with the email address, and prove domain control
using HTTP on port 80. cert-manager creates temporary challenge routes under
`/.well-known/acme-challenge/` during issuance.

Verify it:

```bash
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

## 5. Configure and deploy the application

Edit `PROD/k8s/values.override.yaml` for the application. Replace the hostname,
IngressClass, and Secret name as appropriate:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  host: indigo.chembience.com
  tls:
    enabled: true
    secretName: indigo-chembience-com-tls
```

For Django, also configure its public hostname and browser origin:

```yaml
django:
  virtualHostname: indigo.chembience.com
  csrfTrustedOrigins: https://indigo.chembience.com
  trustXForwardedProto: true
```

Deploy from the generated application directory:

```bash
cd PROD/k8s
helm upgrade --install <project-name> ./chart \
  --namespace chembience --create-namespace \
  -f values.generated.yaml -f values.override.yaml
```

cert-manager creates the configured TLS Secret in the `chembience` namespace;
the Ingress controller uses it to terminate HTTPS and route traffic to the app.

## 6. Check certificate issuance

```bash
kubectl -n chembience get certificate,certificaterequest,order,challenge
kubectl -n chembience describe certificate indigo-chembience-com-tls
```

If issuance fails, first confirm that DNS resolves to the Ingress controller's
public address and that HTTP port 80 is reachable from the internet.

## References

- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Traefik Helm chart](https://github.com/traefik/traefik-helm-chart)
- [cert-manager installation](https://cert-manager.io/docs/installation/)
- [cert-manager HTTP-01 validation](https://cert-manager.io/docs/configuration/acme/http01/)
- [cert-manager Ingress integration](https://cert-manager.io/docs/usage/ingress/)
