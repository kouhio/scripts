#!/bin/bash

#Script to run given command in all files in directory

set_int () {
    exit 1
}

trap set_int SIGINT SIGTERM

SSIZE=$(lib file empty)

for file in *; do
    if [ -f "$file" ]; then
        "$@" "$file"
    fi
done

ESIZE=$(lib file empty)
if [ "$ESIZE" -ne "$SSIZE" ]; then
    SIZEC=$((ESIZE - SSIZE))
    TOTSIZE=$(lib size $SIZEC)
    echo -en "Change in HDD $TOTSIZE\n"
fi
