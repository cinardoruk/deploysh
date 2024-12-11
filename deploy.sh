#!/bin/zsh
:<<COMMENT
may I please automate the db syncing process between local and remote?
1. create db dump on local machine
2. scp it to remote
3. at the remote, make sure the db service is running
4. delete everything on the current db
5. import the dump
6. sync

TODO
[x] copy over the .env files
[ ] do the build process if container not running already (would jenkins do that instead?)
[ ] ask for ssh passphrase once/get ssh credentials in a conventient way
[x] sync the .env files over too
[x] more granular functions for file syncing
[ ] make django do a collectstatic --clean before syncing static files
[ ] granular execution through args passed to script
[ ] better description of script at the top
[ ] add docker system prune -a docker builder prune
[ ] add compose restart function
[ ] granular db syncing using django fixtures
[ ] function to back up the whole server ? how do we do regular backups?
[ ] do I run jenkins in a docker container?
[ ] function to prepare fresh server
[ ] add confirm()
[ ] put up on github

COMMENT

# the execution of potentially dangerous functions should be wrapped in a confirm
# note that yes returns 0, no returns 1, and bash if(){} takes 0 to mean true, 1 to mean false
confirm() {
	if [ "$NON_INTERACTIVE" -eq 1]; then
		echo "Non-interactive mode: Automatically proceeding with $@."
		return 0
	fi
	while true; do
		read -p "$1 (y/n): " yn
		case $yn in
			[Yy]* ) return 0;; # User answered 'yes'
			[Nn]* ) return 1;; # User answered 'no'
			* ) echo "Please answer y or n.";;
		esac
	done
}


#get project specific data from separate file
source deploy.env

prepare_server ()
{
	echo "Preparing fresh server at $REMOTE_HOST"

}


# DATABASE SYNCING

TIMESTAMP=$(date +%Y%m%d%H%M)
DUMP_FILE="db_dump_$TIMESTAMP.sql"

create_db_dump() {
	# Step 1: Create a dump of the PostgreSQL database from the running container
	echo "Creating database dump from PostgreSQL service..."

	# docker exec -t $DB_CONTAINER_NAME mkdir /home/baks/
	docker exec -t $DB_CONTAINER_NAME pg_dump -U $DB_USER -d $DB_NAME -F c -f /home/$DUMP_FILE
	docker cp $DB_CONTAINER_NAME:/home/$DUMP_FILE $LOCAL_DUMP_DIR
	docker exec -t $DB_CONTAINER_NAME rm /home/$DUMP_FILE

	if [ $? -eq 0 ]; then
	  echo "Database dump created successfully: $LOCAL_DUMP_DIR/$DUMP_FILE"
	else
	  echo "Failed to create database dump. Check the error log: $LOCAL_DUMP_DIR/db_backup_error.log"
	  exit 1
	fi
}


# Step 2: Securely copy the dump file to the remote host using SCP
transfer_dump_to_remote(){
	echo "Transferring database dump to remote host..."
	scp "$LOCAL_DUMP_DIR/$DUMP_FILE" $REMOTE_HOST:$REMOTE_DIR
	echo "Database dump transferred successfully to $REMOTE_HOST:$REMOTE_DIR"

	if [ $? -eq 0 ]; then
	  echo "Database dump transferred successfully to $REMOTE_HOST:$REMOTE_DIR"
	else
	  echo "Failed to transfer database dump to remote host"
	  exit 1
	fi
}

# steps 3, 4, and 5

restore_remote_db() {
	echo "Restoring database on remote host..."
	ssh $REMOTE_HOST "
	docker exec -i $PROD_DB_CONT psql -U $PROD_DB_USER -d postgres -c \"\
		SELECT pg_terminate_backend(pid) \
		FROM pg_stat_activity \
		WHERE datname = '$PROD_DB';\" && \
	docker exec -i $PROD_DB_CONT psql -U $PROD_DB_USER -d postgres -c \"DROP DATABASE IF EXISTS $PROD_DB;\" && \
	docker exec -i $PROD_DB_CONT psql -U $PROD_DB_USER -d postgres -c \"CREATE DATABASE $PROD_DB WITH OWNER $PROD_DB_USER ;\" && \
	cat $REMOTE_DIR/$DUMP_FILE | docker exec -i $PROD_DB_CONT pg_restore --no-owner -U $PROD_DB_USER -d $PROD_DB
	"

	echo "Database dump restored on remote machine."
}

sync_env() {

	echo "Syncing .env files to remote machine..."

	rsync -avz --info=progress2 --partial --delete $CHOWN $LOCAL_REPO_DIR/.env.prod* $REMOTE_HOST:$REMOTE_DEPLOY_DIR
	echo ".env files synced."
}

sync_static() {
	echo "Syncing static files to remote machine..."
	rsync -avz --info=progress2 --partial --delete $CHOWN $LOCAL_REPO_DIR/app/staticfiles/ $REMOTE_HOST:$REMOTE_DEPLOY_DIR/staticfiles
	echo "Static files synced."
}

sync_media() {
	echo "Syncing media files to remote machine..."
	rsync -avz --info=progress2 --partial --delete $CHOWN $LOCAL_REPO_DIR/app/media/ $REMOTE_HOST:$REMOTE_DEPLOY_DIR/mediafiles
	echo "Media files synced."
}

sync_email() {
	echo "Syncing email assets to remote machine..."
	rsync -avz --info=progress2 --partial --delete $CHOWN $LOCAL_REPO_DIR/app/emails/email_static/ $REMOTE_HOST:/var/www/email_assets/posterce
	echo "Email assets synced."
}

usage(){
	echo """
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

	fill out the variables in deploy.env
	"""
}


# main.c
for arg in "$@"; do
	case $arg in
		dump)
			create_db_dump
			;;
		transfer)
			transfer_dump_to_remote
			;;
		restore)
			restore_remote_db
			;;
		files_all)
			sync_env
			sync_static
			sync_media
			sync_email
			;;
		files_env)
			sync_env
			;;
		files_static)
			sync_static
			;;
		files_media)
			sync_media
			;;
		files_email)
			sync_email
			;;
		help)
			usage
			;;
		--non-interactive)
			NON_INTERACTIVE=1
			;;
		*)
			echo "Error: Unknown option '$arg'"
			usage
			exit 1
			;;
	esac
done

create_db_dump
transfer_dump_to_remote
restore_remote_db

sync_env
sync_static
sync_media
sync_email
sync_all

echo "All operations completed successfully."
