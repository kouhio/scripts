#!/bin/bash

if [ -z "$1" ] || [ "$1" == "-h" ]; then
    echo "Grep and open files with given string"
    echo "-h this"
    echo "1 - string to seek from files"
    echo "2 - inverse search (aka, files NOT having the given string) set as I to do a non-case sensitive search instead"
    exit 1
fi

# If input 2 is set, then will choose files that don't have given string
if [ -z "$2" ]; then
    DATA=$(grep -r -c -E $1 --exclude=*.o --exclude-dir=bin | grep -v ":0")
else
    if [ "$2" == "I" ]; then
        DATA=$(grep -r -c -i -E $1 --exclude=*.o --exclude-dir=bin | grep -v ":0")
    else
        DATA=$(grep -r -c -E $1 --exclude=*.o --exclude-dir=bin | grep ":0")
    fi
fi

array=(${DATA// /})
FILES=""

for index in "${!array[@]}"
do
    SPLIT=${array[index]%:*}
    if [ -f "$SPLIT" ]; then
        EXT="${SPLIT##*.}"
        [ "$EXT" == "so" ] && continue
        [ "$EXT" == "o" ] && continue
        [ "$EXT" == "bin" ] && continue
        [ "$EXT" == "swp" ] && continue
        [ "$SPLIT" == "tags" ] && continue
        [[ "$SPLIT" =~ ".git" ]] && continue
        FILES+="$SPLIT "
    fi
done

if [ ! -z "$FILES" ]; then
    VimScript.sh $FILES
else
    echo "No files with '$1' found!"
fi
