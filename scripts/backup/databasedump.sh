#!/bin/bash
start_time=$(date +%s)
MYSQL_ARGS="--defaults-extra-file=/etc/db_backup.cnf"
MYSQL="/usr/bin/mariadb $MYSQL_ARGS "
MYSQLDUMP="/usr/bin/mariadb-dump $MYSQL_ARGS "

BACKUP_DIR="/backup"
BACKUP_RETENTION_DAYS=30
EXCLUDED_DBS="mysql performance_schema information_schema phpmyadmin sys"

# Buat struktur direktori backup
mkdir -p "$BACKUP_DIR/databases"
mkdir -p "$BACKUP_DIR/log"
# Tanggal untuk nama file backup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
# Log file untuk mencatat proses backup
LOGFILE="$BACKUP_DIR/log/dump_log_$(date +"%Y-%m").log"
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
    local DB_NAME="$2"

    # Periksa ukuran file
    if [ ! -s "$BACKUP_FILE" ]; then
        log "GAGAL: Backup $DB_NAME kosong" "ERROR"
        return 1
    fi

    # Coba unzip dan periksa integritas
    gzip -t "$BACKUP_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        log "GAGAL: Backup $DB_NAME rusak" "ERROR"
        return 1
    fi

    return 0
}
# Fungsi backup database
backup_databases() {
    # Dapatkan daftar semua database
    local DATABASES=$($MYSQL -BNe "SHOW DATABASES;" | grep -Ev "^(Database|${EXCLUDED_DBS// /|})")

    log "Memulai proses backup database"

    # Buat backup untuk setiap database
    for DB in $DATABASES; do
        # Buat nama file unik untuk setiap database
        local DB_BACKUP_DIR="$BACKUP_DIR/databases/$DB"
        mkdir -p "$DB_BACKUP_DIR"
        local BACKUP_FILE="$DB_BACKUP_DIR/$DB-$TIMESTAMP.sql.gz"

        log "Proses backup database: $DB"

        # Backup database dengan timeout dan penanganan error
        timeout 1h $MYSQLDUMP \
            --single-transaction \
            --routines \
            --triggers \
            --databases "$DB" | gzip >"$BACKUP_FILE" 2>>"$LOGFILE"

        # Periksa status backup
        if [ $? -eq 0 ]; then
            # Validasi backup
            if validate_backup "$BACKUP_FILE" "$DB"; then
                log "Backup $DB berhasil"
                SUCCESSFUL_DATABASES+=" $DB"
            else
                log "Backup $DB gagal validasi"
                BACKUP_FAILED=$((BACKUP_FAILED + 1))
                FAILED_DATABASES+=" $DB"
                rm -f "$BACKUP_FILE"
            fi
        else
            log "Backup $DB gagal"
            BACKUP_FAILED=$((BACKUP_FAILED + 1))
            FAILED_DATABASES+=" $DB"
            rm -f "$BACKUP_FILE"
        fi
    done

    # Ringkasan hasil backup
    if [ $BACKUP_FAILED -gt 0 ]; then
        log "PERINGATAN: $BACKUP_FAILED database gagal di-DUMP:$FAILED_DATABASES"
        log "Database berhasil di-DUMP:$SUCCESSFUL_DATABASES"
    else
        log "Semua database berhasil di-backup"
    fi
}

# Fungsi hapus backup lama
cleanup_old_backups() {
    log "Menghapus backup yang lebih dari $BACKUP_RETENTION_DAYS hari"
    # Dapatkan daftar semua database
    local DATABASES=$($MYSQL -BNe "SHOW DATABASES;" | grep -Ev "^(Database|${EXCLUDED_DBS// /|})")
    # Buat backup untuk setiap database
    for DB in $DATABASES; do
        # Buat nama file unik untuk setiap database
        # Hapus file backup lama per database
        local DELETED_FILES=$(find "$BACKUP_DIR/databases/$DB" -name "*.sql.gz" -type f -mtime +$BACKUP_RETENTION_DAYS -delete -print | wc -l)

        DELETED_FILESBACKUP+=" $DELETED_FILES"
    done
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
