# Chembience Django Application

This is the web service for your Chembience project. It is built using Django and integrated with RDKit for chemical informatics.

## Directory Structure

- `src/`: The main Django project directory.
- `django-init`: Helper script for initializing the application.
- `django-manage-py`: Wrapper for Django's `manage.py`.
- `psql`: Helper script for accessing the PostgreSQL database.
- `requirements.txt`: Python dependencies for this service.

## Getting Started

For initial setup (optional):

```bash
./django-init
```

To run Django management commands:
```bash
docker compose exec django python manage.py <command>
```

or as a shortcut
```bash
./django-manage-py <command>
```

To access the database:
```bash
./psql
```

For more information, see the root [README.md](https://github.com/chembience/chembience/blob/main/README.md).
