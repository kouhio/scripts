#!/bin/bash

#Scripts to run another scripts forever, in case of break

RUNNING=1

set_int () {
    RUNNING=0
}

trap set_int SIGINT SIGTERM

while [ "$RUNNING" -eq 1 ]; do
    "$@"
    sleep 1
done
