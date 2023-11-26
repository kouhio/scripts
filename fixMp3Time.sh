#!/bin/bash

#************************************************************************
# If interrupted, stop all processess
#************************************************************************
set_int () {
    echo "Main conversion interrupted!"
    exit 1
}

trap set_int SIGINT SIGTERM

#************************************************************************
# Initialize variables
#************************************************************************
init() {
    cnt=0
    #depth=0

    #START=$(pwd)
    #CURR="$START"
}

#************************************************************************
# Go through all files in directory and fix possible problems
#************************************************************************
check_files() {
    CNT=0
    for F in *.mp3; do
        mp3val "${F}" -f -t >/dev/null 2>&1
        CNT=$(( CNT + 1 ))
        echo "$CNT of $cnt fixed ($F)"
    done
}

#************************************************************************
# Process directory files and directories
#************************************************************************
process_directory() {
    for D in *; do
        if [ "$D" == "lost+found" ]; then
            continue
        elif [ -d "${D}" ]; then
            cd "$D" || continue
            echo "Entering directory $D"
            cnt=$(find . -maxdepth 1 -name "*.mp3" |wc -l)
            if [ "$cnt" -gt "0" ]; then
                check_files
            else
                process_directory
            fi
            cd ..
        fi
    done
}

#**********************************************************************************
# Verify necessary external programs
#**********************************************************************************
verify_dependencies() {
    error_code=0
    hash mp3val || error_code=$?

    if [ $error_code -ne 0 ]; then
        echo "Missing one mp3val, please install"
        exit 1
    fi
}
#************************************************************************
# Start process
# 1 - Possible input directory or file
#************************************************************************
main() {
    if [ -z "$1" ]; then
        process_directory
    else
        if [ -d "$1" ]; then
            cd "$1" || echo "Something wrong with $1, can't enter directory!" && exit 1
            process_directory
            cd ..
        else
            FILE="${1##*.}"
            if [ "$FILE" == "mp3" ]; then
                mp3val "${FILE}" -f -t >/dev/null 2>&1
            else
                echo "$1 is not a mp3 file"
                exit 1
            fi
        fi
    fi
}

#************************************************************************
# Main function
#************************************************************************
verify_dependencies
init
main "$1"
