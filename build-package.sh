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

META=$LOGDIR/${PKG}
mkdir -p ${META}
opam install --show-actions $PKG > ${META}/actions 2>&1
opam show $PKG > ${META}/info 2>&1
starttime=`date +%s`
echo ${starttime} > ${META}/start_time
opam depext -uiv $PKG > ${META}/stdout 2>${META}/stderr
RES=$?
endtime=`date +%s`
echo ${endtime} > ${META}/end_time
difftime=$(($endtime - $starttime))
echo $difftime > ${META}/build_time
exit $RES
