#!/bin/bash

# Move all files with given extensions from sub-directories to current directory

extensions="mp4 mkv avi wmv webm flv m4v mpg srt sub"
skiplist="mp3 part wav"

#If interrupted, make sure no external compressions are continued
set_int () {
    exit 1
}

TARGET=".."
[ ! -z "$1" ] && TARGET="$1"

trap set_int SIGINT SIGTERM

SUCS=0

if [ "$PWD" == "$HOME" ]; then
    echo "home directory! no way!"
    exit 1
fi

array=(${extensions//})
array2=(${skiplist//})
sinput=""

for D in *; do
    size=${#D}
    if [ -d "${D}" ] && [ $size -gt "0" ]; then
        cd "$D"
            SUCS=0
            cnt=$(ls -l *.part 2>/dev/null | grep -v ^l | wc -l)
            if [ $cnt -lt "1" ]; then
                IS_DIR=0
                for DIRE in *; do
                    if [ -d "${DIRE}" ]; then
                        IS_DIR=1
                        if  [ -z "$sinput" ]; then
                            echo "$D has subdirectories $DIRE, continue or skip? (y for continue, anything else to ignore all folders with subdirectories)"
                            read -rsn1 sinput
                        fi

                        if [ "$sinput" == "y" ]; then
                            Moveall.sh
                            IS_DIR=0
                        else
                            IS_DIR=1
                            break;
                        fi
                    fi
                done

                if [ $IS_DIR -eq 1 ]; then
                    cd ..
                    continue
                fi

                for index in "${!array[@]}"; do
                    cnt=$(ls -l *.${array[index]} 2>/dev/null | grep -v ^l | wc -l)
                    if [ $cnt -gt "0" ]; then
                        SUCS=$((SUCS + cnt))
                        mv *${array[index]} "$TARGET"
                        echo "Found ${array[index]} in $D (*${array[index]})"
                    fi
                done

                if [ $SUCS -gt "0" ]; then
                    for index in "${!array2[@]}"; do
                        cnt=$(ls -l *.${array2[index]} 2>/dev/null | grep -v ^l | wc -l)
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
    for index in "${!array[@]}"; do
        rename "s/${array[index]}/mp4/" *
    done
fi
