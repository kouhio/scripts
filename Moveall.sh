#!/bin/bash

# Move all files with given extensions from sub-directories to current directory

extensions="mp4 mkv avi wmv webm flv m4v mpg srt sub"
skiplist="mp3 part wav"

#If interrupted, make sure no external compressions are continued
set_int () {
    exit 1
}

TARGET=".."
[ -n "$1" ] && TARGET="$1"

trap set_int SIGINT SIGTERM

SUCS=0

if [ "$PWD" == "$HOME" ]; then
    echo "home directory! no way!"
    exit 1
fi

mapfile -t -d " " array < <(printf "%s" "$extensions")
mapfile -t -d " " array2 < <(printf "%s" "$skiplist")
sinput="${1}"

for D in *; do
    size=${#D}
    if [ -d "${D}" ] && [ "$size" -gt "0" ]; then
        cd "$D" || continue
            SUCS=0
            cnt=$(find . -maxdepth 1 -name "*.part" |wc -l)
            if [ "$cnt" -lt "1" ]; then
                IS_DIR=0
                for DIRE in *; do
                    if [ -d "${DIRE}" ]; then
                        IS_DIR=1
                        if  [ -z "$sinput" ]; then
                            echo "$D has subdirectories $DIRE, continue or skip? (y for continue, anything else to ignore all folders with subdirectories)"
                            read -rsn1 sinput
                        fi

                        if [ "$sinput" == "y" ]; then
                            Moveall.sh "${sinput}"
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
                    cnt=$(find . -maxdepth 1 -name "*.${array[index]}" |wc -l)
                    if [ "$cnt" -gt "0" ]; then
                        SUCS=$((SUCS + cnt))
                        mv ./*"${array[index]}" "$TARGET"
                        echo "Found ${array[index]} in $D (*${array[index]})"
                    fi
                done

                if [ $SUCS -gt "0" ]; then
                    for index in "${!array2[@]}"; do
                        cnt=$(find . -maxdepth 1 -name "*.${array2[index]}" |wc -l)
                        if [ "$cnt" -gt "0" ]; then
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

for D in *; do
    size=${#D}
    if [ -d "${D}" ] && [ "$size" -gt "0" ]; then
        DIRECTORY="${D,,}"
        mapfile -t -d '-' DIRLIST < <(printf "%s" "$DIRECTORY")
        for f in *; do
            if [ -f "$f" ]; then
                EXT="${f##*.}"
                for index in "${array[@]}"; do
                    if [ "$index" == "$EXT" ]; then
                        FILENAME="${f//./ }"
                        FILENAME="${FILENAME,,}"
                        for dir in "${DIRLIST[@]}"; do
                            if [[ "${FILENAME}" == *"${dir// / }"* ]]; then
                                mv "${f}" "${D}/"
                                echo "Moving '$f' to '$D'"
                            fi
                        done
                    fi
                done
            fi
        done
    fi
done

rm -fr *.srt
#if [ $# -ne 0 ]; then
#    for index in "${!array[@]}"; do
#        rename "s/${array[index]}/mp4/" *
#    done
#fi
