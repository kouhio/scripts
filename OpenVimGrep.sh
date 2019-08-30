#!/bin/bash

# Open files with vim that have the given string

if [ -z "$1" ]; then
    echo "No input string given!"
    exit 1
fi

# If input 2 is set, then will choose files that don't have given string
if [ -z "$2" ]; then
    DATA=$(grep -r -c "$1" | grep -v ":0")
else
    DATA=$(grep -r -c "$1" | grep ":0")
fi

array=(${DATA// /})
FILES=""

for index in "${!array[@]}"
do
    SPLIT=${array[index]%:*}
    if [ -f "$SPLIT" ]; then
        FILES+="$SPLIT "
    fi
done

if [ ! -z "$FILES" ]; then
    vi $FILES
else
    echo "No files with '$1' found!"
fi
