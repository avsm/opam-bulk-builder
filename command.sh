#!/usr/bin/env bash

COMMAND=$1

shift
WRKDIR=$1

if [ "$WRKDIR" = "" ]; then
  WRKDIR=/home/opam/data
fi

if [ ! -d "${WRKDIR}" ]; then
  echo "Usage: $0 [init|process] <git-data-dir>"
  echo Error: $1 not a valid directory
  exit 1
fi

cd "$WRKDIR"

COMMIT=`git -C /home/opam/opam-repository rev-parse HEAD`
if [ "$COMMIT" = "" ]; then
  echo Unable to get opam-repository commit id
  echo exit 1
fi

STATEDIR="$WRKDIR/state/$COMMIT"
eval `opam config env`

OCAML_VERSION=`ocamlc -version`
ARCH=`uname -m`
SUBDIR="$OCAML_VERSION/$ARCH"
FULLDIR="$STATEDIR/$SUBDIR"

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
  echo opam depext -ui $BUILD > $ODIR/stdout
  rsleep
  rsleep
  STATE=ok
  mkdir -p "$FULLDIR/results/$STATE"
  git rm -q "$FULLDIR/processing/$BUILD"
  echo TODO metadata, built by `uname -n` > "$FULLDIR/results/$STATE/$BUILD"
  gcommit $BUILD
  retry 10 gpush || (logred FAIL Perma push conflict building $BUILD; exit 2)
  loggreen SUCCESS $1
}

gpop() {
  rm -f /tmp/restart
  gpull
  Q=`head -1 "$FULLDIR/packages"`
  if [ "$Q" = "" ]; then
    log No work to do
    echo exit 2
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
  gpull
  rm -rf "$FULLDIR"
  mkdir -p "$FULLDIR"
  opam list -asS > "$FULLDIR/packages"
  mkdir -p "$FULLDIR/queue"
  for p in `cat "$FULLDIR/packages"`; do
    echo 0 > "$FULLDIR/queue/$p"
  done
  git add "$FULLDIR"
  git commit -a -m "add $FULLDIR/packages"
  gpush
  ;;
clean)
  gpull
  rm -rf "$FULLDIR"
  git commit -a -m "clean $FULLDIR"
  gpush
  ;;
process)
  gpop
  ;;
*)
  echo Unknown command $COMMAND
  exit 1
  ;;
esac