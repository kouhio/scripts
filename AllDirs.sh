#!/bin/bash

#Script to run given command in all subdirectories

set_int () {
    exit 1
}

trap set_int SIGINT SIGTERM

for dir in */; do
    if [ -d "$dir" ]; then
        cd "$dir"
        if [ "$?" -eq "0" ]; then
            AllDirs.sh $@
            cd ..
        fi
    fi
done

#echo "executing $PWD $@"
$@
