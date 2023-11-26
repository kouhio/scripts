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
    NAMEPATH=""         # path to text file with previously given filenames in order
    CURRENT_NAME=""     # trackname found from the file
    TARGET_DIR=""       # Directory where to put the output files
    INFO_FROM_FILE=""   # Split data from file instead of silence
    NAMECOUNT=0         # Number of tracks in the namefile
    LASTFILENO=0        # Last separated audio item number
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
    echo "-t    Target output format extension (default: input filetype)"
    echo "-m    Minimum duration of piece to be extracted (default: same as silence minimum duration)"
    echo "-F    Path to filenames in order to put as output tracks (add to D:target path to file for automatic output dir)"
    echo "-T    Path to output directory"
    echo "-S    Path to file with splitting information (start-end;trackname)"
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

    SHORT="d:n:m:f:F:t:T:sDhi:S:"

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
                FILE="${PWD}/${2}"
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
            -S)
                INFO_FROM_FILE="$2"
                NAMEPATH="$2"
                NAMECOUNT=$(cat "$NAMEPATH" |wc -l)
                NAMECOUNT=$((NAMECOUNT - 1))
                shift 2
                ;;
            -F)
                NAMEPATH="$2"
                NAMECOUNT=$(cat "$NAMEPATH" |wc -l)
                NAMECOUNT=$((NAMECOUNT - 1))
                shift 2
                ;;
            -T)
                TARGET_DIR="$2"
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

