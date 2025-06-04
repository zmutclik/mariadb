#!/bin/bash

find ./ -type f -name ".env" -exec rm {} \;
find ./config -type f -name ".env" -exec rm {} \;
find ./config -type f -name "db_backup.cnf" -exec rm {} \;
find ./config -type f -name "init-backup-user.sql" -exec rm {} \;
cp ./scripts/sample.env ./config/.env
cp ./scripts/sample.cnf ./config/db_backup.cnf
cp ./scripts/sample.sql ./config/init-backup-user.sql

export DBROOTPASSWORDX=$(curl --silent https://randomuser.me/api/ | jq '.results[].login.salt')
export DBAPPUSERX=$(curl --silent https://randomuser.me/api/ | jq '.results[].login.password')
export DBAPPPASSWORDX=$(curl --silent https://randomuser.me/api/ | jq '.results[].login.salt')
export PASSYBACKUPX=$(curl --silent https://randomuser.me/api/ | jq '.results[].login.salt')

sed -i~ "/^DB_ROOTPASSWORD=/s/=.*/=$DBROOTPASSWORDX/" ./config/.env
sed -i~ "/^DB_APPUSER=/s/=.*/=$DBAPPUSERX/" ./config/.env
sed -i~ "/^DB_APPPASS=/s/=.*/=$DBAPPPASSWORDX/" ./config/.env
sed -i~ "/^BACKUP_PASS=/s/=.*/=$PASSYBACKUPX/" ./config/.env

sed -i '' 's/"//gI' ./config/.env

source ./config/.env

sed -i '' "s/BACKUP_PASS/$PASSYBACKUPX/gI" ./config/init-backup-user.sql
sed -i '' "s/PASSYBACKUPX/$PASSYBACKUPX/gI" ./config/db_backup.cnf
sed -i '' 's/"//gI' ./config/init-backup-user.sql
sed -i '' 's/"//gI' ./config/db_backup.cnf

rm ./config/.env~

ln config/.env .env
