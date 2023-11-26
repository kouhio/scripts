#!/bin/bash

#Script to run given command in all subdirectories

set_int () {
    exit 1
}

trap set_int SIGINT SIGTERM

for dir in */; do
    if [ -d "$dir" ]; then
        cd "$dir" || continue
        AllDirs.sh $@
        cd ..
    fi
done

#echo "executing $PWD $@"
$@
