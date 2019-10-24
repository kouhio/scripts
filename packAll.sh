#!/bin/bash

HEVC_CONV=0                     # Use ffmpeg instead of avconv to handle files
SCRUB=0                         # Instead of rm, use scrub, if this is set

WORKMODE=4                      # Workmode handler (which part is to be split)
BEGTIME=0                       # Time where video should begin
ENDTIME=0                       # Time where video ending is wanter
DURATION_TIME=0                 # File time to be copied / used
TOTALSAVE=0

FILECOUNT=0                     # Number of files to be handled
MULTIFILECOUNT=0                # Number of files one video was split into
MISSING=0                       # File existance checker
CURRENTFILECOUNTER=0            # Currently processed file number
SUCCESFULFILECNT=0              # Number of successfully handled files

COPY_ONLY=1                     # Don't pack file, just copy data
EXT_CURR=""                     # Current files extension
CONV_TYPE=".mp4"                # Target filetype
CONV_CHECK="mp4"                # Target filetype extension handler
MP3OUT=0                        # Extract mp3 data, if set

CALCTIME=0                      # Global variable to handle calculated time in seconds
TIMERVALUE=0                    # Printed time value, which is calculated
REPACK=0                        # Repack file instead of changing dimensions
IGNORE=0                        # Ignore bigger target file size
TIMESAVED=0                     # Time cut out from modifying videos

CHECKRUN=0                      # Verificator of necessary inputs
CONTINUE_PROCESS=0              # If something went wrong, or file was split into multiple files, don't continue process

WIDTH=0                         # Width of the video
#HEIGHT=0                        # Height of the current video

SKIP=0                          # Remove data from the middle of the file
SKIPBEG=0                       # Beginning time of the video
SKIPEND=0                       # Ending time of the video
KEEPORG=0                       # If set, will not delete original file after success
SPLIT_FILE=0                    # Split file into two, if set

CROP=0                          # Crop video handler

PACKSIZE=""                     # Target file dimensions
ORIGINAL_DURATION=0             # Original duration of input file
NEW_DURATION=0                  # Duration after cutting file
NEW_FILESIZE=0                  # Filesize after processing
ORIGINAL_SIZE=0                 # Input filesize

PRINT_ALL=0                     # Print information only on file(s)
PRINT_INFO=0                    # Will print information according to value
SEGMENT_PARSING=""              # Segment parsing handler

DEBUG_PRINT=0                   # Print function name in this mode
MASSIVE_SPLIT=0                 # Splitting one file into multiple files

MASSIVE_TIME_CHECK=0            # Wanted total time of output files
MASSIVE_TIME_COMP=0             # Actual total time of output files
SPLIT_MAX=0                     # Number of files input is to be split into

SUBFILE=""                      # Path to subtitle file to be burned into target video
WRITEOUT=""                     # Target filename for file info printing
NEWNAME=""                      # New target filename, if not set, will use input filename
TARGET_DIR="."                  # Target directory for successful file

process_start_time=0            # Time in seconds, when processing started
script_start_time=$(date +%s)   # Time in seconds, when the script started running

RETVAL=0                        # If everything was done as expected, is set to 0

#***************************************************************************************************************
# Define regular colors for echo
#***************************************************************************************************************
#Black='\033[0;30m'
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
#Blue='\033[0;34m'
#Purple='\033[0;35m'
#Cyan='\033[0;36m'
#White='\033[0;37m'
Color_Off='\033[0m'

#***************************************************************************************************************
# Print total handled data information
#***************************************************************************************************************
print_total () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "print_total"
    fi

    TOTALSAVE=$((TOTALSAVE / 1000))
    if [ "$PRINT_INFO" == 1 ]; then
        calculate_time_taken "$TIMESAVED"
        echo "Total in $CURRENTFILECOUNTER files, Size:$TOTALSAVE Length:$TIMER_TOTAL_PRINT"
    else
        if [ "$TIMESAVED" -gt "0" ]; then
            TIMESAVED=$((TIMESAVED  / 1000))
            calculate_time_taken "$TIMESAVED"
            TIMESAVEPRINT=$TIMER_TOTAL_PRINT
        fi
        calculate_time_taken

        if [ "$COPY_ONLY" == 0 ] || [ "$TIMESAVED" -gt "0" ]; then
            echo  "Totally saved $TOTALSAVE Mb $TIMESAVEPRINT on $SUCCESFULFILECNT files in $TIMER_TOTAL_PRINT"
        else
            echo "Handled $SUCCESFULFILECNT files to $CONV_CHECK (size change: $TOTALSAVE Mb) in $TIMER_TOTAL_PRINT"
        fi
        if [ "$MISSING" -gt "0" ]; then
            echo "Number of files disappeared during process: $MISSING"
            RETVAL=1
        fi
    fi
}

#***************************************************************************************************************
# Remove incomplete destination files
#***************************************************************************************************************
remove_interrupted_files () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "remove_interrupted_files"
    fi

    if [ -f "$FILE$CONV_TYPE" ]; then
        delete_file "$FILE$CONV_TYPE"
    fi
    if [ -f "$FILE"_1"$CONV_TYPE" ]; then
        delete_file "$FILE"_1"$CONV_TYPE"
    fi
    if [ -f "$FILE"_2"$CONV_TYPE" ]; then
        delete_file "$FILE"_2"$CONV_TYPE"
    fi
}

#***************************************************************************************************************
#If SYS_INTERRUPTted, stop process, remove files not complete and print final situation
#***************************************************************************************************************
set_int () {
    calculate_duration
    echo " Main conversion interrupted in ${TIMERVALUE}!"
    remove_interrupted_files
    print_total
    exit 1
}

trap set_int SIGINT SIGTERM

#**************************************************************************************************************
# Print script functional help
#***************************************************************************************************************
print_help () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "print_help"
    fi

    echo "No input file! first input is always filename (filename, file type or part of filename)"
    echo " "
    echo "To set dimensions NxM (where N is width, M is height, height is automatically calculated to retain aspect ratio)"
    echo " "
    echo "b(eg)=       -    time to remove from beginning (either seconds or X:Y:Z)"
    echo "e(nd)=       -    time to remove from end (calculated from the end) (either seconds or X:Y:Z)"
    echo "d(uration)=  -    Time from the beginning X:Y:Z, to skip the end after that"
    echo "t(arget)=    -    filetype to set destination filetype (mp4 as default)"
    echo " "
    echo "i(gnore)     -    to ignore size"
    echo "r(epack)     -    to repack file with original dimensions"
    echo "k(eep)       -    to keep the original file after succesful conversion"
    echo "m(p3)        -    to extract mp3 from the file"
    echo "a(ll)        -    print all information"
    echo "p(rint)      -    print only file information (if set as 1, will print everything, 2 = lessthan, 3=biggerthan, 4=else )"
    echo "h(evc)       -    convert with ffmpeg instead of avconv"
    echo "s(crub)      -    original on completion"
    echo "crop         -    crop black borders"
    echo " "
    echo "sub=         -    subtitle file to be burned into video"
    echo "w(rite)=     -    Write printing output to file"
    echo "n(ame)=      -    Give file a new target name (without file extension)"
    echo "T(arget)=    -    Target directory for the target file"
    echo " "
    echo "c(ut)=       -    time where to cut,time where to cut next piece,next piece,etc"
    echo "c(ut)=       -    time to begin - time to end,next time to begin-time to end,etc"
    echo "s(kip)=      -    time to skip|duration (in secs) Requires MP4Box installed (and doesn't work really good)"
    echo " "
    echo "example:     ${0} \"FILENAME\" 640x h b=1:33 c=0:11-1:23,1:0:3-1:6:13"
}

