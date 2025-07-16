#!/bin/bash

BACKUP_SCRIPT="/backup/databasebackup.sh"
CRON_LOG="/backup/log/database_backup_cron.log"
JAMEE=$(( $RANDOM % 2 ));
MENIT=$(( $RANDOM % 50 ));

if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "Error: Script backup tidak ditemukan di $BACKUP_SCRIPT"
    exit 1
fi

chmod +x "$BACKUP_SCRIPT"
touch "$CRON_LOG"

( crontab -l 2>/dev/null ; echo "$MENIT $JAMEE * * * $BACKUP_SCRIPT >> $CRON_LOG 2>&1" ) | crontab -

# Verifikasi
echo "Crontab berhasil diperbarui"
crontab -l
