#!/bin/sh

if [ ! -e keys/id_rsa ]; then
  echo Need to generate key first with generate-keys
  exit 1
fi

docker service create \
  --replicas 3 \
  --name opam-build \
  --restart-condition on_failure \
  -e SSH_PRIVATE_RSA_KEY_B64="`base64 keys/id_rsa`" \
  avsm/opam-bulk-build process