#**************************************************************************************************************
# Crop out black borders (this needs more work, kind of hazard at the moment.
# TODO: Needs to verify dimensional changes, so it won't cut too much
#***************************************************************************************************************
check_and_crop () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "check_and_crop"
    fi

    CROP_DATA=$(ffmpeg -i "$FILE" -t 1 -vf cropdetect -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1)
    if [ ! -z "$CROP_DATA" ]; then
        XC=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        YC=$(mediainfo '--Inform=Video;%Height%' "$FILE")

        if [ ! -z "$XC" ] && [ ! -z "$YC" ]; then
            CB=$(echo "$CROP_DATA" | cut -d = -f 2)
            C1=$(echo "$CB" | cut -d : -f 1)
            C2=$(echo "$CB" | cut -d : -f 2)
            C3=$(echo "$CB" | cut -d : -f 3)
            C4=$(echo "$CB" | cut -d : -f 4)
            if [ "$C1" -ge "0" ] && [ "$C2" -ge "0" ]; then
                if [ "$XC" -ne "$C1" ] || [ "$YC" -ne "$C2" ] || [ "$C3" -gt "0" ] || [ "$C4" -gt "0" ]; then
                    print_info
                    short_name
                    process_start_time=$(date +%s)
                    PROCESS_NOW=$(date +%T)
                    echo -n -e "$PROCESS_NOW : $FILEprint Cropping black borders ->($CROP_DATA) \t"
                    ffmpeg -i "$FILE" -vf "$CROP_DATA" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
                    calculate_duration
                    check_file_conversion
                fi
            fi
        fi
    fi
}

#**************************************************************************************************************
# Check WORKMODE for removing time data
#***************************************************************************************************************
check_workmode () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "check_workmode"
    fi

    if [ "$BEGTIME" != "D" ]; then
        if [ "$BEGTIME" -gt 0 ] && [ "$ENDTIME" -gt 0 ]; then
            WORKMODE=3
        elif [ "$BEGTIME" -gt 0 ] && [ "$DURATION_TIME" -gt 0 ]; then
            WORKMODE=3
        elif [ "$BEGTIME" -gt 0 ]; then
            WORKMODE=1
        elif [ "$ENDTIME" -gt 0 ] || [ "$DURATION_TIME" -gt 0 ]; then
            WORKMODE=2
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
    if [ ! -z "$ttime" ]; then
        if [ "$ttime" == "0" ]; then
            ZERORETVAL="${1:1:1}"
        fi
    fi
}

#**************************************************************************************************************
# Delete file / scrub file
# 1 - path to filename
#***************************************************************************************************************
delete_file () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "delete_file"
    fi

    if [ -f "$1" ]; then
        if [ "$SCRUB" == "1" ]; then
            scrub -r "$1" >/dev/null 2>&1
        elif [ "$SCRUB" == "2" ]; then
            scrub -r "$1"
        else
            rm "$1"
        fi
    fi
}

#**************************************************************************************************************
# Check that the timelength matches with the destination files from splitting
#***************************************************************************************************************
ERROR_WHILE_SPLITTING=0

massive_filecheck () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "massive_filecheck"
    fi

    if [ "$ERROR_WHILE_SPLITTING" != "0" ]; then
        echo -e -n "${Red}Something went wrong with splitting $FILE${Color_Off}\n"
        ERROR_WHILE_SPLITTING=0
        RETVAL=1
        return 0;
    fi

    MASSIVE_TIME_COMP=0
    RUNNING_FILE_NUMBER=0
    MASSIVE_SIZE_COMP=0
    TOO_SMALL_FILE=0

    while [ "$RUNNING_FILE_NUMBER" -lt "$SPLIT_MAX" ]; do
        RUNNING_FILE_NUMBER=$((RUNNING_FILE_NUMBER + 1))
        make_running_name
        if [ -f "${TARGET_DIR}/${RUNNING_FILENAME}" ]; then
            CFT=$(mediainfo '--Inform=Video;%Duration%' "${TARGET_DIR}/${RUNNING_FILENAME}")
            MASSIVE_TIME_COMP=$((MASSIVE_TIME_COMP + CFT))
            MSC=$(du -k "${TARGET_DIR}/$RUNNING_FILENAME" | cut -f1)
            [ "$MSC" -lt "3000" ] && TOO_SMALL_FILE=$((TOO_SMALL_FILE + 1))
            MASSIVE_SIZE_COMP=$((MASSIVE_SIZE_COMP + MSC))
        else
            break
        fi
    done

    if [ "$MASSIVE_TIME_COMP" -ge "$MASSIVE_TIME_CHECK" ] && [ "$TOO_SMALL_FILE" == "0" ]; then
        OSZ=$(du -k "$FILE" | cut -f1)
        if [ "$KEEPORG" == "0" ]; then
            delete_file "$FILE"
        fi
        OSZ=$(((OSZ - MASSIVE_SIZE_COMP) / 1000))
        echo -e -n"${Green}Saved $OSZ Mb with splitting${Color_Off}\n"

    else
        echo -e -n "${Red}Something wrong with cut-out time ($MASSIVE_TIME_COMP < $MASSIVE_TIME_CHECK) Small files: $TOO_SMALL_FILE${Color_Off}\n"
        RETVAL=1
    fi
}

