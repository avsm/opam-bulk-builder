#!/bin/sh -ex

# This requires a node names "swarm-1" with a host "/logs" directory
# to store all the log files.
docker service create --mode replicated --replicas 1 --name logs \
  --publish 8080:8080 --mount type=bind,source=/logs,target=/logs \
  --constraint 'node.hostname == swarm-1' --network opam-net \
  avsm/opam-log-server -d /logs -vvvv
