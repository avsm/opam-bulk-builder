#!/usr/bin/env bash

VERSION=$1
RUN=$2
p=$3

sudo docker.io run opam:ubuntu-${VERSION} opam installext $p > $RUN/raw/$p 2>&1
if [ $? != 0 ]; then
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