#***************************************************************************************************************
# Split file into chunks given by input parameters, either (start-end,start-end|...) or (point,point,point,...)
# 1 - Splitting time information
#***************************************************************************************************************
new_massive_file_split () {

    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "new_massive_file_split"
    fi

    MASSIVE_TIME_CHECK=0
    SPLIT_FILE=0
    SPLIT_COUNTER=0
    FILECOUNT=1
    MASSIVE_SPLIT=1

    if [ -f "$FILE" ]; then
        EXT_CURR="${FILE##*.}"
        LEN=$(mediainfo '--Inform=Video;%Duration%' "$FILE")
        XSS=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        LEN=$((LEN / 1000))

        SPLIT_P2P=$(grep -o "-" <<< "$1" | wc -l)

        IFS=","
        array=(${1//,/$IFS})
        SPLIT_MAX=${#array[@]}

        for index in "${!array[@]}"
        do
            if [ "$SPLIT_P2P" -gt 0 ]; then
                IFS="-"
                array2=(${array[index]//-/$IFS})

                [ "${array2[0]}" == "D" ] && break

                calculate_time "${array2[0]}"
                BEGTIME=$CALCTIME
                calculate_time "${array2[1]}"
                ENDTIME=$CALCTIME

                if [ "$ENDTIME" -le "$BEGTIME" ] && [ "$ENDTIME" != "0" ] || [ "$WIDTH" -ge "$XSS" ]; then
                    ERROR_WHILE_SPLITTING=1
                    echo -e -n "${Red}Split error $FILE - Time: $ENDTIME <= $BEGTIME, Size: $WIDTH >= $XSS${Color_Off}\n"
                    RETVAL=1
                else
                    if [ "$CALCTIME" != "0" ]; then
                        ENDTIME=$((LEN - CALCTIME))
                    fi
                    check_workmode
                    pack_file
                    MASSIVE_TIME_CHECK=$((MASSIVE_TIME_CHECK + (ENDTIME - BEGTIME)))
                fi
            else
                calculate_time "${array[index]}"
                SPLIT_POINT=$CALCTIME
                calculate_time "${array[index + 1]}"
                SPLIT_POINT2=$CALCTIME
                if [ "$SPLIT_POINT2" -le "$SPLIT_POINT" ] && [ $SPLIT_POINT2 != "0" ] || [ "$WIDTH" -ge "$XSS" ]; then
                    ERROR_WHILE_SPLITTING=1
                    echo -e -n "${Red}Split error $FILE - Time: $SPLIT_POINT2 <= $SPLIT_POINT, - Size: $WIDTH <= $XSS${Color_Off}\n"
                    RETVAL=1
                else
                    if [ "$index" == 0 ]; then
                        BEGTIME=0
                        ENDTIME=$((LEN - SPLIT_POINT))
                        check_workmode
                        pack_file
                        MASSIVE_TIME_CHECK=$((MASSIVE_TIME_CHECK + (ENDTIME - BEGTIME)))

                        # This is the second part of the beginning data 
                        BEGTIME=$SPLIT_POINT
                        ENDTIME=$((LEN - SPLIT_POINT2))
                        MASSIVE_TIME_CHECK=$((MASSIVE_TIME_CHECK + (ENDTIME - BEGTIME)))
                    elif [ -z "$SPLIT_POINT2" ] || [ "$SPLIT_POINT2" == "0" ]; then
                        BEGTIME=$SPLIT_POINT
                        ENDTIME=0
                        MASSIVE_TIME_CHECK=$((MASSIVE_TIME_CHECK + (LEN - BEGTIME)))
                    else
                        BEGTIME=$SPLIT_POINT
                        ENDTIME=$((LEN - SPLIT_POINT2))
                        MASSIVE_TIME_CHECK=$((MASSIVE_TIME_CHECK + (ENDTIME - BEGTIME)))
                    fi
                    check_workmode
                    pack_file
               fi
            fi
        done
        massive_filecheck
    else
        echo "File '$FILE' not found, cannot split!"
    fi
    CONTINUE_PROCESS=0
}

#***************************************************************************************************************
# Separate and calculate given time into seconds and set to corresponting placeholder
# 1 - time value in hh:mm:ss / mm:ss / ss
#***************************************************************************************************************
calculate_time () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "calculate_time"
    fi

    if [ ! -z "$1" ]; then
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
# Parse special handlers
#***************************************************************************************************************
parse_handlers () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "parse_handlers"
    fi

    if [ ! -z "$1" ]; then
        if [ "$1" == "repack" ] || [ "$1" == "r" ]; then
            REPACK=1
            COPY_ONLY=0
        elif [ "$1" == "ignore" ] || [ "$1" == "i" ]; then
            IGNORE=1
        elif [ "$1" == "keep" ] || [ "$1" == "k" ]; then
            KEEPORG=1
        elif [ "$1" == "mp3" ] || [ "$1" == "m" ]; then
            MP3OUT=1
            CONV_TYPE=".mp3"
        elif [ "$1" == "all" ] || [ "$1" == "a" ]; then
            PRINT_ALL=1
        elif [ "$1" == "crop" ] || [ "$1" == "s" ]; then
            CROP=1
        elif [ "$1" == "scrub" ] || [ "$1" == "s" ]; then
            SCRUB=1
        elif [ "$1" == "print" ] || [ "$1" == "p" ]; then
            PRINT_INFO=1
        elif [ "$1" == "hevc" ] || [ "$1" == "h" ]; then
            IGNORE=1
            HEVC_CONV=1
        elif [ "$1" == "D" ]; then
            DEBUG_PRINT=1
        else
            echo "Unknown handler $1"
            RETVAL=1
        fi
    fi
}

#**************************************************************************************************************
# Parse skipdata
# 1 - Input value
#***************************************************************************************************************
parse_skipdata () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "parse_skipdata"
    fi

    if [ ! -z "$1" ]; then
        SKIPBEG=$(echo "$1" | cut -d "|" -f 1)
        SKIPEND=$(echo "$1" | cut -d "|" -f 2)
        occ=$(grep -o "|" <<< "$1" | wc -l)

        calculate_time "$SKIPBEG"
        SKIPBEG=$CALCTIME
        if [ "$occ" -gt 0 ] ; then
            calculate_time "$SKIPEND"
            SKIPEND="$CALCTIME"

            if [ "$SKIPEND" -gt "$SKIPBEG" ]; then
                SKIPEND=$((SKIPEND - SKIPBEG))
            fi
        else
            SKIPEND=0
        fi

    fi
}

#**************************************************************************************************************
# Parse time values to remove
# 1 - input value
#***************************************************************************************************************
parse_values () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "parse_values"
    fi

    if [ ! -z "$1" ]; then
        HANDLER=$(echo "$1" | cut -d = -f 1)
        VALUE=$(echo "$1" | cut -d = -f 2)
        if [ "$HANDLER" == "beg" ] || [ "$HANDLER" == "b" ]; then
            calculate_time "$VALUE"
            BEGTIME=$CALCTIME
        elif [ "$HANDLER" == "end" ] || [ "$HANDLER" == "e" ]; then
            calculate_time "$VALUE"
            ENDTIME=$CALCTIME
        elif [ "$HANDLER" == "duration" ] || [ "$HANDLER" == "d" ]; then
            calculate_time "$VALUE"
            DURATION_TIME=$CALCTIME
        elif [ "$HANDLER" == "skip" ] || [ "$HANDLER" == "s" ]; then
            parse_skipdata "$VALUE"
            SKIP=1
        elif [ "$HANDLER" == "target" ] || [ "$HANDLER" == "t" ]; then
            CONV_TYPE=".$VALUE"
            CONV_CHECK="$VALUE"
        elif [ "$HANDLER" == "cut" ] || [ "$HANDLER" == "c" ]; then
            new_massive_file_split "$VALUE"
        elif [ "$HANDLER" == "print" ] || [ "$HANDLER" == "p" ]; then
            PRINT_INFO=$VALUE
        elif [ "$HANDLER" == "sub" ]; then
            SUBFILE="$VALUE"
        elif [ "$HANDLER" == "w" ] || [ "$HANDLER" == "write" ]; then
            WRITEOUT="$VALUE"
        elif [ "$HANDLER" == "n" ] || [ "$HANDLER" == "name" ]; then
            NEWNAME="$VALUE"
        elif [ "$HANDLER" == "T" ] || [ "$HANDLER" == "Target" ]; then
            TARGET_DIR="$VALUE"
            mkdir -p "$TARGET_DIR"
        elif [ "$1" == "scrub" ] || [ "$1" == "s" ]; then
            SCRUB=$VALUE
        else
            echo "Unknown value $1"
            RETVAL=1
        fi
        check_workmode
    fi
    CALCTIME=0
}

#**************************************************************************************************************
# Parse dimension values
# 1 - dimension value Width x Height
#***************************************************************************************************************
parse_dimension () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "parse_dimension $1"
    fi

    if [ ! -z "$1" ]; then
        WIDTH=$(echo "$1" | cut -d x -f 1)
        HEIGHT=$(echo "$1" | cut -d x -f 2)
        COPY_ONLY=0
    fi
}

#**************************************************************************************************************
# Parse file information
#***************************************************************************************************************
parse_file () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "parse_file"
    fi

    if [ ! -z "$1" ]; then
        CONTINUE_PROCESS=1
        FILE="$1"
        FileStrLen=${#FILE}
        if [ ! -f "$FILE" ]; then
            if [ "$FileStrLen" -lt 7 ]; then
                FILECOUNT=$(ls -l *"$FILE" 2>/dev/null | grep -v ^l | wc -l)
            else
                MULTIFILECOUNT=$(ls -l *"$FILE"* 2>/dev/null | grep -v ^l | wc -l)
            fi
        fi
    fi
}

#***************************************************************************************************************
# Parse input data from given commandline inputs
#***************************************************************************************************************
parse_data () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "parse_data"
    fi

    if [ ! -z "$1" ]; then
        if [ "$CHECKRUN" == 0 ]; then
            parse_file "$1"
        else
            xss=$(grep -o "x" <<< "$1" | wc -l)
            DATA2=$(echo "$1" | cut -d x -f 2)

            if [ "$xss" == "0" ] || [ ! -z "$DATA2" ]; then
                xss=$(grep -o "=" <<< "$1" | wc -l)
                if [ "$xss" == "0" ]; then
                    parse_handlers "$1"
                else
                    parse_values "$1"
                fi
            else
                parse_dimension "$1"
            fi
        fi
    fi
}

