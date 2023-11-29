#!/bin/bash

#Script to run given command in all subdirectories

set_int () {
    exit 1
}

trap set_int SIGINT SIGTERM

SSIZE=$(lib file empty)

for dir in */; do
    if [ -d "$dir" ]; then
        cd "$dir" || continue
        AllDirs.sh $@
        cd ..
    fi
done

echo "Entering $(pwd)"
$@

ESIZE=$(lib file empty)
if [ "$ESIZE" -ne "$SSIZE"]; then
    SIZEC=$((ESIZE - SSIZE))
    TOTSIZE=$(lib size $SIZEC)
    echo -en "Change in HDD $TOTSIZE\n\n"
else
    echo -en "\n\n"
fi
