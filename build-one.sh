#!/usr/bin/env bash

IMAGE=$1
VERSION=$2
RUN=$3
p=$4

sudo docker.io run opam:${IMAGE}-${VERSION} opam installext $p > $RUN/raw/$p 2>&1
RES=$?

L=git-lock
lockfile-create $L
lockfile-touch $L &
# Save the PID of the lockfile-touch process
LP="$!"

if [ $RES != 0 ]; then
  ln -sf ../raw/$p $RUN/err/$p
  git add $RUN/err/$p
else
  ln -sf ../raw/$p $RUN/ok/$p
  git add $RUN/ok/$p
fi
git add $RUN/raw/$p
git commit -m "$RUN: $p " -a
git pull --no-edit
git push origin master || true

kill "${LP}"
lockfile-remove $L