#***************************************************************************************************************
# Print video information data
#***************************************************************************************************************
print_file_info () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "print_file_info"
    fi

    if [ -f "$FILE" ]; then
        X=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        if [ ! -z "$X" ]; then
            if [ "$PRINT_INFO" == "2" ] && [ "$WIDTH" -le "$X" ]; then
                return 0
            elif [ "$PRINT_INFO" == "3" ] && [ "$WIDTH" -ge "$X" ]; then
                return 0
            elif [ "$PRINT_INFO" == "4" ] && [ "$WIDTH" == "$X" ]; then
                echo "$PACKSIZE -- $X"
                return 0
            fi

            Y=$(mediainfo '--Inform=Video;%Height%' "$FILE")
            LEN=$(mediainfo '--Inform=Video;%Duration%' "$FILE")
            LEN=$((LEN / 1000))
            calculate_time_taken $LEN
            TIMESAVED=$((TIMESAVED + LEN))
            SIZE=$(du -k "$FILE" | cut -f1)
            TOTALSAVE=$((TOTALSAVE + SIZE))
            SIZE=$((SIZE / 1000))
            if [ "$MULTIFILECOUNT" -gt 1 ]; then
                FILECOUNT=$MULTIFILECOUNT
            fi
            if [ "$FILECOUNT" -gt 1 ]; then
                if [ "$CURRENTFILECOUNTER" -lt "10" ]; then
                    FILECOUNTPRINTER="0$CURRENTFILECOUNTER of $FILECOUNT :: "
                else
                    FILECOUNTPRINTER="$CURRENTFILECOUNTER of $FILECOUNT :: "
                fi
            fi
            short_name
            echo "$FILECOUNTPRINTER$FILEprint X:$X Y:$Y Size:$SIZE Mb Lenght:$TIMER_TOTAL_PRINT"
            if [ ! -z "$WRITEOUT" ]; then
                echo "packAll.sh \"$FILE\" " >> "$WRITEOUT"
            fi
        else
            echo "$FILE is corrupted"
        fi
    fi
}

#***************************************************************************************************************
# Print multiple file handling information
#***************************************************************************************************************
print_info () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "print_info"
    fi

    if [ "$FILECOUNT" -gt 1 ]; then
        echo -n "$CURRENTFILECOUNTER of $FILECOUNT "
    elif [ "$MULTIFILECOUNT" -gt 1 ]; then
        echo -n "$CURRENTFILECOUNTER of $MULTIFILECOUNT "
    fi
}

#***************************************************************************************************************
# Calculate time from current time data for one process and total
#***************************************************************************************************************
calculate_duration () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "calculate_duration"
    fi

    TIMERR=$(date +%s)
    processing_time=$((TIMERR - process_start_time))
    TIMERVALUE=$(date -d@${processing_time} -u +%T)
}

