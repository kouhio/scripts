#!/bin/bash

HEVC_CONV=1                     # Use ffmpeg instead of avconv to handle files
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
START_POSITION=0                # File to start handling from
END_POSITION=0                  # File where to no longer handle files

COPY_ONLY=1                     # Don't pack file, just copy data
EXT_CURR=""                     # Current files extension
CONV_TYPE=".mp4"                # Target filetype
CONV_CHECK="mp4"                # Target filetype extension handler
MP3OUT=0                        # Extract mp3 data, if set
AUDIO_PACK=0                    # Pack input file into target audio
WAV_OUT=0                       # extract wav from video

CALCTIME=0                      # Global variable to handle calculated time in seconds
TIMERVALUE=0                    # Printed time value, which is calculated
REPACK=0                        # Repack file instead of changing dimensions
REPACK_GIVEN=0                  # Repack value holder
IGNORE=0                        # Ignore bigger target file size
IGNORE_SPACE=0                  # Ignore space warning and proceed to next file
IGNORE_SPACE_SIZE=0             # Ignore too little space warning
TIMESAVED=0                     # Time cut out from modifying videos

CHECKRUN=0                      # Verificator of necessary inputs
CONTINUE_PROCESS=0              # If something went wrong, or file was split into multiple files, don't continue process

WIDTH=0                         # Width of the video
#HEIGHT=0                        # Height of the current video
DIMENSION_PARSED=0              # Handler to tell if the dimension was already parsed

KEEPORG=0                       # If set, will not delete original file after success

CROP=0                          # Crop video handler
EXIT_VALUE=0                    # Exit with error value
EXIT_CONTINUE=0                 # If set will not stop on too many errors
EXIT_REPEAT=0                   # If set, will repeat process on failed

PACKSIZE=""                     # Target file dimensions
ORIGINAL_DURATION=0             # Original duration of input file
NEW_DURATION=0                  # Duration after cutting file
NEW_FILESIZE=0                  # Filesize after processing
ORIGINAL_SIZE=0                 # Input filesize

PRINT_ALL=0                     # Print information only on file(s)
PRINT_INFO=0                    # Will print information according to value

DEBUG_PRINT=0                   # Print function name in this mode
MASSIVE_SPLIT=0                 # Splitting one file into multiple files
MASSIVE_TIME_SAVE=0             # Save each split total to this handler
MASSIVE_COUNTER=0               # Counter of multisplit items handled

MASSIVE_TIME_CHECK=0            # Wanted total time of output files
MASSIVE_TIME_COMP=0             # Actual total time of output files
SPLIT_MAX=0                     # Number of files input is to be split into
SPLIT_AND_COMBINE=0             # If set, will combine a new file from splitted files
MASSIVE_FILE_HANDLE=0           # If set, will not raise the global filecount more than once

SUBFILE=""                      # Path to subtitle file to be burned into target video
SUBERR=0                        # Subfile error checker
WRITEOUT=""                     # Target filename for file info printing
NEWNAME=""                      # New target filename, if not set, will use input filename
TARGET_DIR="."                  # Target directory for successful file

process_start_time=0            # Time in seconds, when processing started
script_start_time=$(date +%s)   # Time in seconds, when the script started running

RETVAL=0                        # If everything was done as expected, is set to 0

SPACELEFT=0                     # Target directory drive space left
SIZETYPE="Mb"                   # Saved size type
SAVESIZE=0                      # Calculated value of size saved

ERROR_WHILE_MORPH=0

APP_NAME=/usr/bin/ffmpeg        # current application name to be used
COMMAND_LINE=""                 # command line options to be set up later
COMMAND_ADD=""                  # command line options, that will be set up each time
APP_SETUP=0                     # variable to see, if the setup has already been set
CURRENT_TIMESAVE=0              # Time saved during editing session
SPLITTER_TIMESAVE=0             # Time saved during splitting

COMBINELIST=()                  # combine file list
COMBINEFILE=0                   # variable for combining files handler

AUDIOTRACK=""                   # Audiotrack number
VIDEOTRACK=""                   # Videotrack number
LANGUAGE="en"                   # Wanted audiotrack language
SPLITTING_ERROR=0               # Is set when splitting fails

AUDIODELAY=""                   # Delay audio by given value
VIDEODELAY=""                   # Delay video by given value

TOTAL_ERR_CNT=0                 # Number of errors occured

# If this value is not set, external program is not accessing this and exit -function will be used normally
[ -z "$NO_EXIT_EXTERNAL" ] && NO_EXIT_EXTERNAL=0

#***************************************************************************************************************
# Define regular colors for echo
#***************************************************************************************************************
Black='\033[0;30m'
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
Blue='\033[0;34m'
Purple='\033[0;35m'
Cyan='\033[0;36m'
White='\033[0;37m'
Color_Off='\033[0m'

#***************************************************************************************************************
# Change printout type to corrent
#***************************************************************************************************************
check_valuetype () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    SAVESIZE=0
    SIZETYPE="kb"
    HAND_VAL="$1"

    [ -z "$1" ] && return

    [ "$1" -lt "0" ] && HAND_VAL=$((HAND_VAL * -1))

    if [ "$HAND_VAL" -lt "1000" ]; then
        SAVESIZE="$1"
        SIZETYPE="kb"
    elif [ "$HAND_VAL" -lt "1000000" ]; then
        SIZETYPE="Mb"
        SAVESIZE=$(bc <<<"scale=2; $1 / 1000")
    else
        SIZETYPE="Gb"
        SAVESIZE=$(bc <<<"scale=2; $1 / 1000000")
    fi
}

#***************************************************************************************************************
# Print total handled data information
#***************************************************************************************************************
print_total () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    GLOBAL_FILESAVE=$((GLOBAL_FILESAVE + TOTALSAVE))
    check_valuetype "$TOTALSAVE"
    #TOTALSAVE=$((TOTALSAVE / 1000))

    if [ "$PRINT_INFO" == 1 ]; then
        TIMESAVED=$(date -d@${TIMESAVED} -u +%T)
        echo "Total in $CURRENTFILECOUNTER files, Size:$SAVESIZE Length:$TIMESAVED"
    else
        if [ "$TIMESAVED" -gt "0" ]; then
            if [ "$MASSIVE_TIME_SAVE" -gt "0" ]; then TIMESAVED=$(((ORIGINAL_DURATION / 1000) - MASSIVE_TIME_SAVE))
            else                                      TIMESAVED=$((TIMESAVED  / 1000)); fi
            calculate_time_given "$TIMESAVED"
        fi
        calculate_time_taken

        if [ "$COPY_ONLY" == 0 ] || [ "$TIMESAVED" -gt "0" ]; then echo "Totally saved $SAVESIZE ${SIZETYPE} $TIMER_SECOND_PRINT on $SUCCESFULFILECNT files in $TIMER_TOTAL_PRINT"
        elif [ -n "$SUBFILE" ]; then                               echo "Burned subs to $SUCCESFULFILECNT files (size change: $SAVESIZE ${SIZETYPE}) in $TIMER_TOTAL_PRINT"
        else                                                       echo "Handled $SUCCESFULFILECNT files to $CONV_CHECK (size change: $SAVESIZE ${SIZETYPE}) in $TIMER_TOTAL_PRINT"; fi

        [ "$MISSING" -gt "0" ] && echo "Number of files disappeared during process: $MISSING" && RETVAL=1
    fi
}

#***************************************************************************************************************
# Remove incomplete destination files
#***************************************************************************************************************
remove_interrupted_files () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    [ -f "$FILE$CONV_TYPE" ]     && delete_file "$FILE$CONV_TYPE"
    [ -f "$FILE"_1"$CONV_TYPE" ] && delete_file "$FILE"_1"$CONV_TYPE"
    [ -f "$FILE"_2"$CONV_TYPE" ] && delete_file "$FILE"_2"$CONV_TYPE"
    [ -f "$NEWNAME" ] && delete_file "$NEWNAME"
}

#***************************************************************************************************************
#If SYS_INTERRUPTted, stop process, remove files not complete and print final situation
#***************************************************************************************************************
set_int () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    shopt -u nocaseglob
    calculate_duration
    echo " Main conversion interrupted in ${TIMERVALUE}!"
    remove_interrupted_files
    EXIT_EXT_VAL=1

    [ -f "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" ] && rm "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}"

    [ "$MASSIVE_TIME_SAVE" -gt "0" ] && GLOBAL_TIMESAVE=$((GLOBAL_TIMESAVE + (ORIGINAL_DURATION / 1000) - MASSIVE_TIME_SAVE))

    if [ "$NO_EXIT_EXTERNAL" -ne "0" ]; then
        check_valuetype "$GLOBAL_FILESAVE"
        [ "$SPLITTER_TIMESAVE" -gt "0" ] && SPLITTER_TIMESAVE=$(((ORIGINAL_DURATION - SPLITTER_TIMESAVE) / 1000))
        calculate_time_given "$((GLOBAL_TIMESAVE + CURRENT_TIMESAVE + SPLITTER_TIMESAVE))"
        printf "Globally saved $SAVESIZE $SIZETYPE and removed time: $TIMER_SECOND_PRINT\n"
    else
        print_total
    fi

    [ "$NO_EXIT_EXTERNAL" == "0" ] && exit 1
}

trap set_int SIGINT SIGTERM

