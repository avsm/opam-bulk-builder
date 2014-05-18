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
WRKDIR=`pwd`
. ./config.sh
if [ ! -d $LOG_REPO ]; then
  git clone $LOG_REPO_URL $LOG_REPO
else
  cd $LOG_REPO && git pull --no-edit
fi
cd $LOG_REPO
RUN=${DATE}/${VERSION}
rm -f PKGS
PKGS=`sudo docker.io run opam:$IMAGE-$VERSION opam list -s -a`
for i in $PKGS; do echo $i >> PKGS-$IMAGE-$VERSION; done
mkdir -p $RUN/raw $RUN/err $RUN/ok
cat PKGS-$IMAGE-$VERSION | parallel -j ${JOBS} ${WRKDIR}/build-one.sh $IMAGE $VERSION $RUN
git push origin master