#**************************************************************************************************************
# Find all items with silence and push into string
# 1 - input string
#**************************************************************************************************************
print_info () {
    IFS=" "
    array=(${1//,/$IFS})

    OUTPUT_DATA=""
    for index in "${!array[@]}"
    do
        if [[ "${array[index]}" =~ "silence_" ]]; then
            OUTPUT_DATA+="${array[index]} ${array[index+1]} "
        fi
    done
    OUTPUT_DATA=$(echo "$OUTPUT_DATA" | tr '\n' ' ')
}

#**************************************************************************************************************
# Write list of files with silence or print data of found files with silence
# 1 - Found silencedata
#**************************************************************************************************************
write_silencedata () {
    print_info "$1"

    if [ -z "$FILE" ]; then
        Color.sh red
        echo -e "$PWD/$2 -> $OUTPUT_DATA"
        Color.sh
    else
        echo -e "$PWD/$2\n    -> $OUTPUT_DATA" >> "$FILE"
    fi
}

#**************************************************************************************************************
# Find target directoryname in trackfiles starting with D:
#**************************************************************************************************************
find_target_in_file () {
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [[ $line =~ "D:" ]]; then
            TARGET_DIR="${line##*:}"
        fi
    done < "$NAMEPATH"
}

#**************************************************************************************************************
# Find trackname from given filepath
# 1 - filenumber (aka the row in the file
#**************************************************************************************************************
find_name_in_file () {
    [ -n "$INFO_FROM_FILE" ] && return

    cnt=1
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [[ $line =~ "D:" ]]; then
            continue
        fi
        if [ "$cnt" -eq "$1" ]; then
            CURRENT_NAME="$line"
            break
        fi

        cnt=$((cnt + 1))
    done < "$NAMEPATH"

    if [ -z "$CURRENT_NAME" ]; then
        CURRENT_NAME="unknown"
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
    OUTPUT=$(printf "%02d_$1" "$4")
    if  [ -n "$TARGET_DIR" ]; then
        [ ! -d "$TARGET_DIR" ] && mkdir "$TARGET_DIR"
    fi

    if [ -n "$TARGET_EXT" ]; then
        if [ -z "$NAMEPATH" ]; then
            PACK_OUTPUT=$(printf "%02d_${1%.*}.$TARGET_EXT" "$4")
        else
            find_name_in_file "$4"
            PACK_OUTPUT=$(printf "%02d_${CURRENT_NAME}.$TARGET_EXT" "$4")
            CURRENT_NAME=""
        fi
        [ -n "$TARGET_DIR" ] && PACK_OUTPUT="${TARGET_DIR}/${PACK_OUTPUT}"
    elif [ -n "$NAMEPATH" ]; then
        find_name_in_file "$4"
        OUTPUT=$(printf "%02d_$CURRENT_NAME" "$4")
        CURRENT_NAME=""i
        [ -n "$TARGET_DIR" ] && OUTPUT="${TARGET_DIR}/${OUTPUT}"
    fi

    ORG_EXT="${1##*.}"

    if [ "$ORG_EXT" == "mp3" ]; then
        echo "Extracting mp3 from $1! | Start: $2 Duration: $3, Min: $MIN_DURATION"
        ffmpeg -i "$1" -ss "$2" -t "$3" -c copy "$OUTPUT" # -v quiet >/dev/null 2>&1 || error_code=$?
    else
        echo "Extracting $OUTPUT | Start: $2 Duration: $3, Min: $MIN_DURATION"
        ffmpeg -i "$1" -ss "$2" -t "$3" "$OUTPUT" -v quiet >/dev/null 2>&1 || error_code=$?

        if [ -n "$TARGET_EXT" ]; then
            if [ "$TARGET_EXT" == "mp3" ]; then
                echo "Packing to mp3 with lame $OUTPUT to $PACK_OUTPUT"
                lame -V 0 -h "$OUTPUT" "$PACK_OUTPUT" >/dev/null 2>&1 || error_code=$?
                if [ $error_code -eq 0 ]; then
                    rm "$OUTPUT"
                fi
            else
                echo "Packing target type $TARGET_EXT not supported, yet!"
            fi
        fi
    fi

    if [ $error_code -ne 0 ]; then
        Color.sh red
        echo "ffmpeg failed to extract $4 audio from $1"
        Color.sh
        ERROR=1
        exit 1
    else LASTFILENO="$4"
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
    TOTAL_LENGTH=$(ffprobe -i "$2" -show_entries format=duration -v quiet -of csv="p=0")

    if [ "$MIN_DURATION" -le 0 ]; then
        MIN_DURATION="$DURATION"
    fi

    if [ -n "$NAMEPATH" ] && [ -z "$TARGET_DIR" ]; then
        find_target_in_file
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

        if [ "$END" != "0" ] && [ "$START" != "0" ]; then
            if (( $(echo "$START < $END" |bc -l) )); then
                # There is no silence in the beginning, so the first file start from the beginning
                if (( $(echo "$START < $MIN_DURATION" |bc -l) )); then
                    FILENUMBER=$((FILENUMBER - 1))
                else
                    split_to_file "$2" "0" "$START" "$FILENUMBER"
                fi
                START=0
            else
                DURATION_2=$(bc <<< "$START - $END")
                if  (( $(echo "$DURATION_2 < $MIN_DURATION" |bc -l) )); then
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

    if [ $START != 0 ] && [ $FILENUMBER == 1 ] && [ $END = 0 ]; then
        #there is only one file and silence at the end, remove silence
        split_to_file "$2" "0" "$START" "$FILENUMBER"
    elif [ $END != "0" ]; then
        # The is no silence at the end of the file, so the last file is created here
        DURATION_2=$(bc <<< "$TOTAL_LENGTH - $END")
        if  (( $(echo "$DURATION_2 >= $MIN_DURATION" |bc -l) )); then
            split_to_file "$2" "$END" "$DURATION_2" "$FILENUMBER"
        fi
    fi

    if [ $ERROR == "0" ] && [ $DELETE == "1" ]  && [ "$FILENUMBER" -gt "1" ]; then
        if [ "$NAMECOUNT" -gt "0"  ] && [ "$NAMECOUNT" -ne "$LASTFILENO" ]; then
            echo "Expected count $NAMECOUNT doesn't equal split count $LASTFILENO (FNo:$FILENUMBER), keeping original files!"
        else
            echo "everythings fine, deleting original. Expected $NAMECOUNT files, Got $LASTFILENO (Fno:$FILENUMBER)"
            rm "$2"
            [ -f "$NAMEPATH" ] && rm "$NAMEPATH"
        fi
    fi
}

#***************************************************************************************************************
# Check if given value starts with a 0 and remove it
# 1 - Value to be verified and modified
#***************************************************************************************************************
check_zero () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "change_zero"
    fi

    ZERORETVAL="$1"
    ttime="${1:0:1}"
    if [ -n "$ttime" ]; then
        if [ "$ttime" == "0" ]; then
            ZERORETVAL="${1:1:1}"
        fi
    fi
}

#***************************************************************************************************************
# Separate and calculate given time into seconds and set to corresponting placeholder
# 1 - time value in hh:mm:ss / mm:ss / ss
#***************************************************************************************************************
calculate_time () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "calculate_time"
    fi

    if [ -n "$1" ]; then
        t1=$(echo "$1" | cut -d : -f 1)
        t2=$(echo "$1" | cut -d : -f 2)
        t3=$(echo "$1" | cut -d : -f 3)

        occ=$(grep -o ":" <<< "$1" | wc -l)

        check_zero "$t1"
        t1=$ZERORETVAL
        check_zero "$t2"
        t2=$ZERORETVAL
        check_zero "$t3"
        t3=$ZERORETVAL

        if [ "$occ" == "0" ]; then
            calc_time=$1
        elif [ "$occ" == "1" ]; then
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
# Parse found silencedata and split input file to separate files with audio only
# 1 - Source filename
#**************************************************************************************************************
split_file_by_input_file () {
    START=0
    END=0
    FILENUMBER=1
    TOTAL_LENGTH=$(ffprobe -i "$1" -show_entries format=duration -v quiet -of csv="p=0")

    if [ "$MIN_DURATION" -le 0 ]; then
        MIN_DURATION="$DURATION"
    fi

    ROWSDATA=""
    while IFS='' read -r line || [[ -n "$line" ]]; do
        ROWSDATA+=" ${line// /_}"
    done < "$INFO_FROM_FILE"

    inputs=(${ROWSDATA//\// })

    for index in "${!inputs[@]}"; do

        line="${inputs[index]}"

        if [[ ${inputs[index]} =~ "D:" ]]; then
            TARGET_DIR="${line##*:}"
            continue
        fi
        CURRENT_NAME="$line"

        TIMEDATA=${CURRENT_NAME%;*}
        START=${TIMEDATA%-*}
        END=${TIMEDATA#*-}
        CURRENT_NAME=${CURRENT_NAME#*;}

        calculate_time "$START"
        START="$CALCTIME"
        calculate_time "$END"
        END="$CALCTIME"

        if [ -z "$END" ] || [ "$END" == "0" ]; then
            TOTAL_LENGTH=${TOTAL_LENGTH%.*}
            END=$((TOTAL_LENGTH - START))
        else
            END=$((END - START))
        fi

        split_to_file "$1" "$START" "$END" "$FILENUMBER"
        START=0
        END=0
        FILENUMBER=$((FILENUMBER + 1))
    done

    if [ $ERROR == "0" ] && [ $DELETE == "1" ] && [ "$FILENUMBER" -gt "1" ]; then
        echo "everythings fine, deleting original"
        rm "$1"
        [ -f "$NAMEPATH" ] && rm "$NAMEPATH"
        [ -f "$INFO_FROM_FILE" ] && rm "$INFO_FROM_FILE"
    fi
}

# 1 - Sourcefile
#**************************************************************************************************************
check_file () {
    #EXT="${1##*.}"
    TIMELEN=$(mediainfo '--Inform=Audio;%Duration%' "$1")
    if [ -n "$TIMELEN" ]; then

        if [ -f "$1" ]; then
            SILENCEDATA=$(ffmpeg -i "$1" -af silencedetect=noise=$NOISE:d=$DURATION -f null - 2>&1 >/dev/null |grep "silence")
            if [ -n "$SILENCEDATA" ]; then
                if [ $SPLIT == 1 ]; then
                    split_file_by_silence "$SILENCEDATA" "$1"
                else
                    write_silencedata "$SILENCEDATA" "$1"
                fi
            fi
        fi
    fi
}

#**************************************************************************************************************
# Go through all files and directories in given directory and act accordingly
#**************************************************************************************************************
do_directory () {
    for f in * ; do
        if [ "$f" != "lost+found" ]; then
            if [ -f "$f" ]; then
                check_file "$f"
            elif [ -d "$f" ]; then
                # Enter directory and repeat function recursively
                cd "$f" || continue
                echo "Entering $f"
                do_directory
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
    hash lame || error_code=$?
    hash mediainfo || error_code=$?

    if [ $error_code -ne 0 ]; then
        echo "Missing one (or more) necessary dependencies: ffmpeg, ffprobe, awk, lame, mediainfo"
        exit 1
    fi
}

#**************************************************************************************************************
# The main function
#**************************************************************************************************************
run_main() {
    if [ -n "$FILE" ] && [ -z "$INFO_FROM_FILE" ] && [ ! -f "$FILE" ]; then
        echo "Seeking silence with $DURATION secs or more" > "$FILE"
    fi

    if [ -z "$FILENAME" ]; then
        echo "Starting seek from $PWD $FILENAME"
        do_directory
    elif [ -d "$FILENAME" ]; then
        echo "Starting seek from directory $FILENAME"
        cd "$FILENAME" || return
        do_directory
        cd ..
    else
        echo "Seeking silence from $FILENAME"
        if [ -z "$INFO_FROM_FILE" ]; then
            check_file "$FILENAME"
        else
            echo "Splitting $FILENAME by $INFO_FROM_FILE"
            split_file_by_input_file "$FILENAME"
        fi
    fi
}

#**************************************************************************************************************

verify_dependencies
init
parse_arguments "$@"

run_main

