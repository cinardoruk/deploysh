# Deployment and Syncing Script

This script automates key deployment and syncing tasks for managing a web project. It supports database synchronization, file transfers, server preparation, and more, making it a valuable tool for efficient project management and deployment.

---

## Features

- **Database Synchronization**:
  - Creates a local database dump.
  - Transfers the dump to a remote server.
  - Restores the database on the remote server, ensuring consistency.

- **File Synchronization**:
  - Syncs static and media files to the remote server using `rsync`.
  - Ensures all assets are up-to-date and organized.

- **Server Preparation**:
  - Automates the setup of a fresh server for production.
  - Installs necessary packages, configures firewalls, and optimizes server settings.

- **Interactive Confirmation**:
  - Prompts users for confirmation before executing critical steps, reducing the risk of accidental changes.

- **Modular Design**:
  - Supports running specific functions (e.g., syncing files or preparing the server) via command-line arguments.

- **Non-Interactive Mode**:
  - Allows full automation for CI/CD pipelines and cron jobs.

---

## Usage

### Run the Script
The script supports multiple tasks, which can be run individually or combined:

```
	Usage: $0 [OPTIONS]
	Options:
	prepare_server  Prepare fresh server for deployment

	dump            Create database dump
	transfer        Transfer dump to remote host
	restore         Restore database on remote host

	sync_env        Sync .env files
	sync_static     Sync static files
	sync_media      Sync media files
	sync_email      Sync email files
	sync_all        Sync all files
	WARNING: sync uses rsync with the --delete option. State of input/source dirs will replace the state of remote dirs. e.g sync_media will remove images on the remote media dir which are not on the local media dir

	all             Run all steps (dump, transfer, restore, sync_all)
	help            Display this help message

	!!! Make sure to fill out the variables in deploy.env !!!
```

## Examples

* Prepare a fresh server:
`
	./deploy.sh prepare
`
* Sync the database and files:
`
	./deploy.sh dump transfer restore sync
`
* Run all tasks:
`
	./deploy.sh all
`
* Enable non-interactive mode:
`
	./deploy.sh --non-interactive all
`
## Configuration

Update the following variables in deploy.env to match your project setup:
* Database Configuration
`
	DB_CONTAINER_NAME="your-container-name"
	DB_NAME="your-database-name"
	DB_USER="your-database-user"
	DUMP_FILE="db_dump_$(date +%Y%m%d%H%M).sql"
`
* Remote Server Configuration
`
	REMOTE_HOST="your-remote-host"
	REMOTE_DIR="/path/to/remote/directory"
`
* File Paths
`
	LOCAL_STATIC_DIR="/path/to/staticfiles"
	REMOTE_STATIC_DIR="/path/to/remote/staticfiles"
	LOCAL_MEDIA_DIR="/path/to/mediafiles"
	REMOTE_MEDIA_DIR="/path/to/remote/mediafiles"
`
## License

This script is provided under the GPLv3 License. Feel free to modify and use it in your own projects.

## Contributing

Contributions are welcome! If you have ideas for improvements or new features, please submit a pull request or open an issue.

## Contact

For questions or feedback, feel free to reach out at [cinar.doruk@gmail.com]
