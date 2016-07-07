#!/bin/sh -x

if [ ! -e keys/id_rsa ]; then
  echo Need to run ./generate-keys and place the keys/id_rsa.pub in the deploy keys for the log repo
  exit 1
fi

docker build -t bulk-local .
docker run -v `pwd`/keys/id_rsa:/home/opam/.ssh/id_rsa -v `pwd`/keys/id_rsa.pub:/home/opam/.ssh/id_rsa.pub bulk-local /home/opam/command.sh $1
