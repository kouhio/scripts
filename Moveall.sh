#!/bin/bash

# Move all files with given extensions from sub-directories to current directory

extensions="mp4 mkv avi wmv webm flv m4v"
skiplist="mp3 part wav"

#If interrupted, make sure no external compressions are continued
set_int () {
    exit 1
}

trap set_int SIGINT SIGTERM

SUCS=0

array=(${extensions//\t})
array2=(${skiplist//\t})

for D in *; do
    size=${#D}
    if [ -d "${D}" ] && [ $size -gt "0" ]; then
        cd "$D"
            SUCS=0
            cnt=`ls -l *.part 2>/dev/null | grep -v ^l | wc -l`
            if [ $cnt -lt "1" ]; then
                for index in "${!array[@]}"
                do
                    cnt=`ls -l *.${array[index]} 2>/dev/null | grep -v ^l | wc -l`
                    if [ $cnt -gt "0" ]; then
                        SUCS=$((SUCS + cnt))
                        mv *${array[index]} ..
                        echo "Found ${array[index]} in $D (*${array[index]})"
                    fi
                done
                if [ $SUCS -gt "0" ]; then
                    for index in "${!array2[@]}"
                    do
                        cnt=`ls -l *.${array2[index]} 2>/dev/null | grep -v ^l | wc -l`
                        if [ $cnt -gt "0" ]; then
                            echo "Found files not to be deleted, not removing directory $D"
                            SUCS=0
                        fi
                    done
                fi
            fi
        cd ..
        if [ $SUCS -gt "0" ]; then
            rm "$D" -fr
            SUCS=0
        fi
    fi
done

if [ $# -ne 0 ]; then
    for index in "${!array[@]}"
    do
        rename "s/${array[index]}/mp4/" *
    done
fi