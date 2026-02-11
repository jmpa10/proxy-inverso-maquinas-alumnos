#!/bin/sh
set -e

echo "⏳ Esperando configuraciones..."
while [ ! -f /etc/nginx/conf.d/stream.d/stream-map-entries.conf ] || [ ! -f /etc/nginx/conf.d/stream.d/ssh-proxy.conf ]; do
    sleep 2
done

echo "✅ Configuraciones listas"
nginx -t
exec "$@"
