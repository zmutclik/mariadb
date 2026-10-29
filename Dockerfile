ARG MARIADB_VERSION=12.3
FROM mariadb:${MARIADB_VERSION}
RUN apt update && apt -y upgrade \
    && apt-get install -y tzdata cron curl nano iputils-ping traceroute \
    && ln -snf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime && echo "Asia/Jakarta" >/etc/timezone && dpkg-reconfigure -f noninteractive tzdata \
    && mkdir -p /backup/databases /backup/fullbackup /backup/log && chmod 755 /backup/databases /backup/fullbackup /backup/log \
    && echo "[mysqld]\nevent_scheduler=ON" >/etc/mysql/conf.d/custom_scheduler.cnf \
    &&  apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --chmod=644 scripts/init-backup-user.sh /docker-entrypoint-initdb.d/
COPY --chmod=755 scripts/backup/ /opt/backup/
RUN rm /etc/ssl/openssl.cnf
COPY scripts/openssl.cnf /etc/ssl/openssl.cnf
COPY scripts/docker-entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh
VOLUME /backup
ENTRYPOINT ["custom-entrypoint.sh"]
CMD ["mariadbd"]
