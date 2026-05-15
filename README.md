# Chembience

Chembience is a specialized platform for chemical informatics, using Django for the web interface and API, and RDKit for chemical data processing.

## Prerequisites

- Docker and Docker Compose
- Bash (Linux/macOS/WSL2)

## Installation & Setup

1.  **Clone the repository.**
2.  **Navigate to the `core/` directory:**
    ```bash
    cd core
    ```
3.  **Build and setup an application:**
    ```bash
    ./build <type> <target>
    ```
    - `<type>`: `django` or `rdkit`
    - `<target>`: Name of your application (e.g., `myapp`)

    Example:
    ```bash
    ./build django myapp
    ```

    By default, the application is created in `~/myapp`. You can specify a custom directory with the `-d` option:
    ```bash
    ./build django myapp -d /path/to/parent_dir
    ```
    This will create the app in `/path/to/parent_dir/myapp`.

## Common Commands

Running from the `core/` directory:

- **Start services**: `docker compose up -d`
- **Stop services**: `docker compose down`
- **View logs**: `docker compose logs -f`
- **Remove an application**:
  ```bash
  ./remove <target>
  ```
  If you used a custom directory:
  ```bash
  ./remove <target> -d /path/to/parent_dir
  ```
- **Run Django management commands**:
  ```bash
  docker compose exec django python manage.py <command>
  ```
- **Shell access**:
  - Django: `docker compose exec django /bin/bash`
  - RDKit: `docker compose exec rdkit /bin/bash`

## Development

For more detailed information, see:
- [CLAUDE.md](CLAUDE.md): Development guide and common commands.
- [AGENTS.md](AGENTS.md): Information for AI agents and high-level overview.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.