#**************************************************************************************************************
# Print script functional help
#***************************************************************************************************************
print_help () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    echo -en "No input file! first input is always 'combine/merge/append' or filename (filename, file type or part of filename)\n\n"
    echo -en "To set dimensions Nx (where N is width, height is automatically calculated to retain aspect ratio)\n\n"
    echo "b(eg)=       -    time to remove from beginning (either seconds or X:Y:Z)"
    echo "e(nd)=       -    time to remove from end (calculated from the end) (either seconds or X:Y:Z)"
    echo "d(uration)=  -    Time from the beginning X:Y:Z, to skip the end after that"
    echo -en "t(arget)=    -    filetype to set destination filetype (mp4 as default)\n\n"
    echo "i(gnore)     -    to ignore size (both too big, or too small)"
    echo "I(gnore)     -    to ignore space check exit (not the space check) and continue to next file"
    echo "F(orce)      -    to ignore space check and pack file instead"
    echo "r(epack)     -    to repack file with original dimensions (if target width has been given, will repack only videos smaller than new given size)"
    echo "k(eep)       -    to keep the original file after succesful conversion"
    echo "m(p3)        -    to extract mp3 from the file"
    echo "M(p3)        -    pack input audio file(s) into mp3 file"
    echo "w(av)=       -    extract wav from input file"
    echo "A(udio)=     -    convert audiofile to another audio filetype"
    echo "a(ll)        -    print all information"
    echo "p(rint)      -    print only file information (if set as 1, will print everything, 2 = lessthan, 3=biggerthan, 4=else )"
    echo "h(evc)       -    convert with avconv instead of ffmpeg"
    echo "s(crub)      -    original on completion"
    echo -en "crop         -    crop black borders (experimental atm, probably will cut too much of the area)\n\n"
    echo "sub=         -    subtitle file to be burned into video, or if the file itself has subtitles embedded, the number of the wanted subtitle track (starting from 0)"
    echo "w(rite)=     -    Write printing output to file"
    echo "n(ame)=      -    Give file a new target name (without file extension)"
    echo -en "T(arget)=    -    Target directory for the target file\n\n"
    echo "c(ut)=       -    time where to cut,time where to cut next piece,next piece,etc"
    echo "c(ut)=       -    time to begin - time to end,next time to begin-time to end,etc"
    echo "C(ombine)=   -    same as cutting with begin-end, but will combine split videos to one"
    echo -en "             -    When setting cut or Cut, adding D as the last point, will delete the original file if successful\n\n"
    echo "P(osition)   -    Start handling only from Nth file set in position. If not set, will handle all files"
    echo -en "E(nd)        -    Stop handling files after Nth position. If set as 0 (default) will run to the end\n\n"
    echo "combine      -    If given as a first input, all input after are read as files, and are combined into one file"
    echo "merge        -    If given as a first input, first file after is the video, and rest all audio files to be overwritten to the video"
    echo "append       -    If given as a first input, first file after is the video, and all the rest of the audio is added to the video as their own tracks"
    echo -en "             -    If any input is given as 'delete', deletes all sources, if combining/merge/append is successful\n\n"
    echo "repeat       -    repeat process on failed result"
    echo "continue     -    ignore too many errors"
    echo -en "quit         -    Exit after an error with exit code\n\n"
    echo "vt           -    Wanted videotrack from input file, if multiple, separate each with :"
    echo "at           -    Wanted audiotrack from input file, if multiple, separate each with :"
    echo "delaudio     -    Delay audio by given seconds"
    echo "delvideo     -    Delay video by given seconds"
    echo -en "l(anguage)   -    Wanted output audio language with two letters, default:en\n\n"
    echo "example:     ${0} \"FILENAME\" 640x c=0:11-1:23,1:0:3-1:6:13,D"
}

#*************************************************************************************************************
# Find image position in a video
# 1 - Video file
# 2 - Image file
# 3 - first or last
#**************************************************************************************************************
find_image_pos () {
    [[ ! "$APP_NAME" =~ "ffmpeg" ]] && echo "Can't seek images without ffmpeg!" && exit 1
    [ "$DEBUG_PRINT" == 1 ] && echo -en "Seeking time from '$1' by '$2'"
    IMAGEPOS=$(ffmpeg -i "$1" -r 1 -loop 1 -i "$2" -an -filter_complex "blend=difference:shortest=1,blackframe=99:32,metadata=print:file=-" -f null -v quiet -)
    IMAGETIME=$(echo "$IMAGEPOS" |grep "blackframe" -m 1)

    if [ -z "$3" ]; then IMAGETIME="${IMAGEPOS#*pts_time:}"
    else IMAGETIME="${IMAGEPOS##*pts_time:}"; fi

    IMAGETIME="${IMAGETIME%%.*}"
    [ "$DEBUG_PRINT" == 1 ] && echo " image at :$IMAGETIME"
}

#**************************************************************************************************************
# Crop out black borders (this needs more work, kind of hazard at the moment.
# TODO: Needs to verify dimensional changes, so it won't cut too much
#***************************************************************************************************************
check_and_crop () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ "$SPLIT_AND_COMBINE" -eq "1" ] && [[ ! "$APP_NAME" =~ "ffmpeg" ]]; then
        printf "${Red}Cannot crop files with ${Yellow}$APP_NAME${Red} Aborting!${Color_Off}\n"
        exit 1
    fi

    CROP_DATA=$($APP_NAME -i "$FILE" -t 1 -vf cropdetect -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1)
    if [ -n "$CROP_DATA" ]; then
        XC=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        YC=$(mediainfo '--Inform=Video;%Height%' "$FILE")

        if [ -n "$XC" ] && [ -n "$YC" ]; then
            CB=$(echo "$CROP_DATA" | cut -d = -f 2)
            C1=$(echo "$CB" | cut -d : -f 1)
            C2=$(echo "$CB" | cut -d : -f 2)
            C3=$(echo "$CB" | cut -d : -f 3)
            C4=$(echo "$CB" | cut -d : -f 4)

            if [ "$C1" -ge "0" ] && [ "$C2" -ge "0" ]; then
                if [ "$XC" -ne "$C1" ] || [ "$YC" -ne "$C2" ] || [ "$C3" -gt "0" ] || [ "$C4" -gt "0" ]; then
                    if [ "$C1" -ge "320" ] && [ "$C2" -ge "240" ]; then
                        print_info
                        short_name
                        process_start_time=$(date +%s)
                        PROCESS_NOW=$(date +%T)
                        printf "$PROCESS_NOW : $FILEprint Cropping black borders ->($CROP_DATA) \t"
                        $APP_NAME -i "$FILE" -vf "$CROP_DATA" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
                        calculate_duration
                        check_file_conversion
                    else
                        printf "${Yellow}$FILE ${Red}Cropping to ${C1}x${C2} ($C3 $C4) makes video too small! Skipping!${Color_Off}\n"
                    fi
                fi
            fi
        fi
    fi
}

#**************************************************************************************************************
# Check WORKMODE for removing time data
#***************************************************************************************************************
check_workmode () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ "$BEGTIME" != "D" ]; then
        if [ "$BEGTIME" -gt 0 ] && [ "$ENDTIME" -gt 0 ]; then           WORKMODE=3
        elif [ "$BEGTIME" -gt 0 ] && [ "$DURATION_TIME" -gt 0 ]; then   WORKMODE=3
        elif [ "$BEGTIME" -gt 0 ]; then                                 WORKMODE=1
        elif [ "$ENDTIME" -gt 0 ] || [ "$DURATION_TIME" -gt 0 ]; then   WORKMODE=2; fi
    fi
}

#***************************************************************************************************************
# Check if given value starts with a 0 and remove it
# 1 - Value to be verified and modified
#***************************************************************************************************************
check_zero () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    ZERORETVAL="$1"
    ttime="${1:0:1}"
    [ -n "$ttime" ] && [ "$ttime" == "0" ] && ZERORETVAL="${1:1:1}"
}

#**************************************************************************************************************
# Delete file / scrub file
# 1 - path to filename
#***************************************************************************************************************
delete_file () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ -f "$1" ]; then
        if [ "$SCRUB" == "1" ]; then   scrub -r "$1" >/dev/null 2>&1
        elif [ "$SCRUB" == "2" ]; then scrub -r "$1"
        else                           rm "$1"; fi
    fi
}

#**************************************************************************************************************
# Check that the timelength matches with the destination files from splitting
#***************************************************************************************************************
ERROR_WHILE_SPLITTING=0

massive_filecheck () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ "$ERROR_WHILE_SPLITTING" != "0" ] || [ "$ERROR_WHILE_MORPH" != "0" ]; then
        printf "${Red}Something went wrong with splitting $FILE${Color_Off}\n"
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

    [ "$IGNORE" -ne "0" ] && TOO_SMALL_FILE=0
    [ "$SPLIT_AND_COMBINE" -ne "0" ] && TOO_SMALL_FILE=0

    if [ "$MASSIVE_TIME_COMP" -ge "$MASSIVE_TIME_CHECK" ] && [ "$TOO_SMALL_FILE" == "0" ] && [ "$SPLITTING_ERROR" == "0" ]; then
        TIME_SHORTENED=$((ORIGINAL_DURATION - MASSIVE_TIME_COMP))
        SPLITTER_TIMESAVE=$((SPLITTER_TIMESAVE + MASSIVE_TIME_COMP))
        TIME_SHORTENED=$((TIME_SHORTENED / 1000))

        if [ "$KEEPORG" == "0" ] && [ "$ERROR_WHILE_MORPH" == "0" ]; then
            OSZ=$(du -k "$FILE" | cut -f1)
            delete_file "$FILE"
            OSZ=$((OSZ - MASSIVE_SIZE_COMP))
            check_valuetype "$OSZ"
            FINAL_TIMESAVE=$(((ORIGINAL_DURATION / 1000) - MASSIVE_TIME_SAVE))
            calculate_time_given "$FINAL_TIMESAVE"
            printf "${Yellow}Saved %-6.6s ${SIZETYPE} and $TIMER_SECOND_PRINT with splitting${Color_Off}\n" "$SAVESIZE"
            GLOBAL_FILESAVE=$((GLOBAL_FILESAVE + OSZ))
            [ "$MASSIVE_FILE_HANDLE" -le "1" ] && GLOBAL_FILECOUNT=$((GLOBAL_FILECOUNT + 1))
            [ "$MASSIVE_FILE_HANDLE" -eq "1" ] && MASSIVE_FILE_HANDLE=2
        else
            printf "${Yellow}Finished${Color_Off}\n"
        fi

    else
        printf "${Red}Something wrong with cut-out time ($MASSIVE_TIME_COMP < $MASSIVE_TIME_CHECK) Small files: $TOO_SMALL_FILE${Color_Off}\n"
        RETVAL=1
    fi
}

