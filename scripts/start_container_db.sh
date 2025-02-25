#!/bin/bash

sudo -u root /etc/init.d/cron start
sleep 1
mariadbd

