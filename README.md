# Chembience

Chembience is a specialized platform for chemical informatics, using Django for the web interface and API, and RDKit for chemical data processing.

## Prerequisites

- **Docker**: Version 20.10.0 or higher
- **Docker Compose**: Version 2.0.0 or higher
- **Bash**: (Linux/macOS/WSL2)

## Major Software Libraries

- **Python**: 3.14
- **RDKit**: 2026.03.2
- **PostgreSQL**: 18 (PostGIS/rdkit-ready)
- **Django**: 5.x
- **SQLAlchemy**: latest
- **FastAPI**: latest
- **JupyterLab**: latest
- **django-rdkit**: latest (GitHub)
- **razi**: latest (GitHub)


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
    - `<type>`: `django`, `fastapi` or `rdkit`
    - `<target>`: Name of your application (e.g., `myapp`)

    Example:
    ```bash
    ./build django myapp
    ```
    or
    ```bash
    ./build fastapi myapp
    ```

    By default, the application is created in `~/myapp`. You can specify a custom directory with the `-d` option:
    ```bash
    ./build django myapp -d /path/to/parent_dir
    ```
    This will create the app in `/path/to/parent_dir/myapp`.

## Common Commands

Running from the `core/` directory:

- **Remove an application**:
  ```bash
  ./remove <target>
  ```
  If you used a custom directory:
  ```bash
  ./remove <target> -d /path/to/parent_dir
  ```

## Development

For more detailed information, see:
- [CLAUDE.md](https://github.com/chembience/chembience/blob/main/core/CLAUDE.md): Development guide and common commands.
- [AGENTS.md](https://github.com/chembience/chembience/blob/main/core/AGENTS.md): Information for AI agents and high-level overview.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](https://github.com/chembience/chembience/blob/main/core/LICENSE) file for details.