#***************************************************************************************************************
# Split file into chunks given by input parameters, either (start-end,start-end|...) or (point,point,point,...)
# 1 - Splitting time information
#***************************************************************************************************************
new_massive_file_split () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    IGNORE=1
    MASSIVE_FILE_HANDLE=1

    if [ "$SPLIT_AND_COMBINE" -eq "1" ]; then
        if [[ ! "$APP_NAME" =~ "ffmpeg" ]]; then
            printf "${Red}Cannot combine files with ${Yellow}$APP_NAME${Red} Aborting!${Color_Off}\n"
            exit 1
        fi
    fi

    MASSIVE_TIME_CHECK=0
    FILECOUNT=1
    MASSIVE_SPLIT=1
    KEEPORG=1

    if [ -f "$FILE" ]; then
        EXT_CURR="${FILE##*.}"
        LEN=$(mediainfo '--Inform=Video;%Duration%' "$FILE")
        XSS=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        LEN=${LEN%.*}
        LEN=$((LEN / 1000))

        SPLIT_P2P=$(grep -o "-" <<< "$1" | wc -l)

        IFS=","
        DO_THE_SPLITS="$1"
        array=(${DO_THE_SPLITS//,/$IFS})
        SPLIT_MAX=${#array[@]}
        MASSIVE_COUNTER=0

        for index in "${!array[@]}"; do
            APP_SETUP=0
            if [ "$SPLIT_P2P" -gt 0 ]; then
                IFS="-"
                array2=(${array[index]//-/$IFS})

                if [ "${array2[0]}" == "D" ]; then
                    KEEPORG=0
                    break
                fi

                [ "$index" -ne "0" ] && printf "\n"

                calculate_time "${array2[0]}"
                BEGTIME=$CALCTIME
                calculate_time "${array2[1]}" "1"
                ENDTIME=$CALCTIME

                if [ -z "$XSS" ] || [ -z "$WIDTH" ]; then
                    echo "Something wrong with width w:$WIDTH s:$XSS"
                    ERROR_WHILE_SPLITTING=1
                    RETVAL=1
                    continue
                fi

                #echo "1 - e:$ENDTIME b:$BEGTIME w:$WIDTH x:$XSS"

                if [ "$ENDTIME" -le "$BEGTIME" ] && [ "$ENDTIME" != "0" ] || [ "$WIDTH" -ge "$XSS" ]; then
                    ERROR_WHILE_SPLITTING=1
                    printf "${Red}Split error $FILE - Time: $ENDTIME <= $BEGTIME, Size: $WIDTH >= $XSS${Color_Off}\n"
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
                if [ "${array[index + 1]}" == "D" ]; then
                    KEEPORG=0
                fi

                [ "$index" -ne "0" ] && printf "\n"

                calculate_time "${array[index]}"
                SPLIT_POINT=$CALCTIME
                calculate_time "${array[index + 1]}" "1"
                SPLIT_POINT2=$CALCTIME
                if [ "$SPLIT_POINT2" -le "$SPLIT_POINT" ] && [ $SPLIT_POINT2 != "0" ] || [ "$WIDTH" -ge "$XSS" ]; then
                    ERROR_WHILE_SPLITTING=1
                    printf "${Red}Split error $FILE - Time: $SPLIT_POINT2 <= $SPLIT_POINT, - Size: $WIDTH <= $XSS${Color_Off}\n"
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

            MASSIVE_COUNTER=$((MASSIVE_COUNTER + 1))
        done

        massive_filecheck

        if [ "$SPLIT_AND_COMBINE" -eq "1" ]; then
            if [ "$RETVAL" -eq "0" ]; then
                combine_split_files
            else
                remove_combine_files
                [ "$EXIT_VALUE" == "1" ] && exit 1
            fi
        fi

        [ "$index" == "1" ] && [ -z "$NEWNAME" ] && rename "s/_01//" "${FILE%.*}"*
        [ "$index" -le "1" ] && [ -n "$NEWNAME" ] &&  rename "s/_01//" "${NEWNAME%.*}"*

    else
        echo "File '$FILE' not found, cannot split!"
        [ "$EXIT_VALUE" == "1" ] && exit 1
    fi

    CONTINUE_PROCESS=0
    MASSIVE_FILE_HANDLE=0
}

#***************************************************************************************************************
# Rename files for concate compatibility or remove them
# 1 - if set, will rename files, if not, will remove the renamed files
#***************************************************************************************************************
COMBINE_RUN_COUNT=0
make_or_remove_split_files() {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    RUNNING_FILE_NUMBER=1

    while true; do
        make_running_name

        if [ -z "$1" ]; then
            [ ! -f "${TARGET_DIR}/temp_${RUNNING_FILE_NUMBER}$CONV_TYPE" ] && break
            rm "${TARGET_DIR}/temp_${RUNNING_FILE_NUMBER}$CONV_TYPE"

        else
            [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ] && break

            mv "${TARGET_DIR}/$RUNNING_FILENAME" "${TARGET_DIR}/temp_${RUNNING_FILE_NUMBER}$CONV_TYPE"

            if [ "$TARGET_DIR" == "." ]; then echo "file 'temp_${RUNNING_FILE_NUMBER}$CONV_TYPE'" >> "packcombofile.txt"
            else                              echo "file 'temp_${RUNNING_FILE_NUMBER}$CONV_TYPE'" >> "${TARGET_DIR}/packcombofile.txt"; fi
        fi

        COMBINE_RUN_COUNT="$RUNNING_FILE_NUMBER"
        RUNNING_FILE_NUMBER=$((RUNNING_FILE_NUMBER + 1))
    done
}

#***************************************************************************************************************
# In case of failure, remove files meant to be combined
#***************************************************************************************************************
remove_combine_files() {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    RUNNING_FILE_NUMBER=1

    while true; do
        make_running_name

        [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ] && break
        rm "${TARGET_DIR}/$RUNNING_FILENAME"

        COMBINE_RUN_COUNT="$RUNNING_FILE_NUMBER"
        RUNNING_FILE_NUMBER=$((RUNNING_FILE_NUMBER + 1))
    done
}

#***************************************************************************************************************
# Combine split files into one file, then remove splitted files and rename combofile
#***************************************************************************************************************
combine_split_files() {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ "$SPLITTING_ERROR" != "0" ]; then
        printf "Failed to separate all asked parts, not combining!"
        rm "${TARGET_DIR}/packcombofile.txt"
        rm "${TARGET_DIR}/tmp_combo$CONV_TYPE"
        [ "$EXIT_VALUE" == "1" ] && exit 1
        return 0
    fi

    process_start_time=$(date +%s)
    make_or_remove_split_files 1
    CURRDIR="$PWD"
    cd "$TARGET_DIR"

    ERROR=0
    printf "%-57.57s Combining $COMBINE_RUN_COUNT split files " " "
    $APP_NAME -f concat -i "packcombofile.txt" -c copy "tmp_combo$CONV_TYPE"  -v quiet >/dev/null 2>&1
    ERROR=$?

    cd "$CURRDIR"
    rm "${TARGET_DIR}/packcombofile.txt"

    if [ "$ERROR" -eq "0" ]; then
        LE_ORG_FILE="$FILE"
        FILE="temp.mp4"
        make_or_remove_split_files
    else
        printf "${Red}Failed${Color_Off}\n"
        rm "${TARGET_DIR}/tmp_combo$CONV_TYPE"
        [ "$EXIT_VALUE" == "1" ] && exit 1
        return
    fi

    if [ -f "$LE_ORG_FILE" ]; then
        RUNNING_FILE_NUMBER=1
        FILE="Combo_$LE_ORG_FILE"
        make_running_name

        if [ -f "${TARGET_DIR}/$RUNNING_FILENAME" ]; then
            while true; do
                make_running_name
                [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ] && break
                RUNNING_FILE_NUMBER=$((RUNNING_FILE_NUMBER + 1))
            done
        fi

        if [ -z "$NEWNAME" ]; then mv "${TARGET_DIR}/tmp_combo$CONV_TYPE" "${TARGET_DIR}/${RUNNING_FILENAME}"
        else                       mv "${TARGET_DIR}/tmp_combo$CONV_TYPE" "${TARGET_DIR}/${NEWNAME}${CONV_TYPE}"; fi
    else
        if [ -z "$NEWNAME" ]; then mv "${TARGET_DIR}/tmp_combo$CONV_TYPE" "${TARGET_DIR}/${LE_ORG_FILE}"
        else                       mv "${TARGET_DIR}/tmp_combo$CONV_TYPE" "${TARGET_DIR}/${NEWNAME}${CONV_TYPE}"; fi
        RUNNING_FILENAME="${LE_ORG_FILE}"
    fi

    calculate_duration
    calculate_time_taken
    calculate_time_given "$TIME_SHORTENED"
    printf "${Green} Success in $TIMERVALUE/$TIMER_TOTAL_PRINT ${Yellow}${RUNNING_FILENAME}${Color_Off} Shortened:$TIMER_SECOND_PRINT\n"
    FILE="$LE_ORG_FILE"
}

#***************************************************************************************************************
# Combine given input files to one file
#***************************************************************************************************************
combineFiles () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    FILESCOUNT=0
    DELETESOURCEFILES=0

    for file in "${COMBINELIST[@]}"; do
        [ -f "$file" ] && echo "file '$file'" >> "packcombofile.txt" && FILESCOUNT=$((FILESCOUNT + 1))
        [ "$file" == "delete" ] && DELETESOURCEFILES=1
        [ "$FILESCOUNT" -gt "0" ] && [ -z "$NEWNAME" ] && NEWNAME="$file"
    done

    if [ "$FILESCOUNT" -gt "1" ];  then
        [ -z "$NEWNAME" ] && NEWNAME="target_combo"

        printf "Combining $FILESCOUNT files "
        ERROR=0
        $APP_NAME -f concat -safe 0 -i "packcombofile.txt" -c copy "${TARGET_DIR}/${NEWNAME}_${CONV_TYPE}" -v quiet >/dev/null 2>&1
        ERROR=$?

        rm "packcombofile.txt"

        if [ "$ERROR" -eq "0" ]; then
            if [ "$DELETESOURCEFILES" == "1" ]; then
                for file in "${COMBINELIST[@]}"; do
                    [ -f "$file" ] && rm "$file"
                done

                printf "${Green}Combined $FILESCOUNT files to ${TARGET_DIR}/${NEWNAME}_${CONV_TYPE},${Color_Off} deleted all sourcefiles\n"
            else
                printf "${Green}Combined $FILESCOUNT files to ${TARGET_DIR}/${NEWNAME}_${CONV_TYPE}${Color_Off}\n"
            fi

            exit 0
        else
            printf "${Red}Failed to combine $FILESCOUNT as ${TARGET_DIR}/${NEWNAME}_${CONV_TYPE}${Color_Off}\n"
            exit 1
        fi
    else
        [ -f "packcombofile.txt" ] && rm "packcombofile.txt"
        printf "${Red}No input files given to combine! Filecount:$FILESCOUNT${Color_Off}\n"
        exit 1
    fi
}

#***************************************************************************************************************
# Replace or insert audio in video file with given audio files
# 1 - If not set, is a merge, else append
#***************************************************************************************************************
mergeFiles () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ -z "$1" ]; then SETUPSTRING="-map 0:v " && TYPE="Merge"
    else SETUPSTRING="-map 0 " && TYPE="Append"; fi

    FILESCOUNT=0
    DELETESOURCEFILES=0
    COMMANDSTRING=()
    ORIGNAME=""
    ORGSIZE=0

    for file in "${COMBINELIST[@]}"; do
        if [ -f "$file" ]; then
            COMMANDSTRING+=(-i "${file}")
            OSIZE=$(du -k "$file" | cut -f1)
            [ "$FILESCOUNT" -gt "0" ] && SETUPSTRING+="-map ${FILESCOUNT}:a "
            FILESCOUNT=$((FILESCOUNT + 1))
            ORIGSIZE=$((ORIGSIZE + OSIZE))
        fi
        [ "$file" == "delete" ] && DELETESOURCEFILES=1
        [ "$FILESCOUNT" -gt "0" ] && [ -z "$NEWNAME" ] && NEWNAME="$file" && ORIGNAME="$file"
        [[ "$ORIGNAME" =~ "${CONV_TYPE}" ]] && ORIGNAME="${ORIGNAME%.*}.${CONV_TYPE}"
    done

    SETUPSTRING+="-c:v copy -shortest "

    if [ "$FILESCOUNT" -gt "1" ];  then
        [ -z "$NEWNAME" ] && NEWNAME="target_combo"
        [ -f "${TARGET_DIR}/${NEWNAME}_${CONV_TYPE}" ] && NEWNAME="merged_$NEWNAME"

        printf "$(date -u +%T) $TYPE $FILESCOUNT files "
        ERROR=0
        $APP_NAME "${COMMANDSTRING[@]}" $SETUPSTRING "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" >/dev/null 2>&1
        ERROR=$?

        calculate_time_taken

        if [ "$ERROR" -eq "0" ]; then
            if [ "$DELETESOURCEFILES" == "1" ]; then
                for file in "${COMBINELIST[@]}"; do [ -f "$file" ] && rm "$file"; done
                NEWSIZE=$(du -k "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" | cut -f1)
                NEWSIZE=$(((ORGSIZE - NEWSIZE) / 1000))
                [ "$NEWNAME" != "$ORIGNAME" ] && mv "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" "${TARGET_DIR}/${ORIGNAME}"
                printf "${Green}Success into ${TARGET_DIR}/${ORIGNAME},${Color_Off} deleted all sourcefiles in $TIMER_TOTAL_PRINT saved ${NEWSIZE}Mb\n"
            else
                printf "${Green}Success into ${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}${Color_Off} in $TIMER_TOTAL_PRINT\n"
            fi

            exit 0
        else
            printf "${Red}Failed!${Color_Off} in $TIMER_TOTAL_PRINT\n"
            rm "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}"
            exit 1
        fi
    else
        printf "${Red}Not enough input files given to $TYPE! Filecount:$FILESCOUNT${Color_Off}\n"
        exit 1
    fi
}

