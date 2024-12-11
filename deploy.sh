#!/bin/bash
:<<COMMENT



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
	echo "Preparing fresh debian server at $REMOTE_HOST"


	# ssh into the server as root and run our commands. we need sshpass for this.
	sudo pacman -Sy sshpass
	sshpass -p "$ROOTPSW" ssh ${ROOTUSR}@${HOST_IP} "echo 'login successful'"

	if [ $? -eq 0 ]; then
		echo "initial login works ${ROOTUSR}@${HOST_IP}"
	else
		echo "initial login failed ${ROOTUSR}@${HOST_IP}"
		exit 1
	fi

	echo "creating new user with a password, adding it to sudoers, and installing basic software"
	sshpass -p "$ROOTPSW" ssh ${ROOTUSR}@${HOST_IP} <<- EOF

	# create new user, add to sudoers, give it a password
	adduser --gecos "" --disabled-password "$REMOTE_USER"
	echo "$REMOTE_USER:$REMOTE_PASS" | chpasswd
	usermod -aG sudo "$REMOTE_USER"

	# switch to it
	su - "$REMOTE_USER"

	# install basic software
	echo "$REMOTE_PASS" | sudo apt update && sudo apt upgrade -y
	sudo apt install -y wget ufw fail2ban neofetch htop neovim zsh ssh certbot python3-certbot-nginx ca-certificates curl git nginx

	EOF

	if [ $? -eq 0 ]; then
		echo "new user creation successful $REMOTE_USER_AT"
	else
		echo "new user creationg failed! $REMOTE_USER_AT"
		exit 1
	fi

	# create new ssh key locally

	ssh-keygen -t rsa -b 4096 -C "${USER}@${SSH_ALIAS}" -f "$SSH_KEYPATH" -N "$SSH_PWD"
	if [ $? -eq 0 ]; then
		echo "SSH keypair created at $KEY_PATH and $KEY_PATH.pub"
	else
		echo "Failed to generate SSH keypair."
		exit 1
	fi

	# move public key to server for user
	# will ask for pwd interactively

	ssh-copy-id -i ~/.ssh/id_rsa.pub username@remote_host

	# add alias to local ~/.ssh/config to be used later
	echo $SSH_ALIAS_ENTRY >> $HOME/.ssh/config

	# test ssh access using key
	ssh $SSH_ALIAS "echo 'SSH setup successful!'"
	if [ $? -eq 0 ]; then
		echo "SSH access $REMOTE_USER_AT verified successfully"
	else
		echo "SSH access test failed $REMOTE_USER_AT"
		exit 1
	fi

	# in server edit sshd_config
	EDIT_SSHD="
	echo $REMOTE_PASS sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config;
	sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config;
	sudo sed -i 's/^#\?UsePAM.*/UsePAM no/' /etc/ssh/sshd_config;
	sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config;
	sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config;
	sudo sed -i 's/^#\?AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config;
	sudo grep -q '^Port 1995' /etc/ssh/sshd_config || echo 'Port 1995' | sudo tee -a /etc/ssh/sshd_config;
	sudo grep -q '^ClientAliveInterval 60' /etc/ssh/sshd_config || echo 'ClientAliveInterval 60' | sudo tee -a /etc/ssh/sshd_config;
	sudo grep -q '^ClientAliveCountMax 3' /etc/ssh/sshd_config || echo 'ClientAliveCountMax 3' | sudo tee -a /etc/ssh/sshd_config;
	sudo sshd -t
	sudo systemctl restart sshd
	"
	ssh $SSH_ALIAS "$EDIT_SSHD"
	echo "Remote SSH configuration updated and SSH service restarted."

	# try logging in using the user's key again just to make sure

	# copy over dotfiles/.zshrc
	# set TERM to the right thing

	# configure ufw


	# install docker
	sudo mkdir -p /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

	# verify docker installation

	# add the $REMOTE_USER to the group 'docker'
	sudo usermod -aG docker $REMOTE_USER


	# get the bare repo ready

	# set up post-receive hook



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
