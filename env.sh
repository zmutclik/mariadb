#!/bin/bash

find ./config -type f -name ".env" -exec rm {} \;
find ./       -type f -name ".env" -exec rm {} \;
find ./config -type f -name "init.sql" -exec rm {} \;
find ./config -type f -name "db_backup.cnf" -exec rm {} \;
cp ./config/sample/.env.sample          ./config/.env
cp ./config/sample/init.sample.sql      ./config/init.sql
cp ./config/sample/db.sample.cnf        ./config/db_backup.cnf

export DBROOTPASSWORDX=$(curl --silent https://randomuser.me/api/   | jq '.results[].login.salt')
export DBAPPUSERX=$(curl --silent https://randomuser.me/api/        | jq '.results[].login.password')
export DBAPPPASSWORDX=$(curl --silent https://randomuser.me/api/    | jq '.results[].login.salt')
export PASSYBACKUPX=$(curl --silent https://randomuser.me/api/      | jq '.results[].login.salt')

sed -i~ "/^DB_ROOTPASSWORD=/s/=.*/=$DBROOTPASSWORDX/"   ./config/.env
sed -i~ "/^DB_APPUSER=/s/=.*/=$DBAPPUSERX/"             ./config/.env
sed -i~ "/^DB_APPPASS=/s/=.*/=$DBAPPPASSWORDX/"         ./config/.env
sed -i~ "/^BACKUP_PASS=/s/=.*/=$PASSYBACKUPX/"          ./config/.env

sed -i 's/"//gI' ./config/.env

source ./config/.env

sed -i "s/DB_ROOTPASSWORD/$DBROOTPASSWORDX/gI"  ./config/init.sql
sed -i "s/DB_APPUSER/$DBAPPUSERX/gI"            ./config/init.sql
sed -i "s/DB_APPPASS/$DBAPPPASSWORDX/gI"        ./config/init.sql
sed -i "s/BACKUP_PASS/$PASSYBACKUPX/gI"         ./config/init.sql
sed -i "s/DB_NAME/$DB_NAME/gI"                  ./config/init.sql

sed -i 's/"//gI' ./config/init.sql

sed -i "s/PASSYBACKUPX/$PASSYBACKUPX/gI"        ./config/db_backup.cnf

sed -i 's/"//gI' ./config/db_backup.cnf

rm ./config/.env~

cp -rL config/.env .env