#***************************************************************************************************************
# Separate and calculate given time into seconds and set to corresponting placeholder
# 1 - time value in hh:mm:ss / mm:ss / ss or a filename
#***************************************************************************************************************
calculate_time () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    CALCTIME=0
    ADDTIME=0

    if [ -n "$1" ]; then
        [ "$1" == "D" ] && return

        if [ -f "$1" ]; then
            find_image_pos "$FILE" "$1" "$2"
            CALCTIME="$IMAGETIME"
        else
            if [[ "$1" =~ "." ]]; then
                ADDTIME="${1##*.}"
                MAINTIME="${1%.*}"
            else
                MAINTIME="$1"
            fi

            t1=$(echo "$MAINTIME" | cut -d : -f 1)
            t2=$(echo "$MAINTIME" | cut -d : -f 2)
            t3=$(echo "$MAINTIME" | cut -d : -f 3)

            occ=$(grep -o ":" <<< "$MAINTIME" | wc -l)

            check_zero "$t1"
            t1=$ZERORETVAL
            check_zero "$t2"
            t2=$ZERORETVAL
            check_zero "$t3"
            t3=$ZERORETVAL

            if [ "$occ" == "0" ]; then
                calc_time=$MAINTIME
            elif [ "$occ" == "1" ]; then
                t1=$((t1 * 60))
                calc_time=$((t1 + t2))
            else
                t1=$((t1 * 3600))
                t2=$((t2 * 60))
                calc_time=$((t1 + t2 + t3))
            fi

            CALCTIME=$calc_time
            [ "$ADDTIME" != "0" ] && CALCTIME+=".${ADDTIME}"
        fi
    fi
}

#**************************************************************************************************************
# Parse special handlers
#***************************************************************************************************************
parse_handlers () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ -n "$1" ]; then
        if [ "$1" == "repack" ] || [ "$1" == "r" ]; then
            REPACK=1
            REPACK_GIVEN=1
            COPY_ONLY=0
        elif [ "$1" == "quit" ]; then
            EXIT_VALUE=1
        elif [ "$1" == "repeat" ]; then
            EXIT_REPEAT=1
        elif [ "$1" == "continue" ]; then
            EXIT_CONTINUE=1
        elif [ "$1" == "ignore" ] || [ "$1" == "i" ]; then
            IGNORE=1
        elif [ "$1" == "Ignore" ] || [ "$1" == "I" ]; then
            IGNORE_SPACE=1
        elif [ "$1" == "Force" ] || [ "$1" == "F" ]; then
            IGNORE_SPACE_SIZE=1
        elif [ "$1" == "keep" ] || [ "$1" == "k" ]; then
            KEEPORG=1
        elif [ "$1" == "wav" ] || [ "$1" == "w" ]; then
            KEEPORG=1
            AUDIO_PACK=1
            CONV_TYPE=".wav"
            CONV_CHECK="wav"
            WAV_OUT=1
        elif [ "$1" == "Mp3" ] || [ "$1" == "M" ]; then
            KEEPORG=1
            AUDIO_PACK=1
            CONV_TYPE=".mp3"
            CONV_CHECK="mp3"
        elif [ "$1" == "mp3" ] || [ "$1" == "m" ]; then
            KEEPORG=1
            MP3OUT=1
            CONV_TYPE=".mp3"
            CONV_CHECK="mp3"
        elif [ "$1" == "all" ] || [ "$1" == "a" ]; then
            PRINT_ALL=1
        elif [ "$1" == "crop" ] || [ "$1" == "s" ]; then
            CROP=1
        elif [ "$1" == "scrub" ] || [ "$1" == "s" ]; then
            SCRUB=1
        elif [ "$1" == "print" ] || [ "$1" == "p" ]; then
            PRINT_INFO=1
        elif [ "$1" == "hevc" ] || [ "$1" == "h" ]; then
            #IGNORE=1
            APP_NAME="avconv"
            HEVC_CONV=0
        elif [ "$1" == "D" ]; then
            DEBUG_PRINT=1
        else
            echo "Unknown handler $1"
            RETVAL=1
            #[ "$NO_EXIT_EXTERNAL" == "0" ] && exit "$RETVAL"
            exit "$RETVAL"
        fi
    fi
}

#**************************************************************************************************************
# Parse time values to remove
# 1 - input value
#***************************************************************************************************************
parse_values () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ -n "$1" ]; then
        HANDLER=$(echo "$1" | cut -d = -f 1)
        VALUE=$(echo "$1" | cut -d = -f 2)

        if [ "$HANDLER" == "beg" ] || [ "$HANDLER" == "b" ]; then
            calculate_time "$VALUE"
            BEGTIME=$CALCTIME
        elif [ "$HANDLER" == "end" ] || [ "$HANDLER" == "e" ]; then
            calculate_time "$VALUE" "1"
            ENDTIME=$CALCTIME
        elif [ "$HANDLER" == "delaudio" ]; then
            AUDIODELAY="$VALUE"
        elif [ "$HANDLER" == "delvideo" ]; then
            VIDEODELAY="$VALUE"
        elif [ "$HANDLER" == "language" ] || [ "$HANDLER" == "" ]; then
            LANGUAGE="$VALUE"
        elif [ "$HANDLER" == "videotrack" ] || [ "$HANDLER" == "vt" ]; then
            VIDEOTRACK="$VALUE"
        elif [ "$HANDLER" == "audiotrack" ] || [ "$HANDLER" == "at" ]; then
            AUDIOTRACK="$VALUE"
        elif [ "$HANDLER" == "Position" ] || [ "$HANDLER" == "P" ]; then
            START_POSITION="$VALUE"
        elif [ "$HANDLER" == "End" ] || [ "$HANDLER" == "E" ]; then
            END_POSITION="$VALUE"
        elif [ "$HANDLER" == "duration" ] || [ "$HANDLER" == "d" ]; then
            calculate_time "$VALUE"
            DURATION_TIME=$CALCTIME
        elif [ "$HANDLER" == "target" ] || [ "$HANDLER" == "t" ]; then
            CONV_TYPE=".$VALUE"
            CONV_CHECK="$VALUE"
        elif [ "$HANDLER" == "Audio" ] || [ "$HANDLER" == "A" ]; then
            AUDIO_PACK=1
            CONV_TYPE=".$VALUE"
            CONV_CHECK="$VALUE"
        elif [ "$HANDLER" == "Combine" ] || [ "$HANDLER" == "C" ]; then
            SPLIT_AND_COMBINE=1
            new_massive_file_split "$VALUE"
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
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ -n "$1" ]; then
        WIDTH=$(echo "$1" | cut -d x -f 1)
        if [ "$WIDTH" -lt "640" ]; then
            echo "$WIDTH way too small width to be used! Aborting! 640x is minimum!"
            exit 1
        fi
        #HEIGHT=$(echo "$1" | cut -d x -f 2)
        COPY_ONLY=0
        DIMENSION_PARSED=1
    fi
}

