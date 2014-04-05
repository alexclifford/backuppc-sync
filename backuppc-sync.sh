#!/bin/bash

# The script is called with the configuration file as the only argument
# e.g. ./backuppc-sync.sh backup02-config.cfg 
source $1
# REMOTE_SERVER
# SSH_PORT
# SSH_USER
# BACKUPPC_INITD
# CONFIG_DIR
# DATA_DIR
# LOG_DIR
# LOG_FILE
# LOG_PATH
# CONF_ORIG
# CONF_FILE
# LOCK_FILE
# EMAIL_SUBJECT
# EMAIL_FROM
# EMAIL_TO
# RSYNC_BIN
# TEE_BIN
# MAIL_BIN
# SSH_BIN

if [ -e $LOCK_FILE ]
then
	echo "Sync already running... exiting" 2>&1 | $TEE_BIN -a $LOG_PATH
	exit 0
fi

# Only allow one sync to run at a time
touch $LOCK_FILE 2>&1 | $TEE_BIN -a $LOG_PATH

echo "Start:" $(date) 2>&1 | $TEE_BIN -a $LOG_PATH

echo "Stopping BackupPC..." 2>&1 | $TEE_BIN -a $LOG_PATH
$BACKUPPC_INITD stop 2>&1 | $TEE_BIN -a $LOG_PATH

# $CONFIG_DIR sync
echo "Syncing the directory" $CONFIG_DIR "from" `hostname` "to $REMOTE_SERVER..." 2>&1 | $TEE_BIN -a $LOG_PATH
$RSYNC_BIN -avH --delete -e $SSH_BIN' -p '$SSH_PORT $CONFIG_DIR $SSH_USER@$REMOTE_SERVER:$CONFIG_DIR 2>&1 | $TEE_BIN -a $LOG_PATH
RSYNC_RETURN_CODE1=$?
echo "$CONFIG_DIR rsync return code: "$RSYNC_RETURN_CODE1 2>&1 | $TEE_BIN -a $LOG_PATH
# Reinstate the remote backup specific configuration file
$SSH_BIN -p $SSH_PORT $SSH_USER@$REMOTE_SERVER cp $CONF_ORIG $CONF_FILE 2>&1 | $TEE_BIN -a $LOG_PATH

echo "" 2>&1 | $TEE_BIN -a $LOG_PATH

# $DATA_DIR sync
echo "Syncing the directory" $DATA_DIR "from" `hostname` "to $REMOTE_SERVER..." 2>&1 | $TEE_BIN -a $LOG_PATH
$RSYNC_BIN -avH --delete -e $SSH_BIN' -p '$SSH_PORT $DATA_DIR $SSH_USER@$REMOTE_SERVER:$DATA_DIR 2>&1 | $TEE_BIN -a $LOG_PATH
RSYNC_RETURN_CODE2=$?
echo "$DATA_DIR rsync return code: "$RSYNC_RETURN_CODE2 2>&1 | $TEE_BIN -a $LOG_PATH

echo "Starting BackupPC..." 2>&1 | $TEE_BIN -a $LOG_PATH
$BACKUPPC_INITD start 2>&1 | $TEE_BIN -a $LOG_PATH

echo "End:" $(date) 2>&1 | $TEE_BIN -a $LOG_PATH

rm -f $LOCK_FILE 2>&1 | $TEE_BIN -a $LOG_PATH

echo "" 2>&1 | $TEE_BIN -a $LOG_PATH

# Add SUCCESS or FAILURE to the email subject
if [ $RSYNC_RETURN_CODE1 ] || [ $RSYNC_RETURN_CODE2 ]
then
	EMAIL_SUBJECT="FAILURE! - "$EMAIL_SUBJECT
else
	EMAIL_SUBJECT="SUCCESS! - "$EMAIL_SUBJECT
fi
# Email the results to $EMAIL_TO
echo -ne "$(head -n20 $LOG_PATH)\n\n[stripped...]\n\n$(tail -n20 $LOG_PATH)" | $MAIL_BIN -a "From: "$EMAIL_FROM -s "$EMAIL_SUBJECT" $EMAIL_TO 2>&1 | $TEE_BIN -a $LOG_PATH
