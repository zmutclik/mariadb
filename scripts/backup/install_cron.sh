#!/bin/bash
# Pasang jadwal cron backup. Dijalankan entrypoint setiap container start,
# crontab ditulis ulang (bukan ditambah) sehingga tidak pernah dobel.
#
# BACKUP_CRON / DUMP_CRON: jadwal format cron 5 kolom, atau "off" untuk menonaktifkan.
# Default: menit & jam diturunkan dari hostname, jadi tiap server berbeda tapi tetap stabil.

SEED=$(hostname | cksum | cut -d' ' -f1)
BACKUP_CRON="${BACKUP_CRON:-$((SEED % 60)) $((SEED / 60 % 2)) * * *}"
DUMP_CRON="${DUMP_CRON:-$((SEED / 120 % 60)) $((SEED / 7200 % 2 + 3)) * * *}"

CRON_LOG_DIR="/backup/log"
mkdir -p "$CRON_LOG_DIR"

CRONTAB=""
if [ "$BACKUP_CRON" != "off" ]; then
    CRONTAB+="$BACKUP_CRON /opt/backup/databasebackup.sh >> $CRON_LOG_DIR/database_backup_cron.log 2>&1"$'\n'
fi
if [ "$DUMP_CRON" != "off" ]; then
    CRONTAB+="$DUMP_CRON /opt/backup/databasedump.sh >> $CRON_LOG_DIR/database_dump_cron.log 2>&1"$'\n'
fi

printf '%s' "$CRONTAB" | crontab -

echo "Jadwal backup terpasang:"
crontab -l