#**************************************************************************************************************
# Parse file information
#***************************************************************************************************************
parse_file () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ -n "$1" ]; then
        CONTINUE_PROCESS=1
        FILE="$1"

        filename="${FILE%.*}"
        [ -f "${filename}.mp4" ] && FILE="${filename}.mp4"

        if [ ! -f "$FILE" ]; then
            shopt -s nocaseglob
            FILECOUNT=$(ls -l *"$FILE" 2>/dev/null | grep -v ^l | wc -l)
            [ "$FILECOUNT" == 0 ] && MULTIFILECOUNT=$(ls -l *"$FILE"* 2>/dev/null | grep -v ^l | wc -l)
            shopt -u nocaseglob
        fi
    fi
}

#***************************************************************************************************************
# Parse input data from given commandline inputs
#***************************************************************************************************************
parse_data () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ -n "$1" ]; then
        if [ "$CHECKRUN" == 0 ]; then
            parse_file "$1"
        else
            xss=0
            if [ "$DIMENSION_PARSED" -eq "0" ]; then
                re='^[0-9x]+$'
                [[ "$1" =~ $re ]] && xss=$(grep -o "x" <<< "$1" | wc -l)
            fi

            if [ "$xss" == "0" ] || [[ "$1" =~ "=" ]]; then
                xss=$(grep -o "=" <<< "$1" | wc -l)
                if [ "$xss" == "0" ]; then parse_handlers "$1"
                else                       parse_values "$1"; fi
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
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ -f "$FILE" ]; then
        X=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        if [ -n "$X" ]; then
            if [ "$PRINT_INFO" == "2" ] && [ "$WIDTH" -le "$X" ]; then   return 0
            elif [ "$PRINT_INFO" == "3" ] && [ "$WIDTH" -ge "$X" ]; then return 0
            elif [ "$PRINT_INFO" == "4" ] && [ "$WIDTH" == "$X" ]; then  echo "$PACKSIZE -- $X" && return 0; fi

            Y=$(mediainfo '--Inform=Video;%Height%' "$FILE")
            LEN=$(mediainfo '--Inform=Video;%Duration%' "$FILE")
            LEN=${LEN%.*}
            LEN=$((LEN / 1000))
            calculate_time_taken
            calculate_time_given "$LEN"

            TIMESAVED=$((TIMESAVED + LEN))
            SIZE=$(du -k "$FILE" | cut -f1)
            TOTALSAVE=$((TOTALSAVE + SIZE))

            print_info
            if [ "$FILECOUNT" -gt 1 ] || [ "$MULTIFILECOUNT" -gt 1 ]; then printf ":: "; fi
            short_name
            check_valuetype "${SIZE}"
            printf "${FILECOUNTPRINTER}${FILEprint} X:%04d Y:%04d Size:%-6.6s ${SIZETYPE} Lenght:${TIMER_SECOND_PRINT}\n" "${X}" "${Y}" "${SAVESIZE}"
            [ -n "$WRITEOUT" ] && echo "packAll.sh \"$FILE\" " >> "$WRITEOUT"
        else
            echo "$FILE is corrupted"
        fi
    fi
}

#***************************************************************************************************************
# Print multiple file handling information
#***************************************************************************************************************
print_info () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ "$FILECOUNT" -gt 1 ]; then
        STROUT_P="%0${#FILECOUNT}d"
        printf "${STROUT_P}/${STROUT_P} " "$CURRENTFILECOUNTER" "$FILECOUNT"
    elif [ "$MULTIFILECOUNT" -gt 1 ]; then
        STROUT_P="%0${#MULTIFILECOUNT}d"
        printf "${STROUT_P}/${STROUT_P} " "$CURRENTFILECOUNTER" "$MULTIFILECOUNT"
    fi
}

#***************************************************************************************************************
# Calculate time from current time data for one process and total
#***************************************************************************************************************
calculate_duration () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    TIMERR=$(date +%s)
    processing_time=$((TIMERR - process_start_time))
    TIMERVALUE=$(date -d@${processing_time} -u +%T)
}

#***************************************************************************************************************
# Cut filename shorter if it's too long, or fill with empty to match length
# 1 - filename max length
#***************************************************************************************************************
short_name () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    NAMENOEXT="${FILE%.*}"
    FILEprint=$(printf "%-35s %-5s" "${NAMENOEXT:0:35}" "${EXT_CURR:0:3}")
}

#***************************************************************************************************************
# Setup file packing variables
# TODO: add all other variations, like mp3 stripping
#***************************************************************************************************************
setup_file_packing () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    COMMAND_LINE=""

    if [ "$WORKMODE" == "1" ] || [ "$WORKMODE" == "3" ]; then COMMAND_LINE+="-ss $BEGTIME "; fi

    if [ "$WORKMODE" == "2" ] || [ "$WORKMODE" == "3" ]; then
        ENDO=$((DUR - ENDTIME - BEGTIME))
        COMMAND_LINE+="-t $ENDO "
    fi

    AUDIOSTUFF=$((MP3OUT + AUDIO_PACK + WAV_OUT))

    #if [ -n "$SUBFILE" ]; then
    #    re='^[0-9]+$'
    #    if [[ $SUBFILE =~ $re ]]; then
    #        get_sub_info "$FILE" "$SUBFILE" "1"
    #        [ "$SUBERR" == "0" ] && COMMAND_LINE+="subtitles='$FILE':stream_index=$SUBFILE "
    #    elif [ -f "$SUBFILE" ]; then
    #        COMMAND_LINE="subtitles='$SUBFILE' "
    #    fi
    #fi

    if [ "$HEVC_CONV" == "0" ]; then
        if [ "$AUDIOSTUFF" -gt "0" ]; then
            if [ "$CONV_CHECK" == "wav" ]; then COMMAND_LINE+="-vn -acodec pcm_s16le -ar 44100 -ac 2 "
            else                                COMMAND_LINE+="-acodec libmp3lame "; fi
        elif [ "$COPY_ONLY" == "0" ]; then      COMMAND_LINE+="-map 0 -map_metadata 0:s:0 -strict experimental -s $PACKSIZE "
        else                                    COMMAND_LINE+="-map 0 -map_metadata 0:s:0 -c copy "; fi

    elif [ "$AUDIOSTUFF" -gt "0" ]; then
        if [ "$CONV_CHECK" == "wav" ]; then COMMAND_LINE+="-vn -acodec pcm_s16le -ar 44100 -ac 2 "
        elif [ "$AUDIO_PACK" == "1" ]; then COMMAND_LINE+="-codec:a libmp3lame -q:a 0 -v error "
        else                                COMMAND_LINE+="-q:a 0 -map a "; fi

    elif [ -n "$AUDIODELAY" ]; then    COMMAND_LINE+="-itsoffset $AUDIODELAY -c:a copy -c:v copy -map 0:a:0 -map 1:v:0 "
    elif [ -n "$VIDEODELAY" ]; then    COMMAND_LINE+="-itsoffset $VIDEODELAY -c:v copy -c:a copy -map 0:v:0 -map 1:a:0 "
    elif [ "$COPY_ONLY" == "0" ]; then COMMAND_LINE+="-bsf:v h264_mp4toannexb -vf scale=$PACKSIZE -sn -vcodec libx264 -codec:a libmp3lame -q:a 0 -v error "
    else                               COMMAND_LINE+="-c:v:1 copy "; fi # -c:a copy "
    #else                               COMMAND_LINE+="-bsf:v h264_mp4toannexb -sn -vcodec libx264 -codec:a libmp3lame -q:a 0 -v error "; fi #-c:v:1 copy "; fi # -c:a copy "

    if [ -z "$AUDIODELAY" ] && [ -z "$VIDEODELAY" ]; then
        if [ -n "$AUDIOTRACK" ]; then
            IFS=':' read -r -a audio_array <<< "$AUDIOTRACK"
            for audio in "${audio_array[@]}"; do
                COMMAND_LINE+="-map 0:a:$audio "
            done
        fi

        if [ -n "$VIDEOTRACK" ] && [ "$AUDIOSTUFF" -eq "0" ]; then
            IFS=':' read -r -a video_array <<< "$AUDIOTRACK"
            for video in "${video_array[@]}"; do
                COMMAND_LINE+="-map 0:v:$video "
            done
        fi
    fi

    COMMAND_LINE+="-metadata title= "

    APP_SETUP=1
}

#***************************************************************************************************************
# Find correct mapping positions for video on audio, if no streams have been set
#***************************************************************************************************************
setup_add_packing () {
    COMMAND_ADD=""
    if [ "$AUDIOSTUFF" -eq "0" ]; then
        if [ -z "$VIDEOTRACK" ]; then
            VIDEOID=$(mediainfo '--Inform=Video;%ID%' "$FILE")
            VIDEOID=$((VIDEOID - 1))
            [ "$VIDEOID" -ge "0" ] && COMMAND_ADD+="-map 0:$VIDEOID "
        fi

        if [ -z "$AUDIOTRACK" ]; then
            AUDIO_OPTIONS=$(mediainfo '--Inform=Audio;%Language%' "$FILE")

            if [ -z "$AUDIO_OPTION" ]; then
                [ "$COPY_ONLY" == "1" ] && COMMAND_ADD="-map 0 "
            else
                AUDIOID=1
                AUDIOFOUND=0

                while [ -n "${#AUDIO_OPTIONS}" ]; do
                    [ "${#AUDIO_OPTIONS}" -lt 2 ] && break
                    [ "${AUDIO_OPTIONS:0:2}" == "$LANGUAGE" ] && AUDIOFOUND=1 && break
                    AUDIO_OPTIONS="${AUDIO_OPTIONS:2}"
                    AUDIOID=$((AUDIOID + 1))
                done

                [ "$AUDIOFOUND" -eq "1" ] && [ "$VIDEOID" -ge "0" ] && [ "$AUDIOID" -ge "0" ] && COMMAND_ADD+="-map 0:$AUDIOID "
                [ "$AUDIOFOUND" -eq "0" ] && [ "$VIDEOID" -ge "0" ] && COMMAND_ADD+="-map 0:1 "
            fi
        fi
    fi
}

