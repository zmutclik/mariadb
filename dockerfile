FROM mariadb:latest
RUN apt update
RUN apt -y upgrade
RUN apt-get install -y tzdata cron curl nano
RUN ln -snf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime && echo "Asia/Jakarta" >/etc/timezone && dpkg-reconfigure -f noninteractive tzdata
RUN mkdir -p /backup/databases /backup/fullbackup /backup/log && chmod 755 /backup/databases /backup/fullbackup /backup/log

RUN echo "[mysqld]\nevent_scheduler=ON" >/etc/mysql/conf.d/custom_scheduler.cnf
COPY config/init-backup-user.sql /docker-entrypoint-initdb.d/

COPY scripts/backup/ /backup/
RUN chmod +x /backup/*.sh
RUN /backup/install_backup.sh
RUN /backup/install_dump.sh

RUN rm /etc/ssl/openssl.cnf
COPY scripts/openssl.cnf /etc/ssl/openssl.cnf

COPY scripts/docker-entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

ENTRYPOINT ["custom-entrypoint.sh"]
CMD ["mariadbd"]
