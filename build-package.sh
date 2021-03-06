#!/usr/bin/env bash
# Build an OPAM package for a given OS/OCaml version combination.

set -x

LOGDIR=$1
shift
PKG=$*
shift

if [ "$PKG" = "" ]; then
  echo "Usage: $0 <logdir> <pkg1> <pkg2> ..."
  exit 1
fi

opam install --show-actions $PKG > ${LOGDIR}/actions 2>&1
opam show $PKG > ${LOGDIR}/info 2>&1
starttime=`date +%s`
echo ${starttime} > ${LOGDIR}/start_time
TMPLOG=/tmp/json.log
jsontee -vvv -o ${TMPLOG} -- opam-depext -uivy $PKG 
# TODO parse out exit code and set RES to that to signal error
hash=`curl -s --data-binary @${TMPLOG} -X POST http://logs:8080/logs | jq -r .id`
echo $hash > ${LOGDIR}/logs
RES=$?
endtime=`date +%s`
echo ${endtime} > ${LOGDIR}/end_time
exit $RES
