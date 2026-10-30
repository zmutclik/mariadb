# MariaDB dengan Backup Otomatis

Image Docker MariaDB (`zmutclik/mariadb`) dengan tambahan:

- **Backup otomatis via cron**: full backup fisik (`mariadb-backup`) dan dump logis per database (`mariadb-dump`), retensi 30 hari.
- **Zona waktu Asia/Jakarta** dan `event_scheduler=ON`.
- **Kredensial tidak disimpan di image**: user backup dibuat dari environment saat inisialisasi pertama.
- **Healthcheck** dan upgrade otomatis saat versi MariaDB dinaikkan.

## Mulai cepat

```bash
./env.sh                      # buat .env dengan user & password acak
nano .env                     # sesuaikan CONTAINER_NAME, HOSTNAME, DATA_PORT, DNS, dll.
docker compose up -d --build  # build lokal
```

Untuk memakai image dari Docker Hub tanpa build (mis. lewat Portainer):

```bash
docker compose -f docker-compose_stack.yml up -d
```

`env.sh` menolak menimpa `.env` yang sudah ada, karena password di dalamnya mungkin sudah dipakai database.
Gunakan `./env.sh --force` hanya untuk instalasi baru.

## Variabel `.env`

| Variabel | Keterangan |
|---|---|
| `CONTAINER_NAME`, `HOSTNAME` | Nama container dan hostname. Hostname juga menentukan jadwal backup default |
| `DATA_PORT` | Port di host yang diteruskan ke 3306 |
| `DB_ROOTPASSWORD` | Password root MariaDB |
| `DB_NAME`, `DB_APPUSER`, `DB_APPPASS` | Database dan user aplikasi yang dibuat saat inisialisasi pertama |
| `DNS1`, `DNS2` | DNS server untuk container |
| `NFS_ADDRESS`, `NFS_DATA_PATH`, `NFS_BACKUP_PATH` | Opsional, untuk menyimpan volume di NFS (aktifkan `driver_opts` di file compose) |
| `BACKUP_USER`, `BACKUP_PASS` | User yang dipakai script backup |
| `BACKUP_CRON`, `DUMP_CRON` | Jadwal format cron (mis. `30 1 * * *`). Kosong = otomatis, `off` = nonaktif |

Variabel `DB_*` dan `BACKUP_USER`/`BACKUP_PASS` hanya dipakai saat volume data masih kosong.
Mengubahnya setelah itu tidak mengubah user di database; lihat [Mengganti password backup](#mengganti-password-backup).

## Backup

| Jenis | Script | Lokasi | Jadwal default |
|---|---|---|---|
| Full backup (fisik) | `/opt/backup/databasebackup.sh` | `/backup/fullbackup/<waktu>.xbstream.gz` | Jam 00:00–01:59 |
| Dump per database | `/opt/backup/databasedump.sh` | `/backup/databases/<db>/<db>-<waktu>.sql.gz` | Jam 03:00–04:59 |

Menit dan jam default diturunkan dari hostname, sehingga tiap server berbeda tetapi tetap sama setiap restart.
Database `mysql`, `performance_schema`, `information_schema`, `phpmyadmin`, dan `sys` tidak ikut di-dump.

`/backup` adalah volume tersendiri. Sebaiknya arahkan ke NFS/NAS (lihat `driver_opts` di file compose) agar backup tidak berada di disk yang sama dengan data.

Log ada di `/backup/log/`. Script keluar dengan kode selain 0 jika backup gagal.

Menjalankan backup secara manual:

```bash
docker exec <container> /opt/backup/databasebackup.sh
docker exec <container> /opt/backup/databasedump.sh
```

## Restore

### Dari dump (satu database)

Dump berisi `CREATE DATABASE`, tabel, data, trigger, routine, dan event. Database dengan nama yang sama akan ditimpa.

```bash
FILE=/backup/databases/<db>/<db>-<waktu>.sql.gz
docker exec <container> sh -c "gunzip -c $FILE" \
  | docker exec -i <container> sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"'
```

### Dari full backup (seluruh server)

Restore ke **volume baru** dulu, periksa hasilnya, baru ganti volume lama. Jangan langsung menimpa volume yang sedang dipakai.

```bash
FULL=<waktu>.xbstream.gz
docker volume create restore_data

docker run --rm --entrypoint bash \
  -v <volume_backup>:/backup:ro \
  -v restore_data:/var/lib/mysql \
  zmutclik/mariadb:12.3 -c "
    set -e
    mkdir -p /tmp/restore
    gunzip -c /backup/fullbackup/$FULL | mbstream -x -C /tmp/restore
    mariadb-backup --prepare --target-dir=/tmp/restore
    mariadb-backup --copy-back --target-dir=/tmp/restore
    chown -R mysql:mysql /var/lib/mysql
  "

# Periksa hasil restore di container sementara
docker run -d --name cek-restore -e MARIADB_AUTO_UPGRADE=1 \
  -v restore_data:/var/lib/mysql zmutclik/mariadb:12.3
docker exec -it cek-restore mariadb -uroot -p
```

Gunakan image dengan versi MariaDB yang sama dengan saat backup dibuat.
Password root dan user lain ikut dari backup, bukan dari `.env`.

Nama volume bisa dilihat dengan `docker volume ls` (biasanya `<nama_project>_data` dan `<nama_project>_backup`).

## Perawatan

### Mengganti password backup

Ubah `BACKUP_PASS` di `.env`, lalu samakan di database dan buat ulang container:

```bash
docker exec -it <container> sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "ALTER USER '\''user_backup'\''@'\''localhost'\'' IDENTIFIED BY '\''<password_baru>'\''"'
docker compose up -d
```

### Upgrade versi MariaDB

Versi dikunci lewat `ARG MARIADB_VERSION` di `Dockerfile` (default `12.3`).
`MARIADB_AUTO_UPGRADE=1` menjalankan `mariadb-upgrade` otomatis saat container start dengan versi baru.
MariaDB tidak mendukung downgrade, jadi buat full backup sebelum upgrade.

### Build dan push image

```bash
docker login
./build-image.sh                        # zmutclik/mariadb:12.3 dan :latest
MARIADB_VERSION=11.8 ./build-image.sh   # versi lain
```

### TLS

`scripts/openssl.cnf` mengatur TLS minimal 1.2 dengan `CipherString = DEFAULT@SECLEVEL=1`.
`SECLEVEL=1` mengizinkan kunci dan cipher yang lebih lemah agar client lama tetap bisa terhubung.
Jika semua client sudah modern, ganti ke `SECLEVEL=2` untuk keamanan yang lebih baik.
