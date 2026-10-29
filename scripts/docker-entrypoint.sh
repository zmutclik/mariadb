#!/bin/bash
# Tulis kredensial backup untuk cron dari env, bukan dari image
if [ -n "$BACKUP_PASS" ]; then
    backup_user="${BACKUP_USER:-user_backup}"
    backup_pass="${BACKUP_PASS//\\/\\\\}"
    backup_pass="${backup_pass//\"/\\\"}"
    (
        umask 077
        printf '[client]\nuser = %s\npassword = "%s"\n' "$backup_user" "$backup_pass" >/etc/db_backup.cnf
    )
    unset backup_user backup_pass
else
    echo "BACKUP_PASS kosong, /etc/db_backup.cnf tidak dibuat (backup akan gagal)" >&2
fi

/opt/backup/install_cron.sh

if ! service cron start; then
    echo "Failed to start cron service" >&2
    if [ "$0" != "/docker-entrypoint.sh" ]; then
        exec docker-entrypoint.sh "$@"
    fi
fi
sleep 1
exec docker-entrypoint.sh "$@"