#***************************************************************************************************************
# Cut filename shorter if it's too long, or fill with empty to match length
# 1 - filename max length
#***************************************************************************************************************
short_name () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "short_name"
    fi

    #if [ -z "$1" ]; then
        NAMELIMITER=40
    #else
    #    NAMELIMITER=$1
    #fi

    nameLen=${#FILE}
    extLen=${#EXT_CURR}
    if [ "$nameLen" -gt "$NAMELIMITER" ]; then
        FILEprint="${FILE:0:$NAMELIMITER}...$EXT_CURR"
    elif [ "$nameLen" -le "$NAMELIMITER" ]; then
        PADDER=$(((NAMELIMITER - nameLen) + 3 + extLen))
        PAD="                             "
        PADDING="${PAD:0:$PADDER}"
        FILEprint=$FILE$PADDING
    #else
    #    FILEprint=$FILE
    fi
}

#***************************************************************************************************************
# Extract mp3 by given parameters
#***************************************************************************************************************
extract_mp3 () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "extract_mp3"
    fi

    short_name
    process_start_time=$(date +%s)
    PROCESS_NOW=$(date +%T)
    echo -n "$PROCESS_NOW : $FILEprint extracting mp3 "

    if [ "$DURATION_TIME" -gt 0 ]; then
        ENDTIME=$((ORIGINAL_DURATION - DURATION_TIME))
    fi

    if [ "$WORKMODE" == "1" ]; then
        avconv -ss "$BEGTIME" -i "$FILE" -acodec libmp3lame "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ "$WORKMODE" == "2" ]; then
        ENDO=$((DUR - ENDTIME))
        avconv -i "$FILE" -t $ENDO -acodec libmp3lame "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ "$WORKMODE" == "3" ]; then
        ENDO=$((DUR - ENDTIME - BEGTIME))
        avconv -ss "$BEGTIME" -i "$FILE" -t $ENDO -acodec libmp3lame "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ "$WORKMODE" == "4" ]; then
        avconv -i "$FILE" -acodec libmp3lame "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    fi
    if [ -f "$FILE$CONV_TYPE" ]; then
        rename "s/.$EXT_CURR//" "$FILE$CONV_TYPE"
        echo "Successfully extracted mp3"
    else
        echo -e -n "${Red}Failed!${Color_Off}\n"
        RETVAL=1
    fi
}

#***************************************************************************************************************
# Do a ffmpeg copy process
#***************************************************************************************************************
copy_hevc () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "copy_hevc"
    fi

    short_name
    process_start_time=$(date +%s)
    PROCESS_NOW=$(date +%T)
    echo -n "$PROCESS_NOW : $FILEprint HEVC copy (${X}x${Y}) "
    if [ "$MASSIVE_SPLIT" == 1 ]; then
        echo -n "splitting file $CUTTING_TIME sec (mode: $WORKMODE) "
    elif [ "$CUTTING_TIME" -gt 0 ]; then
        echo -n "shortened by $CUTTING_TIME sec (mode: $WORKMODE) "
    fi

    if [ "$WORKMODE" == "1" ]; then
        #pack with skipping the beginning
        ffmpeg -ss "$BEGTIME" -i "$FILE" -c:v:1 copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ "$WORKMODE" == "2" ]; then
        #pack with skipping the ending
        ENDO=$((DUR - ENDTIME))
        ffmpeg -i "$FILE" -t $ENDO -c:v:1 copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ "$WORKMODE" == "3" ]; then
        #pack with skipping from the beginning and the end
        ENDO=$((DUR - ENDTIME - BEGTIME))
        ffmpeg -ss "$BEGTIME" -i "$FILE" -t $ENDO -c:v:1 copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    else
        #no time removal, so just pack it
        ffmpeg -i "$FILE" -c:v:1 copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    fi
}

#***************************************************************************************************************
# Pack file with ffmpeg
#***************************************************************************************************************
convert_hevc () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "conver_hevc"
    fi

    short_name
    process_start_time=$(date +%s)
    PROCESS_NOW=$(date +%T)
    echo -n "$PROCESS_NOW : $FILEprint FFMPEG packing (${X}x${Y})->($PACKSIZE) "
    if [ "$CUTTING_TIME" -gt 0 ]; then
        echo -n "cut $CUTTING_TIME sec (mode:$WORKMODE) "
    fi

    #ffmpeg -i "$FILE" -bsf:v h264_mp4toannexb -vf scale=$PACKSIZE -sn -map 0:0 -map 0:1 -vcodec libx264 "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    if [ "$WORKMODE" == "1" ]; then
        #pack with skipping the beginning
        ffmpeg -ss "$BEGTIME" -i "$FILE" -bsf:v h264_mp4toannexb -vf scale=$PACKSIZE -sn -map 0:0 -map 0:1 -vcodec libx264 "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ "$WORKMODE" == "2" ]; then
        #pack with skipping the ending
        ENDO=$((DUR - ENDTIME))
        ffmpeg -i "$FILE" -t $ENDO -bsf:v h264_mp4toannexb -vf scale=$PACKSIZE -sn -map 0:0 -map 0:1 -vcodec libx264 "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ "$WORKMODE" == "3" ]; then
        #pack with skipping from the beginning and the end
        ENDO=$((DUR - ENDTIME - BEGTIME))
        ffmpeg -ss "$BEGTIME" -i "$FILE" -t $ENDO -bsf:v h264_mp4toannexb -vf scale=$PACKSIZE -sn -map 0:0 -map 0:1 -vcodec libx264 "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    else
        #no time removal, so just pack it
        ffmpeg -i "$FILE" -bsf:v h264_mp4toannexb -vf scale=$PACKSIZE -sn -map 0:0 -map 0:1 -vcodec libx264 "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    fi
}

#***************************************************************************************************************
# Burn subtitle file to a given video file
#***************************************************************************************************************
burn_subs () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "burn_subs"
    fi

    if [ -f "$FILE" ]; then
        if [ -f "$SUBFILE" ]; then
            short_name
            process_start_time=$(date +%s)
            PROCESS_NOW=$(date +%T)
            echo -n "$PROCESS_NOW : $FILEprint FFMPEG burning subs "
            ffmpeg -i "$FILE" -vf subtitles="$SUBFILE" "Subbed_$FILE" -v quiet
            echo "Done"
        else
            echo -e -n "${Red}Subfile $SUBFILE not found!${Color_Off}\n"
            RETVAL=1
        fi
    else
        echo -e -n "${Red}File $FILE not found!${Color_Off}\n"
        RETVAL=1
    fi
}

#***************************************************************************************************************
# Pack video file with avconv
#***************************************************************************************************************
pack_it () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "pack_it"
    fi

    short_name
    process_start_time=$(date +%s)
    PROCESS_NOW=$(date +%T)
    echo -n "$PROCESS_NOW : $FILEprint packing (${X}x${Y})->$PACKSIZE "
    if [ "$CUTTING_TIME" -gt 0 ]; then
        echo -n "cut $CUTTING_TIME sec (mode:$WORKMODE) "
    fi

    if [ "$DURATION_TIME" -gt 0 ]; then
        ENDTIME=$((ORIGINAL_DURATION - DURATION_TIME))
    fi

    if [ "$WORKMODE" == "1" ]; then
        #pack with skipping the beginning
        avconv -ss "$BEGTIME" -i "$FILE" -map 0 -map_metadata 0:s:0 -strict experimental -s "$PACKSIZE" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ "$WORKMODE" == "2" ]; then
        #pack with skipping the ending
        ENDO=$((DUR - ENDTIME))
        avconv -i "$FILE" -t $ENDO -map 0 -map_metadata 0:s:0-strict experimental -s "$PACKSIZE" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ "$WORKMODE" == "3" ]; then
        #pack with skipping from the beginning and the end
        ENDO=$((DUR - ENDTIME - BEGTIME))
        avconv -ss "$BEGTIME" -i "$FILE" -t $ENDO -map 0 -map_metadata 0:s:0 -strict experimental -s "$PACKSIZE" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    else
        #no time removal, so just pack it
        #avconv -i "$FILE" -map 0 -map_metadata 0:s:0 -strict experimental -s "$PACKSIZE" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
        avconv -i "$FILE" -s "$PACKSIZE" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    fi
}

