#!/bin/bash

[ -z "$1" ] && echo "No command given" && exit 1

startSize=`df --output=avail "$PWD" | sed '1d;s/[^0-9]//g'`
startTime=$(date +%s)
startPath="$PWD"

for d in */ ; do
    error=0
    echo "$d"
    cd "$d" || error=1

    if [ "$error" == "0" ]; then
        echo "Running in $d"
        $@
    fi

    cd "$startPath"
done

endSize=`df --output=avail "$PWD" | sed '1d;s/[^0-9]//g'`
totalSize=$((endSize - startSize))
endTime=$(date +%s)
totalTime=$((endTime - startTime))
timeOut=$(date -d@${totalTime} -u +%T)

if [ "$totalSize" -ne "0" ]; then
    totalSize=$((totalSize / 1000))
    echo -en "Sizechange $totalSize Mb - "
fi

echo "Time taken $timeOut"

