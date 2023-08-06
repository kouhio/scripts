#!/bin/bash

[ -z "$1" ] && echo "No command given" && exit 1

startSize=$(df --output=avail "$PWD" | sed '1d;s/[^0-9]//g')
startTime=$(date +%s)
startPath="$PWD"
GLOBAL_FILESAVE=0

set_interrupt () {
    [ -z "$1" ] && echo -en "Interrupted! "
    endSize=$(df --output=avail "$PWD" | sed '1d;s/[^0-9]//g')
    totalSize=$((endSize - startSize))
    endTime=$(date +%s)
    totalTime=$((endTime - startTime))
    timeOut=$(date -d@${totalTime} -u +%T)

    if [ "$totalSize" -ne "0" ]; then
        totalSize=$((totalSize / 1000))
        echo -en "Sizechange $totalSize Mb - "
    fi

    if [ "$GLOBAL_FILESAVE" -ne "0" ]; then
        GLOBAL_FILESAVE=$((GLOBAL_FILESAVE / 1000))
        echo -en " totally saved:$GLOBAL_FILESAVE Mb - "
    fi

    echo "Time taken $timeOut"
    exit 1
}

trap set_interrupt SIGINT SIGTERM

for d in */ ; do
    error=0
    cd "$d" || error=1

    if [ "$error" == "0" ]; then
        echo -en "\nRunning in $d\n"
        source $@
    else
        echo -en "\nFailed to enter $d\n"
    fi

    cd "$startPath"
done

set_interrupt "1"
