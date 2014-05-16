#!/bin/sh

. ./config.sh

p=`pwd`
#DRY=echo
if [ ! -d "$DOCKER_REPO" ]; then
  git clone $DOCKER_REPO_URL $DOCKER_REPO
else
  cd $DOCKER_REPO && git pull 
fi

$DRY cd $DOCKER_REPO

for v in $VERSIONS; do
  for i in $BASE_IMAGES; do
    $DRY ./build.sh $i $v 2>&1 | tee -a $p/build-image.log
    cd $p
    $DRY ./bulk-build.sh $i $v 2>&1 | tee -a $p/build.log
  done
done
