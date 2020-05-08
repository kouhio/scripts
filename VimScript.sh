#!/bin/bash

#####################################################
# Find tags file, if it exists
#####################################################
findTags () {
    TAG_PATH="$PWD"
    while [ "$TAG_PATH" != "$HOME" ]; do

        if [ -f "${TAG_PATH}/tags" ]; then
            TAG_PATH=":set tags=${TAG_PATH}/tags"
            return
        fi

        TAG_PATH=${TAG_PATH%/*}

        [ -z "$TAG_PATH" ] && break
        [ "$TAG_PATH" == "/" ] && break
    done

    TAG_PATH=""
}

if [ -z "$1" ]; then
    echo "No input files!"
    exit 1
elif [ "$1" == "-h" ]; then
    echo "Open files with vim, open at given row"
    echo "-h for this"
    exit
fi

findTags

FILES=""
COUNT=1
IS_ONE=0
IS_OPEN=0
IS_SWAP=0
VI_PARAMS=""

# 1 - given string
get_rownumber () {
    FILE=""
    ROW=""
    FILENAME=""
    FILEPATH=""

    # Check if input is a parameter
    if [[ "$1" == "-"* ]]; then
        VI_PARAMS+="$1 "
        return
    fi

    # Check that there is only one file with given rownumber
#    if [ "$2" -eq 2 ] && [ "$COUNT" -eq 2 ]; then
    if [ "$COUNT" -eq 2 ]; then
        if [[ "$1" == "+"* ]]; then
            IS_ONE=1
            return
        fi
    fi

    # Check if the rownumber is given in the string
    if [[ "$1" == *":"* ]]; then
        array=(${1//:/ })
        FILE=${array[0]}
        ROW=${array[1]}
    else
        FILE="$1"
    fi

    if [[ "$FILE" == *"/"* ]]; then
        FILENAME="${FILE##*/}"
        FILEPATH="${FILE%/*}"
        if [ -f "${FILEPATH}/.${FILENAME}.swp" ]; then
            IS_OPEN=1
            return
        fi
    elif [ -f ".${FILE}.swp" ]; then
        IS_OPEN=1
        return
    fi

    EXTENSION="${FILE##*.}"
    if [ "$EXTENSION" == "swp" ]; then
        IS_SWAP=1
        return
    fi

    # Add files to array
    if [ -f "$FILE" ]; then
        FILES+="$FILE "
    fi
    COUNT=$((COUNT + 1))
}

# More than one input given, check if multiple files or something else
if [ "$#" -gt 1 ]; then
    # Go through all input files
    for var in "$@"
    do
        get_rownumber "$var" "$#"
    done

    # If has 2 inputs, but one file, then it's a row number or parameter
    if [ "$IS_ONE" -eq 1 ] && [ "$IS_OPEN" -eq 0 ] && [ "$IS_SWAP" -eq 0 ]; then
        if [ -z "$TAG_PATH" ]; then
            vim $@
        else
            vim -c "$TAG_PATH" $@
        fi
    elif [ -z "$FILES" ]; then
        if [ "$IS_OPEN" -eq 0 ] && [ "$IS_SWAP" -eq 0 ]; then
            if [ -z "$TAG_PATH" ]; then
                vim $@
            else
                vim -c "$TAG_PATH" $@
            fi
        else
            echo "All files are already open/swap files!"
        fi
    else
        if [ -z "$TAG_PATH" ]; then
            vim $VI_PARAMS $FILES
        else
            vim -c "$TAG_PATH" $VI_PARAMS $FILES
        fi
    fi
else # One input given, see if it has row number
    # Get file and rownumnber split
    get_rownumber "$1" "1"

    if [ "$IS_SWAP" -eq 1 ]; then
        echo "$1 is a swap file, not opening!"
        exit 1
    fi

    if [ "$IS_OPEN" -eq 0 ]; then
        if [ -z "$ROW" ]; then
            if [ -z "$TAG_PATH" ]; then
                vim $1
            else
                vim -c "$TAG_PATH" $1
            fi
        else
            if [ -z "$TAG_PATH" ]; then
                vim "$FILE" "+$ROW"
            else
                vim -c "$TAG_PATH" "$FILE" "+$ROW"
            fi
        fi
    else
        echo "$1 is already open!"
    fi
fi