#***************************************************************************************************************
# Pack file by using enviromental variables
#***************************************************************************************************************
simply_pack_file () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    [ "$APP_SETUP" == "0" ] && setup_file_packing
    setup_add_packing

    short_name
    process_start_time=$(date +%s)
    PROCESS_NOW=$(date +%T)

    [ "$DURATION_TIME" -gt 0 ] && ENDTIME=$((ORIGINAL_DURATION - DURATION_TIME))
    [ "$MASSIVE_SPLIT" == 1 ] && [ "$NO_EXIT_EXTERNAL" == "1" ] && [ "$MASSIVE_COUNTER" -gt "0" ] && printf "           "

    PRINTLINE="$PROCESS_NOW : $FILEprint $APP_NAME"
    [ "$EXIT_REPEAT" == "2" ] && PRINTLINE+=" retrying"

    if   [ "$AUDIO_PACK" == "1" ]; then printf "$PRINTLINE packing $EXT_CURR to $CONV_CHECK "
    elif [ "$MP3OUT" == 1 ]; then       printf "$PRINTLINE extracting $CONV_CHECK "
    elif [ "$COPY_ONLY" == "0" ]; then  printf "$PRINTLINE packing (%04dx%04d -> $PACKSIZE) " "${X}" "${Y}"
    else                                printf "$PRINTLINE copying (%04dx%04d) " "${X}" "${Y}"; fi

    if [ "$AUDIO_PACK" == "1" ]; then
        ORIGINAL_DURATION=$(mediainfo '--Inform=Audio;%Duration%' "$FILE")
        calculate_time_given $((ORIGINAL_DURATION / 1000))
        printf " duration:%-6.6s " "$TIMER_SECOND_PRINT"
    elif [ "$MASSIVE_SPLIT" == 1 ]; then
        calculate_time_given $(((ORIGINAL_DURATION / 1000) - CUTTING_TIME))
        printf "splitting to %-6.6s (mode: $WORKMODE) " "$TIMER_SECOND_PRINT"
        MASSIVE_TIME_SAVE=$((MASSIVE_TIME_SAVE + ((ORIGINAL_DURATION / 1000) - CUTTING_TIME)))
    elif [ "$MP3OUT" == 1 ] && [ "$CUTTING_TIME" -gt 0 ]; then
        calculate_time_given $(((ORIGINAL_DURATION / 1000) - CUTTING_TIME))
        printf "%-6.6s (mode: $WORKMODE) " "$TIMER_SECOND_PRINT"
    elif [ "$CUTTING_TIME" -gt 0 ]; then
        calculate_time_given "$CUTTING_TIME"
        printf "shortened by %-6.6s (mode: $WORKMODE) " "$TIMER_SECOND_PRINT"
    fi

    if [ -n "$SUBFILE" ] && [ "$SUBERR" = "0" ]; then
        if [ -n "$SUBLANG" ]; then
            printf "Sub:$SUBLANG "
        elif [ -f "$SUBFILE" ]; then
            printf "Sub:${SUBFILE:0:10}"
        fi
    fi

    ERROR=0
    $APP_NAME -i "$FILE" $COMMAND_LINE $COMMAND_ADD "${FILE}${CONV_TYPE}" -v quiet >/dev/null 2>&1
    ERROR=$?
}

#***************************************************************************************************************
# Read subtitle language from embedded video
# 1 - filename
# 2 - Subtitle track ID
# 3 - If set, will not print successfully read info
#***************************************************************************************************************
get_sub_info () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    SUBERR=0
    SUBDATA=$(mediainfo "$1")
    SUBVAL="$2"
    SUBVAL=$((SUBVAL + 1))
    SINGLESUB=$(echo "$SUBDATA" |grep -e "Text #$SUBVAL" -m 1 -A 12)
    [ -z "$SINGLESUB" ] && SINGLESUB=$(echo "$SUBDATA" |grep -e "Text" -m 1 -A 12)
    SUBLANG=$(echo "$SINGLESUB" |grep -e "Language")
    SUBLANG="${SUBLANG##*: }"
    SUBTITLE=$(echo "$SINGLESUB" |grep -e "Title")
    SUBTITLE="${SUBTITLE##*: }"

    if [ -z "$SUBLANG" ]; then printf "${Red}language not found for index '$2' ${Color_Off}\n" && SUBERR=1;
    elif [ "$SUBLANG" != "English" ]; then
        printf "\n    Read language is not english? Proceed with '$SUBLANG' (y/n)?"
        read -rsn1 -t 1 sinput
        [ "$sinput" != "y" ] && printf "Aborting burning\n" && SUBERR=1
    elif [ -z "$3" ]; then printf "Language:$SUBLANG " && [ -n "$SUBTITLE" ] && printf "Title:'$SUBTITLE' "; fi
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"
}

#***************************************************************************************************************
# Burn subtitle file to a given video file
# 1 - Video file
# 2 - Subtitle file
#***************************************************************************************************************
burn_subs () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ "$SPLIT_AND_COMBINE" -eq "1" ] && [[ ! "$APP_NAME" =~ "ffmpeg" ]]; then
        printf "${Red}Cannot burn subs with ${Yellow}$APP_NAME${Red} Aborting!${Color_Off}\n"
        exit 1
    fi

    MKVSUB=""
    RETVAL=1
    TYPECHANGE=""
    SUB="$2"

    re='^[0-9]+$'
    [[ $SUB =~ $re ]] && MKVSUB="$SUB" && SUB="$1"

    if [ -f "$1" ]; then
        if [ -f "$SUB" ]; then
            short_name

            printf "$(date +%T) '${1:0:40}' burning subs "
            [ -n "$MKVSUB" ] && get_sub_info "$SUB" "$MKVSUB"
            ERROR=0
            [ "$SINGULAR" == "0" ] && NEWNAME=""
            [ -z "$NEWNAME" ] && NEWNAME="Subbed_$1"
            [[ ! "$NEWNAME" =~ "${CONV_TYPE}" ]] && NEWNAME="${NEWNAME}.${CONV_TYPE}" && TYPECHANGE="${1%.*}"

            if [ "$SUBERR" == "0" ]; then
                if [ -n "$MKVSUB" ]; then
                    $APP_NAME -i "$1" -vf "subtitles='$SUB':stream_index=$MKVSUB" "${TARGET_DIR}/${NEWNAME}" -v quiet >/dev/null 2>&1
                else
                    $APP_NAME -i "$1" -vf subtitles="$SUB" "${TARGET_DIR}/${NEWNAME}" -v quiet >/dev/null 2>&1
                fi
                ERROR=$?
                calculate_time_taken

                ORGSIZE=$(du -k "$1" | cut -f1)
                SUBSIZE=0
                [ -z "$MKVSUB" ] && SUBSIZE=$(du -k "$SUB" | cut -f1)
                NEWSIZE=$(du -k "${TARGET_DIR}/${NEWNAME}" | cut -f1)
                NEWSIZE=$((ORGSIZE + SUBSIZE - NEWSIZE))
                TOTALSAVE=$((TOTALSAVE + NEWSIZE))
                NEWSIZE=$((NEWSIZE / 1000))

                if [ "$ERROR" -eq "0" ]; then
                    RETVAL=0
                    printf "${Green}Success${Color_Off} "
                    if [ "$KEEPORG" == "0" ]; then
                        rm "$1"
                        [ -f "$SUB" ] && rm "$SUB"
                        if [[ "$NEWNAME" =~ "Subbed_" ]]; then
                            if [ -z "$TYPECHANGE" ]; then mv "${TARGET_DIR}/${NEWNAME}" "${TARGET_DIR}/${1}" && printf " -> '${1:0:40}' "
                            else mv "${TARGET_DIR}/${NEWNAME}" "${TARGET_DIR}/${TYPECHANGE}${CONV_TYPE}" && printf " -> '${TYPECHANGE:0:36}${CONV_TYPE}' " ; fi
                        fi
                    fi
                    printf "${Color_Off} saved ${NEWSIZE}Mb in $TIMER_TOTAL_PRINT"
                    SUCCESFULFILECNT=$((SUCCESFULFILECNT + 1))
                else printf "${Red}Failed${Color_Off}" && rm "${TARGET_DIR}/${NEWNAME}"; fi
                printf "${Color_Off}\n"
            fi
        else
            printf "${Red}Subfile $SUB not found!${Color_Off}\n"
        fi
    else
        printf "${Red}File $1 not found!${Color_Off}\n"
    fi

    ERROR=$RETVAL
    [ "$SINGULAR" == "1" ] && exit $RETVAL
}

#***************************************************************************************************************
# Make a filename with incrementing value
#***************************************************************************************************************
RUNNING_FILENAME=""

