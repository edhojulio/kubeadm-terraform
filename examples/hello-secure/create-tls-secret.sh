#!/bin/bash
# Create a self-signed TLS secret for the hello-secure example (lab use only).
# Usage: ./create-tls-secret.sh [namespace]
set -euo pipefail

NS="${1:-demo}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$TMP/tls.key" \
  -out "$TMP/tls.crt" \
  -subj "/CN=hello.local" \
  -addext "subjectAltName=DNS:hello.local"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create secret tls hello-tls \
  --cert="$TMP/tls.crt" \
  --key="$TMP/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Created/updated secret ${NS}/hello-tls"
