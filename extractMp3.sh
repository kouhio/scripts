#!/bin/bash

#**************************************************************************************************************
# If the script is cancelled, will stop all functionlity
#**************************************************************************************************************
set_int () {
    echo "$0 has been interrupted!"
    exit 1
}

trap set_int SIGINT SIGTERM

#**************************************************************************************************************
# Print help options
#**************************************************************************************************************
print_help() {
    echo "Usage: $0 -options"
    echo "Options with arguments:"
    echo "-h    This help window"
    echo "-i    Input filename or directory (works also without prefix)"
    echo "-d    Duration to extract from start time (hh:mm:ss) or seconds"
    echo "-s    Start time for extration point (hh:mm:ss) or seconds"
    echo "-e    End time for extraction point (alternative for duration) (hh:mm:ss) or seconds"
    echo "-o    Output filename (default: same as original file plus .mp3"
}

#**********************************************************************************
# Initialize parameters
#**********************************************************************************
init () {
    FILENAME=""
    TARGET=""
    STARTTIME=0
    DURATION_TIME=0
    ENDTIME=0
    ZERORETVAL=0
    CALCTIME=0
}

#************************************************************************************************************************
# Extract defined part from a given input file and convert into mp3
# 1 - filename
# 2 - start time
# 3 - duration
#************************************************************************************************************************
extract_from_file() {
    error_code=0
    if [ $# -ne 3 ]; then
        echo "Not enough parameters!"
        exit 1
    fi

    if [ -z "$TARGET" ]; then
        OUTPUT="${1%%.*}.mp3"
    else
        EXT="${TARGET##*.}"
        OUTPUT="$TARGET"
        if [ "$EXT" != "mp3" ]; then
            OUTPUT+=".mp3"
        fi
    fi

    SOURCE="$1"
    START="$2"
    DURATION="$3"
    if [ "$DURATION" -le 0 ]; then
        DURATION="$TOTAL_LENGHT"
    fi
    echo "Extracting $OUTPUT starting from: $STARTTIME with duration:$DURATION"
    ffmpeg -i "$SOURCE" -ss "$START" -t "$DURATION" -codec:a libmp3lame -q:a 0 "$OUTPUT" -v quiet >/dev/null 2>&1 || error_code=$?

    if [ $error_code -ne 0 ]; then
        echo "Something failed while extracting"
        rm "$OUTPUT"
        exit 1
    fi
}

#**********************************************************************************
# Verify necessary external programs
#**********************************************************************************
verify_dependencies() {
    error_code=0
    hash ffmpeg || error_code=$?
    hash awk || error_code=$?

    if [ $error_code -ne 0 ]; then
        echo "Missing one (or more) necessary dependencies: ffmpeg, awk"
        exit 1
    fi
}

#**************************************************************************************************************
# Calculate duration from given ENDTIME
#**************************************************************************************************************
calculate_duration() {
    if [ -z "$ENDTIME" ]; then
        echo "Endtime not correct!"
        exit 1
    fi
    DURATION_TIME=$((ENDTIME - STARTTIME))
}

#***************************************************************************************************************
# Check if given value starts with a 0 and remove it
#***************************************************************************************************************
check_zero () {
    ZERORETVAL="$1"
    ttime="${1:0:1}"
    if [ ! -z $ttime ]; then
        if [ $ttime == "0" ]; then
            ZERORETVAL="${1:1:1}"
        fi
    fi
}

#***************************************************************************************************************
#Separate and calculate given time into seconds and set to corresponting placeholder
#***************************************************************************************************************
calculate_time () {
    if [ ! -z $1 ]; then
        t1=`echo $1 | cut -d : -f 1`
        t2=`echo $1 | cut -d : -f 2`
        t3=`echo $1 | cut -d : -f 3`

        occ=$(grep -o ":" <<< "$1" | wc -l)

        check_zero $t1
        t1=$ZERORETVAL
        check_zero $t2
        t2=$ZERORETVAL
        check_zero $t3
        t3=$ZERORETVAL

        if [ $occ == "0" ]; then
            calc_time=$1
        elif [ $occ == "1" ]; then
            t1=$((t1 * 60))
            calc_time=$((t1 + t2))
        else
            t1=$((t1 * 3600))
            t2=$((t2 * 60))
            calc_time=$((t1 + t2 + t3))
        fi

        CALCTIME=$calc_time
    else
        CALCTIME=0
    fi
}

#**************************************************************************************************************
# Parse argument options
# 1 - the input array
#**************************************************************************************************************
parse_arguments () {
    getopt --test > /dev/null || error_code=$?
    if [[ $error_code -ne 4 ]]; then
        echo "$0 getopt --test failed!"
        exit 1
    fi

    SHORT="i:d:s:e:o:h"

    PARSED=$(getopt --options $SHORT --name "$0" -- "$@")
    if [[ $? -ne 0 ]]; then
        print_help
        exit 1
    fi

    eval set -- "$PARSED"

    while true; do
        case "$1" in
            -h)
                print_help
                exit
                ;;
            -i)
                FILENAME="$2"
                shift 2
                ;;
            -d)
                calculate_time "$2"
                DURATION_TIME="$CALCTIME"
                shift 2
                ;;
            -o)
                TARGET="$2"
                shift 2
                ;;
            -s)
                calculate_time "$2"
                STARTTIME="$CALCTIME"
                shift 2
                ;;
            -e)
                calculate_time "$2"
                ENDTIME="$CALCTIME"
                shift 2
                ;;
            --)
                FILENAME="$2"
                shift 2
                break
                ;;
            *)
                exit 1
                ;;
        esac
    done
}

#**********************************************************************************
# Run extraction script
#**********************************************************************************
run_script() {
    if [ $ENDTIME -ne 0 ]; then
        calculate_duration
    fi

    if [ -f "$FILENAME" ]; then
        extract_from_file "$FILENAME" "$STARTTIME" "$DURATION_TIME"
    else
        echo "$FILENAME not found!"
        exit 1
    fi
}

#**********************************************************************************
# Main function
#**********************************************************************************
verify_dependencies
init
parse_arguments "$@"

run_script
