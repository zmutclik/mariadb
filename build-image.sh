#!/bin/bash
# Build & push image. Versi MariaDB bisa diganti: MARIADB_VERSION=11.8 ./build-image.sh
set -e

MARIADB_VERSION="${MARIADB_VERSION:-12.3}"
IMAGE="zmutclik/mariadb"

docker build --pull \
    --build-arg MARIADB_VERSION="$MARIADB_VERSION" \
    -t "$IMAGE:$MARIADB_VERSION" \
    -t "$IMAGE:latest" \
    .

# docker login
docker push "$IMAGE:$MARIADB_VERSION"
docker push "$IMAGE:latest"
