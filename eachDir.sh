#!/bin/bash

[ -z "$1" ] && echo "No command given" && exit 1

SUB=0
[ "$1" == "sub" ] && SUB=1 && shift

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

if [ "$SUB" -eq "0" ]; then
    mapfile -t DIR_LIST <<< "$(find -type d | sort)"
else
    mapfile -t DIR_LIST <<< "$(find -type d -maxdepth 1 | sort)"
fi

D_MAX="${#DIR_LIST[@]}"
D_CNT=0

for d in "${DIR_LIST[@]}"; do
    D_CNT="$((D_CNT + 1))"
    cd "$d" || continue
    printf "\n[%0${#D_MAX}s/%${#D_MAX}s] Running in %s\n" "${D_CNT}" "${D_MAX}" "$d"
    "${@}"
    cd "$startPath" || continue
done

set_interrupt "1"
