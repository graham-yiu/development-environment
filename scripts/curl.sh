#!/bin/bash -e

if [ $# -ne 1 ]; then
  echo "[ ERROR ] Must supply URL as argument"
  exit 1
fi
set -x
curl -u $(whoami) $1 -o $(basename $1)
set +x
