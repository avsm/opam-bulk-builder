#!/usr/bin/env bash

set -e

if [ ! -e keys/id_rsa ]; then
  echo Need to run ./generate-keys and place the keys/id_rsa.pub in the deploy keys for the log repo
  exit 1
fi

OPAM_REPO_REV=$(curl --silent https://api.github.com/repos/ocaml/opam-repository/branches| jq -cr '.[] | select (.name | contains("master"))? | .commit.sha')
export OPAM_REPO_REV
docker build -t bulk-local .
docker run -e OPAM_REPO_REV="$OPAM_REPO_REV" -e SSH_PRIVATE_RSA_KEY_B64="`base64 keys/id_rsa`" bulk-local $*