#***************************************************************************************************************
# COPY_ONLY video to different format with avconv
#***************************************************************************************************************
copy_it () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "copy_it"
    fi

    short_name
    process_start_time=$(date +%s)
    PROCESS_NOW=$(date +%T)
    echo -n "$PROCESS_NOW : $FILEprint "

    if [ "$EXT_CURR" != "$CONV_CHECK" ]; then
        echo -n "being transformed "
    fi

    if [ "$MASSIVE_SPLIT" == 1 ]; then
        echo -n "splitting file $CUTTING_TIME sec (mode: $WORKMODE) "
    elif [ "$CUTTING_TIME" -gt 0 ]; then
        echo -n "shortened by $CUTTING_TIME sec (mode: $WORKMODE) "
    fi

    if [ "$WORKMODE" == "1" ]; then
        #pack with skipping the beginning
        avconv -ss "$BEGTIME" -i "$FILE" -map 0 -map_metadata 0:s:0 -c copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ "$WORKMODE" == "2" ]; then
        #pack with skipping the ending
        ENDO=$((DUR - ENDTIME))
        avconv -i "$FILE" -t $ENDO -map 0 -map_metadata 0:s:0 -c copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ "$WORKMODE" == "3" ]; then
        #pack with skipping from the beginning and the end
        ENDO=$((DUR - ENDTIME - BEGTIME))
        avconv -ss "$BEGTIME" -i "$FILE" -t $ENDO -map 0 -map_metadata 0:s:0 -c copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    else
        #no time removal, so just pack it
        if [ "$EXT_CURR" != "$CONV_CHECK" ]; then
            #avconv -i "$FILE" -map 0 -map_metadata 0:s:0 -c copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
            avconv -i "$FILE" -c:a copy -c:v copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
        fi
    fi
}

#***************************************************************************************************************
# Remove a segment from the middle of the video file
# TODO: needs verification of functionality
#***************************************************************************************************************
remove_segment () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "remove_segment"
    fi

    short_name
    process_start_time=$(date +%s)
    PROCESS_NOW=$(date +%T)
    if [ "$SKIP" == 1 ]; then
        echo -n "$PROCESS_NOW : $FILEprint segment being removed (not really working good!)"
    else
        echo -n "$PROCESS_NOW : $FILEprint being split into two files"
    fi
    BEGTIME=0

    avconv -i "$FILE" -t $SKIPBEG -map 0 -map_metadata 0:s:0 -c copy "$FILE"_1"$CONV_TYPE" -v quiet >/dev/null 2>&1
    SKIPBEG=$((SKIPBEG + SKIPEND))
    ENDO=$((DUR - SKIPBEG))
    ENDTIME=$((SKIPEND - SKIPBEG))
    if [ "$ENDTIME" -lt 0 ]; then
        ENDTIME=$((ENDTIME * -1))
    fi
    avconv -ss "$SKIPBEG" -i "$FILE" -t "$ENDO" -map 0 -map_metadata 0:s:0 -c copy "${FILE}_2${CONV_TYPE}" -v quiet >/dev/null 2>&1

    if [ "$SKIP" == 1 ]; then
        MP4Box "temp_1$CONV_TYPE" -cat "temp_2$CONV_TYPE" -out "$FILE$CONV_TYPE" >/dev/null 2>&1
        delete_file "${FILE}_1${CONV_TYPE}"
        delete_file "${FILE}_2${CONV_TYPE}"
    fi
}

#***************************************************************************************************************
# Make a filename with incrementing value
#***************************************************************************************************************
RUNNING_FILENAME=""

make_running_name () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "make_running_name"
    fi

    ExtLen=${#EXT_CURR}
    NameLen=${#FILE}
    LEN_NO_EXT=$((NameLen - ExtLen))
    if [ -z "$NEWNAME" ]; then
        RUNNING_FILENAME=${FILE:0:$LEN_NO_EXT}
    else
        RUNNING_FILENAME=$NEWNAME
    fi
    if [ "$RUNNING_FILE_NUMBER" -lt "10" ]; then
        RUNNING_FILENAME+="_0$RUNNING_FILE_NUMBER$CONV_TYPE"
    else
        RUNNING_FILENAME+="_$RUNNING_FILE_NUMBER$CONV_TYPE"
    fi
}

#***************************************************************************************************************
# When keeping an original file, make the extracted piece it's own unique number, so many parts can be extracted
#***************************************************************************************************************
move_to_a_running_file () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "move_to_a_running_file"
    fi

    RUNNING_FILE_NUMBER=1
    make_running_name
    if [ -f "${TARGET_DIR}/$RUNNING_FILENAME" ]; then
        while true; do
            RUNNING_FILE_NUMBER=$((RUNNING_FILE_NUMBER + 1))
            make_running_name
            if [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ]; then
                break
            fi
        done
    fi

    mv "$FILE$CONV_TYPE" "${TARGET_DIR}/${RUNNING_FILENAME}"
}

#***************************************************************************************************************
# Rename output file to correct format or move unsuccesful file to other directory
# 1 - If bigger than zero, check one file, if 0, process failed and remove target files
#***************************************************************************************************************
handle_file_rename () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "handle_file_rename"
    fi

    if [ "$1" -gt 0 ]; then
        if [ "$KEEPORG" == "0" ]; then
            delete_file "$FILE"
        fi

        if [ "$SPLIT_FILE" == 0 ]; then
            if [ "$KEEPORG" == "0" ]; then
                if [ "$EXT_CURR" == "$CONV_CHECK" ]; then
                    if [ -z "$NEWNAME" ]; then
                        mv "$FILE$CONV_TYPE" "${TARGET_DIR}/${FILE}"
                    else
                        mv "$FILE$CONV_TYPE" "${TARGET_DIR}/$NEWNAME$CONV_TYPE"
                    fi
                else
                    if [ "${TARGET_DIR}" != "." ]; then
                        mv "$FILE$CONV_TYPE" "${TARGET_DIR}/$FILE$CONV_TYPE"
                        rename "s/.$EXT_CURR//" "${TARGET_DIR}/$FILE$CONV_TYPE"
                    else
                        rename "s/.$EXT_CURR//" "$FILE$CONV_TYPE"
                    fi
                fi
            else
                move_to_a_running_file
            fi
        fi
    else
        if [ "$SPLIT_FILE" == 1 ]; then
            delete_file "${FILE}_1${CONV_TYPE}"
            delete_file "${FILE}_2${CONV_TYPE}"
        else
            delete_file "$FILE$CONV_TYPE"
            if [ "$EXT_CURR" == "$CONV_CHECK" ] && [ "$COPY_ONLY" == "0" ]; then
                if [ ! -d "./Failed" ]; then
                    mkdir "Failed"
                fi
                RETVAL=1
                mv "$FILE" "./Failed"
            fi
        fi
    fi
}

