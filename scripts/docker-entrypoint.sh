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

/opt/tuning.sh
/opt/backup/install_cron.sh

# Database tetap dijalankan walau cron gagal start, backup saja yang tidak jalan
if ! service cron start; then
    echo "Gagal menjalankan cron, backup otomatis tidak aktif" >&2
fi

exec docker-entrypoint.sh "$@"
