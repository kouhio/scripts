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
# Initialize arguments
#**************************************************************************************************************
init () {
    FILENAME=""         # Current filename
    SILENCEDATA=""      # Current file's silencedata
    DURATION=5          # Duration of silence to be seeked
    MIN_DURATION=0      # Minimum duration of piece to be separated
    NOISE=0.001         # Noise limit, to be concidered silence
    FILE=""             # Output filename for filelist
    SPLIT=0             # Enable split of file
    TARGET_EXT=""       # Convert input to this format
    DELETE=0            # Delete original file after done
    ERROR=0             # Error has happened during extraction
    error_code=0        # Error checking code for external functionalities
}

#**************************************************************************************************************
# Print help options
#**************************************************************************************************************
print_help() {
    echo "Usage: $0 -options"
    echo "Without any options, will start from current directory and recursively go through everything with default options."
    echo "Options with arguments:"
    echo "-h    This help window"
    echo "-i    Input filename or directory (works also without prefix)"
    echo "-d    Minimum duration in seconds to be calculated as silence (default: 5)"
    echo "-n    Noise level maximum to be calculated as silence (default: 0.001)"
    echo "-f    Output filename for list of files with silence (instead of splitting)"
    echo "-t    Target output format extensioni (default: input filetype)"
    echo "-m    Minimum duration of piece to be extracted (default: same as silence minimum duration)"
    echo "Options without arguments: "
    echo "-s    Split input file to files without silence"
    echo "-D    Delete input file after successful splitting"
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

    SHORT="d:n:m:f:t:sDhi:"

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
                DURATION="$2"
                shift 2
                ;;
            -n)
                NOISE="$2"
                shift 2
                ;;
            -f)
                FILE="$2"
                shift 2
                ;;
            -t)
                TARGET_EXT="$2"
                shift 2
                ;;
            -m)
                MIN_DURATION="$2"
                shift 2
                ;;
            -D)
                DELETE=1
                shift
                ;;
            -s)
                SPLIT=1
                shift
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

#**************************************************************************************************************
# Write list of files with silence or print data of found files with silence
# 1 - Found silencedata
#**************************************************************************************************************
write_silencedata () {
    SILENCEDATA="$1"
    DATA=$(echo "$SILENCEDATA" | grep "silence_duration:") # | awk '{print $2}')
    DATA1=`echo $DATA | cut -d \| -f 2`
    if [ -z "$DATA1" ]; then
        DATA1="$SILENCEDATA"
    fi

    if [ -z $FILE ]; then
        Color.sh red
        echo "$PWD -> $DATA1"
        Color.sh
    else
        echo "$PWD / $1 -> $DATA1" >> $FILE
    fi
}

#**************************************************************************************************************
# Split data from file between silences
# 1 - filename
# 2 - starttime
# 3 - duration
# 4 - number
#**************************************************************************************************************
split_to_file () {
    error_code=0
    if [ -z $TARGET_EXT ]; then
        OUTPUT=$(printf "%02d_$1" "$4")
    else
        OUTPUT=$(printf "%02d_${1%.*}.$TARGET_EXT" "$4")
    fi

    echo "Extracting $OUTPUT | Start: $2 Duration: $3"
    if [ -z $TARGET_EXT ]; then
        ffmpeg -i "$1" -ss "$2" -t "$3" "$OUTPUT" -v quiet >/dev/null 2>&1 || error_code=$?
    elif [ -z $TARGET_EXT == "mp3" ]; then
        ffmpeg -i "$1" -ss "$2" -t "$3" -codec:a libmp3lame -q:a 0 "$OUTPUT" -v quiet >/dev/null 2>&1 || error_code=$?
    else
        ffmpeg -i "$1" -ss "$2" -t "$3" "$OUTPUT" -v quiet >/dev/null 2>&1 || error_code=$?
    fi

    if [ $error_code -ne 0 ]; then
        Color.sh red
        echo "ffmpeg failed to extract $4 audio from $1"
        Color.sh
        ERROR=1
    fi
}