#***************************************************************************************************************
# Calculate dimension ratio change
#***************************************************************************************************************
calculate_packsize () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "calculate_packsize"
    fi

    # Get original video dimensions
    XC=$(mediainfo '--Inform=Video;%Width%' "$FILE")
    YC=$(mediainfo '--Inform=Video;%Height%' "$FILE")
    # Calculate dimension scale
    SCALE=$(bc <<< "scale=25;($WIDTH/($XC/$YC))")
    # Change scale to int
    SCALE=$(bc <<< "scale=0;$SCALE/1")
    # Check division of 8
    SCALECORR=$(bc <<< "$SCALE%8")
    # Correct to a multiplier of 8
    SCALE=$((SCALE - SCALECORR))

    PACKSIZE="$WIDTH"x"$SCALE"
}

#***************************************************************************************************************
# Move corrupted file to a Error directory
#***************************************************************************************************************
handle_error_file () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "handle_error_file"
    fi

    if [ ! -d "./Error" ]; then
        mkdir "Error"
    fi
    mv "$FILE" "./Error"
    echo -e -n "${Red}Something corrupted with $FILE${Color_Off}\n"
    RETVAL=1
}

#***************************************************************************************************************
# Check if file was a filetype conversion, and accept the bigger filesize in that case
#***************************************************************************************************************
check_alternative_conversion () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "check_alternative_conversion"
    fi

    xNEW_DURATION=$((NEW_DURATION / 1000))
    xORIGINAL_DURATION=$((ORIGINAL_DURATION / 1000))
    xNEW_FILESIZE=$((NEW_FILESIZE / 1000))
    xORIGINAL_SIZE=$((ORIGINAL_SIZE / 1000))
    if [ "$EXT_CURR" == "$CONV_CHECK" ]; then
        handle_file_rename 0
        echo -e -n "${Red} FAILED! time:$xNEW_DURATION<$xORIGINAL_DURATION size:$xNEW_FILESIZE>$xORIGINAL_SIZE${Color_Off}\n"
    elif [ "$COPY_ONLY" != 0 ]; then
        DURATION_CHECK=$((DURATION_CHECK - 2000))
        if [ "$NEW_DURATION" -gt "$DURATION_CHECK" ]; then
            handle_file_rename 1
            echo "| Converted. $((ORIGINAL_DURATION - NEW_DURATION))sec and $(((ORIGINAL_SIZE - NEW_FILESIZE) / 1000))Mb in $TIMERVALUE"
            SUCCESFULFILECNT=$((SUCCESFULFILECNT + 1))
            TIMESAVED=$((TIMESAVED + DURATION_CUT))
        else
            echo -e -n "${Red}| FAILED CONVERSION! time:$xNEW_DURATION<$xORIGINAL_DURATION file:$xNEW_FILESIZE>$xORIGINAL_SIZE${Color_Off}\n"
            handle_file_rename 0
        fi
    else
        handle_file_rename 0
        echo -e -n "${Red} FAILED! time:$xNEW_DURATION<$xORIGINAL_DURATION size:$xNEW_FILESIZE>$xORIGINAL_SIZE${Color_Off}\n"
        RETVAL=1
    fi
}

#***************************************************************************************************************
# Verify if that file does indeed exist
#***************************************************************************************************************
check_if_files_exist () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "check_if_file_exists"
    fi

    FILE_EXISTS=0
    if [ "$MASSIVE_SPLIT" == 1 ]; then
        FILE_EXISTS=1
    elif [ "$SPLIT_FILE" == 1 ]; then
        if [ -f "${FILE}_1${CONV_TYPE}" ] && [ -f "${FILE}_2${CONV_TYPE}" ]; then
            FILE_EXISTS=1
        fi
    elif [ -f "$FILE$CONV_TYPE" ]; then
        FILE_EXISTS=1
    fi
}

#***************************************************************************************************************
# Check file handling, if size is smaller and destination file length is the same (with 2sec error marginal)
#***************************************************************************************************************
check_file_conversion () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "check_file_conversion"
    fi

    #if destination file exists
    check_if_files_exist
    if [ "$FILE_EXISTS" == 1 ]; then
        if [ "$SPLIT_FILE" == 1 ]; then
            DURATION_P1=$(mediainfo '--Inform=Video;%Duration%' "$FILE"_1"$CONV_TYPE")
            DURATION_P2=$(mediainfo '--Inform=Video;%Duration%' "$FILE"_2"$CONV_TYPE")
            NEW_DURATION=$((DURATION_P1 + DURATION_P2))
            NEW_FILESIZE=12
        else
            NEW_DURATION=$(mediainfo '--Inform=Video;%Duration%' "$FILE$CONV_TYPE")
            NEW_FILESIZE=$(du -k "$FILE$CONV_TYPE" | cut -f1)
        fi
        DURATION_CUT=$(((BEGTIME + ENDTIME) * 1000))
        DURATION_CHECK=$((ORIGINAL_DURATION - DURATION_CUT - 2000))
        ORIGINAL_SIZE=$(du -k "$FILE" | cut -f1)
        ORIGINAL_HOLDER=$ORIGINAL_SIZE
        if [ -z "$NEW_DURATION" ]; then
            NEW_DURATION=0
        fi

        if [ "$IGNORE" == "1" ] || [ "$SPLIT_FILE" == "1" ]; then
            ORIGINAL_SIZE=$((NEW_FILESIZE + 10000))
        fi

        #if video length matches (with one second error tolerance) and destination file is smaller than original, then
        if [ "$NEW_DURATION" -gt "$DURATION_CHECK" ] && [ "$ORIGINAL_SIZE" -gt "$NEW_FILESIZE" ]; then
            ORIGINAL_SIZE=$ORIGINAL_HOLDER
            ENDSIZE=$((ORIGINAL_SIZE - NEW_FILESIZE))
            TOTALSAVE=$((TOTALSAVE + ENDSIZE))
            SUCCESFULFILECNT=$((SUCCESFULFILECNT + 1))
            ENDSIZE=$((ENDSIZE / 1000))
            TIMESAVED=$((TIMESAVED + DURATION_CUT))
            if [ "$MASSIVE_SPLIT" == 1 ]; then
                echo -e -n "${Green} Success in $TIMERVALUE${Color_Off}\n"
            elif [ "$SPLIT_FILE" == 0 ]; then
                echo -e -n "${Green} Success! Saved $ENDSIZE Mb in $TIMERVALUE${Color_Off}\n"
            else
                echo -e -n "${Green} Done!${Color_Off}\n"
            fi
            handle_file_rename 1
        else
            check_alternative_conversion
        fi
    else
        echo -e -n "${Red} No destination file!${Color_Off}\n"
        if [ ! -d "./Nodest" ]; then
            mkdir "Nodest"
        fi
        mv "$FILE" "./Nodest"
        remove_interrupted_files
        RETVAL=1
    fi
}

