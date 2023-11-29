#!/bin/bash

# Replace all occurences of given string to either TODO or to another given string

INPUT="$1"
REPLACE="\/\/TODO: $1"
TYPES="c cpp h"

# $1 = filetype, $2 = no-exact replace
replace_data() {
    COUNT=$(find . -maxdepth 1 -name "*$1" |wc -l)
    rType=0
    [ -n "$2" ] && rType="$2"

    if [ "$COUNT" -gt 0 ]; then
        if [ "$rType" -eq 0 ]; then
            echo "Replacing exact strings in $1 -files"
            sed -i "s/\<${INPUT}\>/${REPLACE}/g" ./*".$1"
        else
            echo "Replacing strings in $1 -files"
            sed -i "s/${INPUT}/${REPLACE}/g" ./*".$1"
        fi
    fi
}

if [ -n "$1" ]; then
    if [ -n "$2" ]; then
        REPLACE="$2"
    fi

    array=(${TYPES// / })

    if [ -n "$4" ]; then
        array+=($4)
    fi

    if [ "$INPUT" == "$REPLACE" ]; then
        echo "Can't replace '$INPUT' with '$REPLACE', they're the same!"
        exit 1
    fi

    echo -e -n '\033[0;31m'"Sure to replace '$INPUT' with '$REPLACE' in all files  (y/n)?\n"'\033[0m'
    read -rsn1 input

    if [ "$input" == "y" ]; then
        for index in "${!array[@]}"; do
            replace_data "${array[index]}" "$3"
        done

        if [ -n "$2" ]; then
            if [[ ! "$INPUT" =~ "$REPLACE" ]]; then
                VERIFY=$(grep "${INPUT}" -r)
                [ -n "$VERIFY" ] && echo "Failed to replace ${INPUT}"
            fi
        fi
    fi
else
    echo "No input given! 1 = input-string, 2 = replace-string, 3 = no exact replace, 4 = new filetype"
fi