make_running_name () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    ExtLen=${#EXT_CURR}
    NameLen=${#FILE}
    LEN_NO_EXT=$((NameLen - ExtLen - 1))

    if [ -z "$NEWNAME" ]; then RUNNING_FILENAME=${FILE:0:$LEN_NO_EXT}
    else                       RUNNING_FILENAME=$NEWNAME; fi

    if [ "$RUNNING_FILE_NUMBER" -lt "10" ]; then RUNNING_FILENAME+="_0$RUNNING_FILE_NUMBER$CONV_TYPE"
    else                                         RUNNING_FILENAME+="_$RUNNING_FILE_NUMBER$CONV_TYPE"; fi
}

#***************************************************************************************************************
# When keeping an original file, make the extracted piece it's own unique number, so many parts can be extracted
#***************************************************************************************************************
move_to_a_running_file () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    RUNNING_FILE_NUMBER=1
    make_running_name

    if [ -f "${TARGET_DIR}/$RUNNING_FILENAME" ]; then
        while true; do
            RUNNING_FILE_NUMBER=$((RUNNING_FILE_NUMBER + 1))
            make_running_name
            [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ] && break
        done
    fi

    mv "$FILE$CONV_TYPE" "${TARGET_DIR}/${RUNNING_FILENAME}"
}

#***************************************************************************************************************
# Rename output file to correct format or move unsuccesful file to other directory
# 1 - If bigger than zero, check one file, if 0, process failed and remove target files
#***************************************************************************************************************
handle_file_rename () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ "$1" -gt 0 ] && [ "$ERROR" -eq 0 ] ; then
        [ "$KEEPORG" == "0" ] && delete_file "$FILE"

        if [ "$KEEPORG" == "0" ]; then
            if [ "$EXT_CURR" == "$CONV_CHECK" ]; then
                if [ -z "$NEWNAME" ]; then mv "$FILE$CONV_TYPE" "${TARGET_DIR}/${FILE}"
                else                       mv "$FILE$CONV_TYPE" "${TARGET_DIR}/$NEWNAME$CONV_TYPE"; fi

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
    else
        calculate_duration
        [ "$ERROR" -ne "0" ] && printf "${Red}Something went wrong, keeping original!${Color_Off} in $TIMERVALUE\n"

        delete_file "$FILE$CONV_TYPE"

        if [ "$EXT_CURR" == "$CONV_CHECK" ] && [ "$COPY_ONLY" == "0" ]; then
            [ ! -d "./Failed" ] && mkdir "Failed"
            RETVAL=1
            mv "$FILE" "./Failed"
        fi

        [ "$EXIT_VALUE" == "1" ] && exit 1
    fi
}

#***************************************************************************************************************
# Calculate dimension ratio change
#***************************************************************************************************************
calculate_packsize () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"
    [ "$AUDIO_PACK" == 1 ] && return

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
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    [ ! -d "./Error" ] && mkdir "Error"

    mv "$FILE" "./Error"
    calculate_duration
    printf "${Red}Something corrupted with $FILE${Color_Off} in $TIMERVALUE\n"

    [ "$EXIT_VALUE" == "1" ] && exit 1
    RETVAL=1
}

#***************************************************************************************************************
# Check if file was a filetype conversion, and accept the bigger filesize in that case
#***************************************************************************************************************
check_alternative_conversion () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    xNEW_DURATION=$((NEW_DURATION / 1000))
    xORIGINAL_DURATION=$((ORIGINAL_DURATION / 1000))
    xNEW_FILESIZE=$((NEW_FILESIZE / 1000))
    xORIGINAL_SIZE=$((ORIGINAL_SIZE / 1000))
    PRINT_ERROR_DATA=""

    if [ "$COPY_ONLY" != 0 ]; then
        DURATION_CHECK=$((DURATION_CHECK - 2000))
        if [ "$NEW_DURATION" -gt "$DURATION_CHECK" ]; then
            handle_file_rename 1
            check_valuetype "$(((ORIGINAL_SIZE - NEW_FILESIZE)))"
            printf "| Converted. $((ORIGINAL_DURATION - NEW_DURATION))sec and ${SAVESIZE} ${SIZETYPE} in $TIMERVALUE"
            SUCCESFULFILECNT=$((SUCCESFULFILECNT + 1))
            TIMESAVED=$((TIMESAVED + DURATION_CUT))
        else
            PRINT_ERROR_DATA="Duration failed ($NEW_DURATION>$DURATION_CHECK)"
        fi
    elif [ "$EXT_CURR" == "$CONV_CHECK" ]; then
        RETVAL=1
        ERROR_WHILE_MORPH=1
        PRINT_ERROR_DATA="Conversion check (${EXT_CURR}=${CONV_CHECK})"
    else
        RETVAL=1
        ERROR_WHILE_MORPH=1
        PRINT_ERROR_DATA="Unknown"
    fi

    if [ -n "$PRINT_ERROR_DATA" ]; then
        calculate_duration
        handle_file_rename 0
        printf "${Red} FAILED!"
        [ "$xNEW_DURATION" -gt "$xORIGINAL_DURATION" ] && printf " time:$xNEW_DURATION>$xORIGINAL_DURATION" && PRINT_ERROR_DATA=""
        [ "$xNEW_FILESIZE" -gt "$xORIGINAL_SIZE" ] &&  printf " size:$xNEW_FILESIZE>$xORIGINAL_SIZE" && PRINT_ERROR_DATA=""
        [ -n "$PRINT_ERROR_DATA" ] && printf " Reason:$PRINT_ERROR_DATA"
        printf " in $TIMERVALUE"
        TOTAL_ERR_CNT=$((TOTAL_ERR_CNT + 1))
        SPLITTING_ERROR=1
        [ "$EXIT_REPEAT" -gt "0" ] && EXIT_REPEAT=$((EXIT_REPEAT + 1))
    fi

    printf "${Color_Off}\n"

    [ "$TOTAL_ERR_CNT" -gt "3" ] && [ "$EXIT_CONTINUE" == "0" ] && printf "\nToo many errors ($TOTAL_ERR_CNT), aborting!\n" && exit 1
}

#***************************************************************************************************************
# Verify if that file does indeed exist
#***************************************************************************************************************
check_if_files_exist () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    FILE_EXISTS=0
    if [ "$MASSIVE_SPLIT" == 1 ]; then  FILE_EXISTS=1
    elif [ -f "$FILE$CONV_TYPE" ]; then FILE_EXISTS=1; fi
}

#***************************************************************************************************************
# Check file handling, if size is smaller and destination file length is the same (with 2sec error marginal)
#***************************************************************************************************************
check_file_conversion () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    #if destination file exists
    check_if_files_exist
    if [ "$FILE_EXISTS" == 1 ]; then
        if [ "$AUDIO_PACK" == "1" ]; then NEW_DURATION=$(mediainfo '--Inform=Audio;%Duration%' "$FILE$CONV_TYPE")
        else                              NEW_DURATION=$(mediainfo '--Inform=Video;%Duration%' "$FILE$CONV_TYPE"); fi

        NEW_FILESIZE=$(du -k "$FILE$CONV_TYPE" | cut -f1)
        DURATION_CUT=$(((BEGTIME + ENDTIME) * 1000))

        [ "$MASSIVE_SPLIT" == "0" ] && GLOBAL_TIMESAVE=$((GLOBAL_TIMESAVE + CUTTING_TIME))

        DURATION_CHECK=$((ORIGINAL_DURATION - DURATION_CUT - 2000))
        ORIGINAL_SIZE=$(du -k "$FILE" | cut -f1)
        ORIGINAL_HOLDER=$ORIGINAL_SIZE

        [ -z "$NEW_DURATION" ] && NEW_DURATION=0
        [ "$IGNORE" == "1" ] && ORIGINAL_SIZE=$((NEW_FILESIZE + 10000))

        #if video length matches (with one second error tolerance) and destination file is smaller than original, then
        if [ "$NEW_DURATION" -gt "$DURATION_CHECK" ] && [ "$ORIGINAL_SIZE" -gt "$NEW_FILESIZE" ]; then
            ORIGINAL_SIZE=$ORIGINAL_HOLDER
            ENDSIZE=$((ORIGINAL_SIZE - NEW_FILESIZE))
            TOTALSAVE=$((TOTALSAVE + ENDSIZE))
            SUCCESFULFILECNT=$((SUCCESFULFILECNT + 1))
            [ "$MASSIVE_FILE_HANDLE" -le "1" ] && GLOBAL_FILECOUNT=$((GLOBAL_FILECOUNT + 1))
            [ "$MASSIVE_FILE_HANDLE" -eq "1" ] && MASSIVE_FILE_HANDLE=2
            #ENDSIZE=$((ENDSIZE / 1000))
            TIMESAVED=$((TIMESAVED + DURATION_CUT))

            if [ "$MASSIVE_SPLIT" == 1 ]; then
                printf "${Green} Success in $TIMERVALUE${Color_Off} "
            else
                check_valuetype "$ENDSIZE"
                printf "${Green} Success! Saved %-6.6s ${SIZETYPE} in $TIMERVALUE${Color_Off}\n" "$SAVESIZE"
            fi
            handle_file_rename 1
        else
            check_alternative_conversion
        fi
    else
        calculate_duration
        printf "${Red} No destination file!${Color_Off} in $TIMERVALUE\n"
        [ ! -d "./Nodest" ] && mkdir "Nodest"
        mv "$FILE" "./Nodest"
        remove_interrupted_files
        RETVAL=1
        [ "$EXIT_VALUE" == "1" ] && exit 1
    fi
}

#***************************************************************************************************************
# Check what kind of file handling will be accessed
#***************************************************************************************************************
handle_file_packing () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"
    [ ! -f "$FILE" ] && return

    ORIGINAL_SIZE=$(du -k "$FILE" | cut -f1)
    get_space_left

    if [ "$ORIGINAL_SIZE" -gt "$SPACELEFT" ] && [ "$IGNORE_SPACE_SIZE" -eq "0" ]; then
        echo "Not enough space left! File:$ORIGINAL_SIZE > harddrive:$SPACELEFT"
        [ "$IGNORE_SPACE" -eq "0" ] && [ "$NO_EXIT_EXTERNAL" == "0" ] && exit 1
        EXIT_EXT_VAL=1
        return
    fi

    Y=$(mediainfo '--Inform=Video;%Height%' "$FILE")
    CUTTING_TIME=$((BEGTIME + ENDTIME + DURATION_TIME))

    ORIGINAL_DURATION=$(mediainfo '--Inform=Video;%Duration%' "$FILE")
    [[ "$ORIGINAL_DURATION" = *"."* ]] && ORIGINAL_DURATION=$(grep -o "." <<< "$FILE" | wc -l)
    DUR=$((ORIGINAL_DURATION / 1000))

    [ "$CROP" == 0 ] && print_info
    XP=$(mediainfo '--Inform=Video;%Width%' "$FILE")

    if [ "$REPACK" == 1 ] && [ "$DIMENSION_PARSED" == 0 ]; then
        if [ "$HEVC_CONV" == 1 ]; then PACKSIZE="${XP}:${Y}"
        else                           PACKSIZE="${XP}x${Y}"; fi
        COPY_ONLY=0

    elif [ "$REPACK" == 1 ] && [ "$XP" -le "$WIDTH" ]; then
        if [ "$HEVC_CONV" == 1 ]; then PACKSIZE="${XP}:${Y}"
        else                           PACKSIZE="${XP}x${Y}"; fi
        COPY_ONLY=0

    else
        calculate_packsize
    fi

    if [ "$CROP" == 1 ]; then
        check_and_crop
    else
        simply_pack_file
        calculate_duration
        check_file_conversion
    fi
}