#***************************************************************************************************************
# Check what kind of file handling will be accessed
#***************************************************************************************************************
handle_file_packing () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "handle_file_packing"
    fi

    Y=$(mediainfo '--Inform=Video;%Height%' "$FILE")
    CUTTING_TIME=$((BEGTIME + ENDTIME + DURATION_TIME))
    ORIGINAL_DURATION=$(mediainfo '--Inform=Video;%Duration%' "$FILE")
    if [[ "$ORIGINAL_DURATION" = *"."* ]]; then
        ORIGINAL_DURATION=$(grep -o "." <<< "$FILE" | wc -l)
    fi
    DUR=$((ORIGINAL_DURATION / 1000))

    if [ "$CROP" == 0 ]; then
        print_info
    fi

    if [ "$REPACK" == 1 ]; then
        XP=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        if [ "$HEVC_CONV" == 1 ]; then
            PACKSIZE="${XP}:${Y}"
        else
            PACKSIZE="${XP}x${Y}"
        fi
        COPY_ONLY=0
    else
        calculate_packsize
    fi

    if [ "$MP3OUT" == 1 ]; then
        extract_mp3
    elif [ "$CROP" == 1 ]; then
        check_and_crop
    else
        if [ "$HEVC_CONV" == 1 ]; then
            if [ "$COPY_ONLY" == 0 ]; then
                convert_hevc
            else
                copy_hevc
            fi
        elif [ "$SKIP" == 1 ] || [ "$SPLIT_FILE" == 1 ]; then
            remove_segment
        elif [ "$COPY_ONLY" == 0 ]; then
            pack_it
        else
            copy_it
        fi
        calculate_duration
        check_file_conversion
    fi
}

#***************************************************************************************************************
# Main file handling function
#***************************************************************************************************************
pack_file () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "pack_file"
    fi

    # if not SYS_INTERRUPTrupted and WORKMODE is for an existing dimensions
    X=$(mediainfo '--Inform=Video;%Width%' "$FILE")

    if [ "$PRINT_INFO" -gt 0 ]; then
        print_file_info
    else
        if [ ! -f "$FILE" ]; then
            MISSING=$((MISSING + 1))
            if [ "$PRINT_ALL" == 1 ]; then
                print_info
                echo "$FILE is not found!"
            fi
        elif [ -z "$X" ]; then
            handle_error_file
        elif [ "$WORKMODE" -gt 0 ] && [ "$X" -gt "$WIDTH" ]; then
            handle_file_packing
        elif [ "$PRINT_ALL" == 1 ]; then
            print_info
            echo "$FILE width:$X skipping"
        elif [ "$X" -le "$WIDTH" ] && [ "$FILECOUNT" == 1 ]; then
            if [ "$EXT_CURR" != "$CONV_TYPE" ]; then
                REPACK=1
                handle_file_packing
            else
                echo -e -n "${Yellow}$FILE cannot be packed $X <= $WIDTH${Color_Off}\n"
                RETVAL=1
            fi
        fi
    fi
}

#***************************************************************************************************************
# Calculate time taken to process data
#***************************************************************************************************************
calculate_time_taken () {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "calculate_time_taken"
    fi

    JUST_NOW=$(date +%s)
    SCRIPT_TOTAL_TIME=$((JUST_NOW - script_start_time))
    TIMER_TOTAL_PRINT=$(date -d@${SCRIPT_TOTAL_TIME} -u +%T)
}

#***************************************************************************************************************
# Verify that all necessary programs are installed
#***************************************************************************************************************
verify_necessary_programs() {
    if [ "$DEBUG_PRINT" == 1 ]; then
        echo "verify_necessary_programs"
    fi

    ff_missing=0
    av_missing=0
    mi_missing=0

    hash ffmpeg 2>/dev/null || ff_missing=$?
    hash avconv 2>/dev/null || av_missing=$?
    hash mediainfo 2>/dev/null || mi_missing=$?

    error_code=$((ff_missing + mi_missing))

    if [ "$av_missing" -ne 0 ]; then
        HEVC_CONV=1
    fi

    if [ "$error_code" -ne 0 ]; then
        echo -e -n "Missing necessary programs: "
        [ "$ff_missing" -ne 0 ] && echo -e -n "ffmpeg "
        [ "$av_missing" -ne 0 ] && echo -e -n "avconv "
        [ "$mi_missing" -ne 0 ] && echo -e -n "mediainfo "
        echo -e -n "\n"
        exit 1
    fi
}

#***************************************************************************************************************
# Check that at least one command was given, or print help
#***************************************************************************************************************
verify_commandline_input() {
    if [ "$#" -le 0 ]; then
        print_help
        exit 1
    fi
}

#***************************************************************************************************************
# The MAIN VOID function
#***************************************************************************************************************

verify_necessary_programs
verify_commandline_input "$@"

for var in "$@"
do
    parse_data "$var"
    CHECKRUN=$((CHECKRUN + 1))
done

if [ "$CHECKRUN" == "0" ]; then
        print_help
        RETVAL=1
elif [ "$CONTINUE_PROCESS" == "1" ]; then
    if [ ! -z "$SUBFILE" ]; then
        burn_subs
    elif [ "$FILECOUNT" -gt 1 ] || [ "$FileStrLen" -lt 5 ]; then
        EXT_CURR="$FILE"
        for f in *.$EXT_CURR
            do
                FILE="$f"
                CURRENTFILECOUNTER=$((CURRENTFILECOUNTER + 1))
                pack_file
            done
    elif [ "$MULTIFILECOUNT" -gt 1 ]; then
        for f in *$FILE*
            do
                if [ -f "$f" ]; then
                    FILE="$f"
                    EXT_CURR="${FILE##*.}"
                    CURRENTFILECOUNTER=$((CURRENTFILECOUNTER + 1))
                    pack_file
                fi
            done
    else
        FILECOUNT=1
        EXT_CURR="${FILE##*.}"
        pack_file
    fi

    if [ "$CURRENTFILECOUNTER" -gt "1" ]; then
        print_total
    fi
fi

exit "$RETVAL"
