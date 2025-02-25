FROM ubuntu:jammy
LABEL maintainer="Fahrudin Hariadi<fahrudin.hariadi@gmail.com>"
ARG DB_ROOTPASSWORD
ARG DB_APPUSER
ARG DB_APPPASS
ARG DB_NAME
RUN echo "########################################################################################################################"
ENV DATABASE_ROOTPASSWORD = ${DB_ROOTPASSWORD}
ENV DATABASE_APP_USERNAME = ${DB_APPUSER}
ENV DATABASE_APP_PASSWORD = ${DB_APPPASS}
ENV DATABASE_NAME = ${DB_NAME}
RUN echo "########################################################################################################################"
RUN groupadd -r mysql && useradd -r -g mysql mysql --home-dir /var/lib/mysql
RUN echo "########################################################################################################################"
RUN apt update
RUN apt -y upgrade
RUN echo "########################################################################################################################"
RUN ln -snf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime && echo Asia/Jakarta > /etc/timezone
RUN apt-get install tzdata -y
RUN echo "########################################################################################################################"
RUN apt -y install mariadb-server mariadb-client mariadb-backup
RUN apt -y install iproute2 nano iputils-ping lsb-release gnupg2 ca-certificates apt-transport-https software-properties-common gcc make autoconf libc-dev pkg-config logrotate sudo curl
RUN echo "mysql ALL=(ALL) NOPASSWD: /etc/init.d/cron" > /etc/sudoers.d/startcron
RUN echo "########################################################################################################################"
RUN mkdir /backup
RUN mkdir /backup/databases
RUN mkdir /backup/fullbackup
RUN mkdir /backup/log
RUN chmod 755 /backup/databases
RUN chmod 755 /backup/fullbackup
RUN echo "########################################################################################################################"
COPY config/init.sql /backup/
RUN /etc/init.d/mariadb start ; sleep 10 ; bash -c "mysql --user='root' < /backup/init.sql"
RUN rm /backup/init.sql
RUN sed -i "s/bind-address            = 127.0.0.1/bind-address            = 0.0.0.0/gI" /etc/mysql/mariadb.conf.d/50-server.cnf
RUN echo "########################################################################################################################"
COPY scripts/databasebackup.sh        /backup/databasebackup.sh
COPY scripts/databasedump.sh          /backup/databasedump.sh
COPY scripts/install_backup.sh        /backup/install_backup.sh
COPY scripts/install_dump.sh          /backup/install_dump.sh
COPY scripts/start_container_db.sh    /boot/start.sh
RUN chmod +x /backup/databasebackup.sh
RUN chmod +x /backup/databasedump.sh
RUN chmod +x /backup/install_backup.sh
RUN chmod +x /backup/install_dump.sh
RUN chmod +x /boot/start.sh
RUN /backup/install_backup.sh
RUN /backup/install_dump.sh
RUN echo "########################################################################################################################"
RUN rm /etc/ssl/openssl.cnf
COPY config/sample/openssl.cnf /etc/ssl/openssl.cnf
USER mysql
RUN echo "########################################################################################################################"
CMD ["/boot/start.sh"]