#***************************************************************************************************************
# Get space left on target directory
#***************************************************************************************************************
get_space_left () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    FULL=$(df -k "${TARGET_DIR}" |grep "/")

    IFS=" "
    space_array=(${FULL//,/$IFS})
    SPACELEFT=${space_array[3]}
}

#***************************************************************************************************************
# Main file handling function
#***************************************************************************************************************
pack_file () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    [ "$START_POSITION" -gt "$CURRENTFILECOUNTER" ] && return
    [ "$END_POSITION" -gt "0" ] && [ "$CURRENTFILECOUNTER" -ge "$END_POSITION" ] && return

    # if not SYS_INTERRUPTrupted and WORKMODE is for an existing dimensions
    X=$(mediainfo '--Inform=Video;%Width%' "$FILE")
    [ "$EXIT_REPEAT" -gt "0" ] && EXIT_REPEAT=1

    if [ "$PRINT_INFO" -gt 0 ]; then
        print_file_info
    else
        if [ ! -f "$FILE" ]; then
            MISSING=$((MISSING + 1))
            if [ "$PRINT_ALL" == 1 ]; then
                print_info
                echo "$FILE is not found!"
            fi
        elif [ "$AUDIO_PACK" == "1" ]; then
            handle_file_packing
            [ "$EXIT_REPEAT" == "2" ] && handle_file_packing
        elif [ -z "$X" ]; then
            handle_error_file
        elif [ "$WORKMODE" -gt 0 ] && [ "$X" -gt "$WIDTH" ]; then
            handle_file_packing
            [ "$EXIT_REPEAT" == "2" ] && handle_file_packing
        elif [ "$X" -le "$WIDTH" ]; then
            if [ ".$EXT_CURR" != "$CONV_TYPE" ] || [ "$REPACK" == 1 ]; then
                REPACK=1
                handle_file_packing
                [ "$EXIT_REPEAT" == "2" ] && handle_file_packing
                REPACK="$REPACK_GIVEN"
            elif [ "$PRINT_ALL" == 1 ]; then
                printf "${Yellow}$FILE cannot be packed $X <= $WIDTH${Color_Off}\n"
                RETVAL=1
            fi
        elif [ "$PRINT_ALL" == 1 ]; then
            print_info
            echo "$FILE width:$X skipping"
        fi
    fi
}

#***************************************************************************************************************
# Calculate time taken to process data
#***************************************************************************************************************
calculate_time_taken () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    JUST_NOW=$(date +%s)
    SCRIPT_TOTAL_TIME=$((JUST_NOW - script_start_time))

    if [ "$SCRIPT_TOTAL_TIME" -gt "86399" ]; then
        DAYS_TOTAL=0

        while [ "$SCRIPT_TOTAL_TIME" -gt "86399" ]; do
            DAYS_TOTAL=$((DAYS_TOTAL + 1))
            SCRIPT_TOTAL_TIME=$((SCRIPT_TOTAL_TIME - 86400))
        done

        TIMER_TOTAL_PRINT=$(date -d@${SCRIPT_TOTAL_TIME} -u +%T)
        TIMER_TOTAL_PRINT="${DAYS_TOTAL}:${TIMER_TOTAL_PRINT}"
    else
        TIMER_TOTAL_PRINT=$(date -d@${SCRIPT_TOTAL_TIME} -u +%T)
    fi
}

#***************************************************************************************************************
# Change given time in seconds to HH:MM:SS
# 1 - time in seconds
#***************************************************************************************************************
calculate_time_given () {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ -z "$1" ]; then
        TIMER_SECOND_PRINT="0"
    else
        VAL_HAND="$1"
        [ "$1" -lt "0" ] && VAL_HAND=$((VAL_HAND * -1))

        if [ "$VAL_HAND" -lt "60" ]; then     TIMER_SECOND_PRINT="$VAL_HAND"
        elif [ "$VAL_HAND" -lt "3600" ]; then TIMER_SECOND_PRINT=$(date -d@${VAL_HAND} -u +%M:%S)
        else                                  TIMER_SECOND_PRINT=$(date -d@${VAL_HAND} -u +%T); fi
    fi

}

#***************************************************************************************************************
# Verify that all necessary programs are installed
#***************************************************************************************************************
verify_necessary_programs() {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    ff_missing=0
    av_missing=0
    mi_missing=0
    ren_missing=0

    hash ffmpeg 2>/dev/null || ff_missing=$?
    hash avconv 2>/dev/null || av_missing=$?
    hash mediainfo 2>/dev/null || mi_missing=$?
    hash rename 2>/dev/null || ren_missing=$?

    error_code=$((ff_missing + mi_missing + ren_missing))
    [ "$av_missing" -ne 0 ] && HEVC_CONV=1

    if [ "$error_code" -ne 0 ]; then
        printf "Missing necessary programs: "
        [ "$ff_missing" -ne 0 ] && printf "ffmpeg "
        [ "$av_missing" -ne 0 ] && printf "avconv "
        [ "$mi_missing" -ne 0 ] && printf "mediainfo "
        [ "$ren_missing" -ne 0 ] && printf "rename "
        printf "\n"
        EXIT_EXT_VAL=1
        exit 1
    fi
}

#***************************************************************************************************************
# Check that at least one command was given, or print help
#***************************************************************************************************************
verify_commandline_input() {
    [ "$DEBUG_PRINT" == 1 ] && echo "${FUNCNAME[0]}"

    if [ "$#" -le 0 ]; then
        print_help
        EXIT_EXT_VAL=1
        exit 1
    fi
}

#***************************************************************************************************************
# The MAIN VOID function
#***************************************************************************************************************

verify_necessary_programs
verify_commandline_input "$@"

[ "$1" == "combine" ] && COMBINEFILE=1
[ "$1" == "merge" ] && COMBINEFILE=2
[ "$1" == "append" ] && COMBINEFILE=3

for var in "$@"; do
    if [ "$COMBINEFILE" == "1" ]; then
        [ "$var" != "combine" ] && COMBINELIST+=("$var")
    elif [ "$COMBINEFILE" == "2" ]; then
        [ "$var" != "merge" ] && COMBINELIST+=("$var")
    elif [ "$COMBINEFILE" == "3" ]; then
        [ "$var" != "append" ] && COMBINELIST+=("$var")
    else
        parse_data "$var"
        CHECKRUN=$((CHECKRUN + 1))
    fi
done

if [ "$COMBINEFILE" == "1" ]; then
    combineFiles

elif [ "$COMBINEFILE" == "2" ]; then
    mergeFiles

elif [ "$COMBINEFILE" == "3" ]; then
    mergeFiles "append"

elif [ "$CHECKRUN" == "0" ]; then
    print_help
    RETVAL=1

elif [ "$CONTINUE_PROCESS" == "1" ]; then
    if [ -n "$SUBFILE" ]; then
        SINGULAR=1
        if [ -f "$FILE" ]; then
            burn_subs "$FILE" "$SUBFILE"
        elif [ "$FILECOUNT" -gt 0 ] || [ "$MULTIFILECOUNT" -gt 0 ]; then
            SINGULAR=0
            shopt -s nocaseglob
            for f in *"$FILE"*; do
                if [ -f "$f" ]; then
                    EXT_CURR="${FILE##*.}"
                    CURRENTFILECOUNTER=$((CURRENTFILECOUNTER + 1))
                    print_info
                    burn_subs "$f" "$SUBFILE"
                fi
            done
            shopt -u nocaseglob
        else
            printf "${Red}File(s) '$1' not found!${Color_Off}\n"
            RETVAL=2
        fi

    elif [ -f "$FILE" ]; then
        FILECOUNT=1
        EXT_CURR="${FILE##*.}"
        pack_file

    elif [ "$FILECOUNT" -gt 0 ]; then
        EXT_CURR="$FILE"
        shopt -s nocaseglob
        for f in *".$EXT_CURR"; do
            FILE="$f"
            CURRENTFILECOUNTER=$((CURRENTFILECOUNTER + 1))
            pack_file
        done
        shopt -u nocaseglob

    elif [ "$MULTIFILECOUNT" -gt 0 ]; then
        shopt -s nocaseglob
        for f in *"$FILE"*; do
            if [ -f "$f" ]; then
                FILE="$f"
                EXT_CURR="${FILE##*.}"
                CURRENTFILECOUNTER=$((CURRENTFILECOUNTER + 1))
                pack_file
            fi
        done
        shopt -u nocaseglob

    else
        printf "${Red}File(s) '$1' not found!${Color_Off}\n"
        RETVAL=2
    fi

    if [ "$CURRENTFILECOUNTER" -gt "1" ]; then print_total
    else GLOBAL_FILESAVE=$((GLOBAL_FILESAVE + TOTALSAVE)); fi
fi

[ "$MASSIVE_TIME_SAVE" -gt "0" ] && GLOBAL_TIMESAVE=$((GLOBAL_TIMESAVE + (ORIGINAL_DURATION / 1000) - MASSIVE_TIME_SAVE))

[ "$NO_EXIT_EXTERNAL" == "0" ] && exit "$RETVAL"
