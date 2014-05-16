#!/usr/bin/env bash
set -ex

IMAGE=$1
VERSION=$2

if [ "$VERSION" = "" ]; then
  echo "Usage: $0 <image> <ocaml-version>"
  exit 1
fi

JOBS=4
DATE=`date +%Y%m%d`
. ./config.sh
if [ ! -d $LOG_REPO ]; then
  git clone $LOG_REPO_URL $LOG_REPO
fi
WRKDIR=`pwd`
cd $LOG_REPO
RUN=${DATE}/${VERSION}
rm -f PKGS
for i in $(opam list -s -a); do echo $i >> PKGS; done
mkdir -p $RUN/raw $RUN/err $RUN/ok
cat PKGS | parallel -j ${JOBS} ${WRKDIR}/build-one.sh $IMAGE $VERSION $RUN
git push origin master
