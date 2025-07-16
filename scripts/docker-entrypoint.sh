#!/bin/bash
if ! service cron start; then
    echo "Failed to start cron service" >&2
    if [ "$0" != "/docker-entrypoint.sh" ]; then
        exec docker-entrypoint.sh "$@"
    fi
fi
sleep 1
exec docker-entrypoint.sh "$@"
