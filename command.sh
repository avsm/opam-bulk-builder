#!/usr/bin/env bash

COMMAND=$1
shift

WRKDIR=/home/opam/data

if [ ! -d "${WRKDIR}" ]; then
  echo "Usage: $0 [init|process] <git-data-dir>"
  echo Error: $1 not a valid directory
  exit 0
fi

cd "$WRKDIR"

OCAML_VERSION=`ocamlc -version`
ARCH=`uname -m`
eval `opam config env`

if [ "$OPAM_REPO_REV" = "" ]; then
  echo Must set OPAM_REPO_REV to the Git SHA of the desired changeset to build
  exit 0
fi

git -C /home/opam/opam-repository pull
git -C /home/opam/opam-repository checkout $OPAM_REPO_REV || exit 0
opam update -u -y
# TODO optimize this to not require opam update if cset hasnt changed

COMMIT=$OPAM_REPO_REV
STATEDIR="$WRKDIR/state/$COMMIT"
SUBDIR="$OCAML_VERSION/$ARCH"
FULLDIR="$STATEDIR/$SUBDIR"

## Logging in pretty colors
green='\e[0;32m'
red='\e[0;31m'
endColor='\e[0m'

loggreen() {
  echo -e `uname -n`: ${green}$*${endColor}
}

log() {
  echo `uname -n`: $*
}

logred() {
  echo -e `uname -n`: ${red}$*${endColor}
}

rsleep() {
  sleep $[ ( $RANDOM % 5 ) + 2 ]
}

retry()
{
  local n=0
  local try=$1
  local cmd="${@: 2}"
  [[ $# -le 1 ]] && {
    echo "Usage $0 <retry_number> <Command>"; }
    until [[ $n -ge $try ]]
    do
      $cmd && break || {
        log "Command Fail: $cmd"
        ((n++))
        log "retry $n ::"
        sleep 1;
      }
    done
}

gundocommit() {
  log gundocommit
  git reset HEAD^
  git reset --hard
  git clean -fd
}

gcommit() {
  BUILD=$1
  log gcommit
  git add $FULLDIR
  git commit -q -a -m "build log for $BUILD"
}

ginitpull() {
  log ginitpull
  git pull -q -r --no-commit --no-edit || (log aborting rebase; git rebase --abort; rsleep; return 1)
  git checkout --track -B state-$OPAM_REPO_REV
  return 0
}

gpull() {
  log gpull
  git pull -q -r --no-commit --no-edit || (log aborting rebase; git rebase --abort; rsleep; return 1)
  return 0
}

gpush() {
  # TODO retry gpull a few times in case of temp conflict
  gpull
  RET=$?
  if [ $RET -eq 0 ]; then
    if git push -q worigin ; then
      log "gpush: ok"
    else
      log "gpush: push failed"
      return 1
    fi
  else
    log "gpush: pull conflict"
    return 1
  fi
  return 0
}

dobuild() {
  BUILD=$1
  ODIR=$2
  log "Building $BUILD"
  /home/opam/build-package.sh $ODIR $BUILD
  RET=$?
  if [ $RET -eq 0 ]; then
    STATE=ok
  else
    STATE=err
  fi
  echo $STATE > $ODIR/result
  mkdir -p "$FULLDIR/results/$STATE"
  git rm -q "$FULLDIR/processing/$BUILD"
  echo TODO metadata, built by `uname -n` > "$FULLDIR/results/$STATE/$BUILD"
  gcommit $BUILD
  retry 20 gpush || (logred FAIL Perma push conflict building $BUILD; exit 0)
  loggreen SUCCESS $1
  exit 1
}

gpop() {
  if [ ! -e "$FULLDIR/packages" ]; then
    echo Need to initialise the package list before processing this queue
    echo Normal exit code to avoid restarting.
    exit 0
  fi
  Q=`head -1 "$FULLDIR/packages"`
  if [ "$Q" = "" ]; then
    log "No work to do, normal exit code"
    exit 0
  fi
  tail -n +2 "$FULLDIR/packages" > "$FULLDIR/packages.new"
  mv "$FULLDIR/packages.new" "$FULLDIR/packages"
  log "Attempting gpop on $Q"
  NODE=`uname -n`
  mkdir -p "$FULLDIR/processing"
  git mv "$FULLDIR/queue/$Q" "$FULLDIR/processing/$Q"
  echo $NODE > "$FULLDIR/processing/$Q"
  git commit -q -a -m "pop $Q"
  gpush
  RET=$?
  if [ $RET -gt 0 ]; then
    log Push Conflict during pop
    gundocommit
    rsleep
    gpop
  else
    log gpush succeeded
    ODIR="$FULLDIR/logs/$Q"
    rm -rf "$ODIR"
    mkdir -p "$ODIR"
    dobuild $Q $ODIR
  fi
}

cd "$WRKDIR"
case $COMMAND in
init)
  ginitpull
  rm -rf "$FULLDIR"
  mkdir -p "$FULLDIR"
  opam list -asS $* > "$FULLDIR/packages"
  mkdir -p "$FULLDIR/queue"
  for p in `cat "$FULLDIR/packages"`; do
    echo 0 > "$FULLDIR/queue/$p"
  done
  git add "$FULLDIR"
  git commit -a -m "add $FULLDIR/packages"
  gpush
  ;;
clean)
  ginitpull
  rm -rf "$FULLDIR"
  git commit -a -m "clean $FULLDIR"
  gpush
  ;;
process)
  ginitpull
  gpop
  ;;
*)
  echo Unknown command $COMMAND
  exit 0
  ;;
esac
