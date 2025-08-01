#!/bin/bash

docker build -t mariadb:latest .

# docker login
docker tag mariadb:latest zmutclik/mariadb:latest
docker push zmutclik/mariadb:latest