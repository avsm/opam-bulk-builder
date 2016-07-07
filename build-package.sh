#!/usr/bin/env bash
# Build an OPAM package for a given OS/OCaml version combination.

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
opam depext -uiv $PKG > ${LOGDIR}/stdout 2>${LOGDIR}/stderr
RES=$?
endtime=`date +%s`
echo ${endtime} > ${LOGDIR}/end_time
difftime=$(($endtime - $starttime))
echo $difftime > ${LOGDIR}/build_time
exit $RES
