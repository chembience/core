{{- define "chembience.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "chembience.fullname" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else }}{{ printf "%s-%s" .Release.Name (include "chembience.name" .) | trunc 63 | trimSuffix "-" }}{{- end }}
{{- end }}
{{- define "chembience.labels" -}}
app.kubernetes.io/name: {{ include "chembience.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
chembience.io/environment: production
{{- end }}
{{- define "chembience.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chembience.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "chembience.appName" -}}{{ printf "%s-app" (include "chembience.fullname" .) | trunc 63 | trimSuffix "-" }}{{- end }}
{{- define "chembience.appConfigName" -}}{{ printf "%s-config" (include "chembience.fullname" . | trunc 56 | trimSuffix "-") }}{{- end }}
{{- define "chembience.postgresName" -}}{{ printf "%s-postgres" (include "chembience.fullname" .) | trunc 63 | trimSuffix "-" }}{{- end }}
{{- define "chembience.migrationName" -}}{{ printf "%s-migrate-%s" (include "chembience.fullname" . | trunc 46 | trimSuffix "-") (.Values.app.image.tag | sha256sum | trunc 8) }}{{- end }}
{{- define "chembience.postgresHost" -}}{{ if .Values.postgres.enabled }}{{ include "chembience.postgresName" . }}{{ else }}{{ required "postgres.host is required when postgres.enabled=false" .Values.postgres.host }}{{ end }}{{- end }}
{{- define "chembience.appPort" -}}{{ if eq .Values.app.kind "jupyter" }}8888{{ else }}8000{{ end }}{{- end }}
{{- define "chembience.image" -}}{{ printf "%s:%s" .repository .tag }}{{- end }}