#**************************************************************************************************************
# Parse found silencedata and split input file to separate files with audio only
# 1 - Found silencedata
# 2 - Source filename
#**************************************************************************************************************
split_file_by_silence () {
    SILENCEDATA="$1"
    array=(${1//})
    START=0
    END=0
    FILENUMBER=1
    TOTAL_LENGTH=`ffprobe -i "$2" -show_entries format=duration -v quiet -of csv="p=0"`

    if [ $MIN_DURATION -le 0 ]; then
        MIN_DURATION="$DURATION"
    fi

    for index in "${!array[@]}"
    do
        if [[ ${array[index]} =~ "silence_start" ]]; then
            if (( $(echo "${array[index + 1]} > 0" |bc -l) )); then
                START=$(bc <<< "${array[index + 1]} + 0.25")
            fi
        elif [[ ${array[index]} =~ "silence_end" ]]; then
            END=$(bc <<< "${array[index + 1]} - 0.25")
        fi

        if [ $END != "0" ] && [ $START != "0" ]; then
            if ((  $(echo "$START < $END" |bc -l) )); then
                # There is no silence in the beginning, so the first file start from the beginning
                split_to_file "$2" "0" "$START" "$FILENUMBER"
                START=0
            else
                DURATION_2=$(bc <<< "$START - $END")
                if  (( $(echo "$DURATION_2< $MIN_DURATION" |bc -l) )); then
                    FILENUMBER=$((FILENUMBER - 1))
                else
                    split_to_file "$2" "$END" "$DURATION_2" "$FILENUMBER"
                fi
                START=0
                END=0
            fi
            FILENUMBER=$((FILENUMBER + 1))
        fi
    done

    if [ $END != "0" ]; then
        # The is no silence at the end of the file, so the last file is created here
        DURATION_2=$(bc <<< "$TOTAL_LENGTH - $END")
        split_to_file "$2" "$END" "$DURATION_2" "$FILENUMBER"
    fi

    if [ $ERROR == "0" ] && [ $DELETE == "1" ]; then
        echo "everythings fine, deleting original"
        rm "$2"
    fi
}

#**************************************************************************************************************
# Check if given file has silence within given parameters and either split or add to output list
# 1 - Sourcefile
#**************************************************************************************************************
check_file () {
    EXT="${1##*.}"
    if [ "mp3" == "$EXT" ] || [ $EXT == "wav" ]; then
        if [ -f "$1" ]; then
            SILENCEDATA=`ffmpeg -i "$1" -af silencedetect=noise=$NOISE:d=$DURATION -f null - 2>&1 >/dev/null |grep "silence" `
            if [ ! -z "$SILENCEDATA" ]; then
                if [ $SPLIT == 1 ]; then
                    split_file_by_silence "$SILENCEDATA" "$1"
                else
                    write_silencedata "$SILENCEDATA"
                fi
            fi
        fi
    fi
}

#**************************************************************************************************************
# Go through all files and directories in given directory and act accordingly
#**************************************************************************************************************
do_directory () {
    for f in *
    do
        if [ "$f" != "lost+found" ]; then
            if [ -f "$f" ]; then
                check_file "$f"
            elif [ -d "$f" ]; then
                # Enter directory and repeat function recursively
                cd "$f"
                if [ $? == "0" ]; then
                    echo "Entering $f"
                    do_directory
                    cd ..
                fi
            fi
        fi
    done
}

#**********************************************************************************
# Verify necessary external programs
#**********************************************************************************
verify_dependencies() {
    error_code=0
    hash ffmpeg || error_code=$?
    hash ffprobe || error_code=$?
    hash awk || error_code=$?

    if [ $error_code -ne 0 ]; then
        echo "Missing one (or more) necessary dependencies: ffmpeg, ffprobe, awk"
        exit 1
    fi
}

#**************************************************************************************************************
# The main function
#**************************************************************************************************************
run_main() {
    if [ ! -z "$FILE" ]; then
        echo "Seeking silence with $DURATION secs or more" > "$FILE"
    fi

    if [ -z "$FILENAME" ]; then
        echo "Starting seek from $PWD"
        do_directory
    elif [ -d "$FILENAME" ]; then
        echo "Starting seek from directory $FILENAME"
        cd "$FILENAME"
        do_directory
        cd ..
    else
        echo "Seeking silence from $FILENAME"
        check_file "$FILENAME"
    fi
}

#**************************************************************************************************************

verify_dependencies
init
parse_arguments "$@"

run_main
