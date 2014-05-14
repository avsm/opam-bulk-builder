#!/usr/bin/env bash
set -ex

VERSION=$1

if [ "$VERSION" = "" ]; then
  echo "Usage: $0 <ocaml-version>"
fi

JOBS=4
DATE=`date +%Y%m%d`
REPO=$(readlink -f `cat REPO`)
if [ ! -d $REPO ]; then
  git clone git@github.com:avsm/opam-bulk-logs $REPO
fi
WRKDIR=`pwd`
cd $REPO
RUN=${DATE}/${VERSION}
rm -f PKGS
for i in $(opam list -s -a); do echo $i >> PKGS; done
mkdir -p $RUN/raw $RUN/err $RUN/ok
cat PKGS | parallel -j ${JOBS} ${WRKDIR}/build-one.sh $VERSION $RUN
git push origin master
