#!/bin/bash

DOMAIN="${REGISTRY_DOMAIN:-registry.aztech-ai.com}"
MAX_ATTEMPTS=120
SLEEP_INTERVAL=30

echo "Checking DNS propagation for $DOMAIN..."

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  if nslookup "$DOMAIN" >/dev/null 2>&1; then
    echo "DNS resolved for $DOMAIN"
    exit 0
  fi
  echo "Waiting for DNS propagation (attempt $i/$MAX_ATTEMPTS)..."
  sleep $SLEEP_INTERVAL
done

echo "Error: DNS propagation failed after $MAX_ATTEMPTS attempts"
exit 1