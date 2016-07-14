#!/usr/bin/env bash

set -e

if [ ! -e keys/id_rsa ]; then
  echo Need to generate key first with generate-keys
  exit 1
fi

OPAM_REPO_REV=$(curl --silent https://api.github.com/repos/ocaml/opam-repository/branches| jq -cr '.[] | select (.name | contains("master"))? | .commit.sha')
export OPAM_REPO_REV

docker service create \
  --replicas 3 \
  --name opam-build \
  --restart-condition on-failure \
  --network opam-net \
  -e OPAM_REPO_REV="${OPAM_REPO_REV}" \
  -e SSH_PRIVATE_RSA_KEY_B64="`base64 keys/id_rsa`" \
  avsm/opam-bulk-build process
