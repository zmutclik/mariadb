#!/bin/bash
# Gagal jika salah satu perintah dalam pipe gagal (bukan hanya gzip)
set -o pipefail
start_time=$(date +%s)
MYSQL_ARGS="--defaults-extra-file=/etc/db_backup.cnf"
MYSQL="/usr/bin/mariadb $MYSQL_ARGS "
MYSQLBACKUP="/usr/bin/mariadb-backup $MYSQL_ARGS "

BACKUP_DIR="/backup"
BACKUP_RETENTION_DAYS=30
EXCLUDED_DBS="mysql performance_schema information_schema phpmyadmin sys"

# Buat struktur direktori backup
mkdir -p "$BACKUP_DIR/fullbackup"
mkdir -p "$BACKUP_DIR/log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="$BACKUP_DIR/log/backup_log_$(date +"%Y").log"
# Variabel untuk melacak status backup
BACKUP_FAILED=0
FAILED_DATABASES=""
SUCCESSFUL_DATABASES=""
DELETED_FILESBACKUP=""
# Fungsi logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOGFILE"
}
# Fungsi validasi backup
validate_backup() {
    local BACKUP_FILE="$1"

    # Periksa ukuran file
    if [ ! -s "$BACKUP_FILE" ]; then
        log "GAGAL: File Full Backup kosong" "ERROR"
        return 1
    fi

    # Coba unzip dan periksa integritas
    gzip -t "$BACKUP_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        log "GAGAL: File Full Backup rusak" "ERROR"
        return 1
    fi

    return 0
}
# Fungsi backup database
backup_databases() {
    local DB_BACKUP_DIR="$BACKUP_DIR/fullbackup"
    local BACKUP_FILE="$DB_BACKUP_DIR/$TIMESTAMP.sql.gz"
    log "Proses Full Backup database"
    # Backup database dengan timeout dan penanganan error
    timeout 1h $MYSQLBACKUP --backup --stream=xbstream 2>>"$LOGFILE" | gzip >"$BACKUP_FILE"

    # Periksa status backup
    if [ $? -eq 0 ]; then
        # Validasi backup
        if validate_backup "$BACKUP_FILE"; then
            log "Semua database berhasil di-BACKUP"
        else
            log "PERINGATAN: database gagal di-BACKUP"
            BACKUP_FAILED=1
            rm -f "$BACKUP_FILE"
        fi
    else
        log "Full Backup gagal"
        BACKUP_FAILED=1
        rm -f "$BACKUP_FILE"
    fi
}

# Fungsi hapus backup lama
cleanup_old_backups() {
    log "Menghapus backup yang lebih dari $BACKUP_RETENTION_DAYS hari"
    # Dapatkan daftar semua database
    local DELETED_FILES=$(find "$BACKUP_DIR/fullbackup" -name "*.sql.gz" -type f -mtime +$BACKUP_RETENTION_DAYS -delete -print | wc -l)
}
# Fungsi utama
main() {
    log "Memulai proses backup database"

    # Reset variabel
    BACKUP_FAILED=0
    FAILED_DATABASES=""
    SUCCESSFUL_DATABASES=""
    DELETED_FILESBACKUP=""

    # Jalankan backup
    backup_databases

    # Bersihkan backup lama
    cleanup_old_backups

    log "Proses backup database selesai dalam $(($(date +%s) - start_time)) detik"

    # Kembalikan status untuk integrasi dengan sistem lain
    exit $BACKUP_FAILED
}

# Jalankan script
main
