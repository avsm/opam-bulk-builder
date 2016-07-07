#!/bin/sh -x

if [ ! -e keys/id_rsa ]; then
  echo Need to run ./generate-keys and place the keys/id_rsa.pub in the deploy keys for the log repo
  exit 1
fi

docker build -t bulk-local .
docker run -e SSH_PRIVATE_RSA_KEY_B64="`base64 keys/id_rsa`" bulk-local $1
