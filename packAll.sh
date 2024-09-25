#!/bin/bash

HEVC_CONV=1                     # Use ffmpeg instead of avconv to handle files
SCRUB=0                         # Instead of rm, use scrub, if this is set

WORKMODE=4                      # Workmode handler (which part is to be split)
TOTALSAVE=0

FILECOUNT=0                     # Number of files to be handled
MULTIFILECOUNT=0                # Number of files one video was split into
MISSING=0                       # File existance checker
SUCCESFULFILECNT=0              # Number of successfully handled files

EXT_CURR=""                     # Current files extension
CONV_TYPE=".mp4"                # Target filetype
CONV_CHECK="mp4"                # Target filetype extension handler
MP3OUT=0                        # Extract mp3 data, if set
AUDIO_PACK=0                    # Pack input file into target audio
WAV_OUT=0                       # extract wav from video

CALCTIME=0                      # Global variable to handle calculated time in seconds
TIMERVALUE=0                    # Printed time value, which is calculated
IGNORE=0                        # Ignore bigger target file size
IGNORE_SPACE=0                  # Ignore space warning and proceed to next file
IGNORE_SPACE_SIZE=0             # Ignore too little space warning
TIMESAVED=0                     # Time cut out from modifying videos

CHECKRUN=0                      # Verificator of necessary inputs
CONTINUE_PROCESS=0              # If something went wrong, or file was split into multiple files, don't continue process

#HEIGHT=0                        # Height of the current video
DIMENSION_PARSED=0              # Handler to tell if the dimension was already parsed

KEEPORG=0                       # If set, will not delete original file after success

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
MASSIVE_FILE_HANDLE=0           # If set, will not raise the global filecount more than once

SUBERR=0                        # Subfile error checker
WRITEOUT=""                     # Target filename for file info printing

process_start_time=0            # Time in seconds, when processing started
script_start_time=$(date +%s)   # Time in seconds, when the script started running

RETVAL=0                        # If everything was done as expected, is set to 0

SPACELEFT=0                     # Target directory drive space left
SIZETYPE="Mb"                   # Saved size type
SAVESIZE=0                      # Calculated value of size saved

ERROR_WHILE_MORPH=0

APP_NAME=/usr/bin/ffmpeg        # current application file to be used
APP_STRING="ffmpeg"             # current application name
CURRENT_TIMESAVE=0              # Time saved during editing session
SPLITTER_TIMESAVE=0             # Time saved during splitting

COMBINELIST=()                  # combine file list
COMBINEFILE=0                   # variable for combining files handler
PACK_RUN=()                     # packing variables
CUT_RUN=()                      # Cutting variables
SUB_RUN=()                      # subtitle handling options
CROP_RUN=()                     # cropping handling options

SPLITTING_ERROR=0               # Is set when splitting fails
CMD_PRINT=""                    # If set, will print out commandline options
IGNORE_UNKNOWN=0                # Ignore unknown errors

AUDIODELAY=""                   # Delay audio by given value
VIDEODELAY=""                   # Delay video by given value
NOMAPPING=0                     # Don't map file
QUICK=0                         # Quickcopy handler
BUGME=0                         # Debug output commands

MAX_SHORT_TIME=""               # Maximum accepted time for shortening
TOTAL_ERR_CNT=0                 # Number of errors occured
ERROR_WHILE_SPLITTING=0         # Splitting error handler
export PROCESS_INTERRUPTED=0    # Interruption handler for external access
export ERROR=0                  # Global error indicator
filename=""                     # Current filename without extension
PRINTLINE=""                    # Status output string handler

PACKLOOP=0                      # Indicates how many times the file has been handled
PACKLEN=0                       # Length of packloop base printout
PACKFILE="/tmp/ffmpeg_out.txt"  # Temporary file to handle output for non-blocking run
CUTTING=0                       # If any cutting is being done, set this value

#***************************************************************************************************************
# Reset all runtime handlers
#***************************************************************************************************************
reset_handlers () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    REPACK=0                        # Repack file instead of changing dimensions
    REPACK_GIVEN=0                  # Repack value holder
    COPY_ONLY=1                     # Don't pack file, just copy data
    CROP=0                          # Crop video handler
    BEGTIME=0                       # Time where video should begin
    ENDTIME=0                       # Time where video ending is wanter
    LANGUAGE="en"                   # Wanted audiotrack language
    VIDEOTRACK=""                   # Videotrack number
    AUDIOTRACK=""                   # Audiotrack number
    END_POSITION=0                  # File where to no longer handle files
    DURATION_TIME=0                 # File time to be copied / used
    SPLIT_AND_COMBINE=0             # If set, will combine a new file from splitted files
    MASS_SPLIT=0                    # Mass split enabled handler
    SUBFILE=""                      # Path to subtitle file to be burned into target video
    NEWNAME=""                      # New target filename, if not set, will use input filename
    DELIMITER=""                    # Delimiter to split the filename into pieces with splitting function
    TARGET_DIR="."                  # Target directory for successful file
    WIDTH=0                         # Width of the video
    CURRENTFILECOUNTER=0            # Currently processed file number
    START_POSITION=0                # File to start handling from
    COMMAND_LINE=""                 # command line options to be set up later
    COMMAND_ADD=""                  # command line options, that will be set up each time
    VAL_HAND=0                      # Splitting timer value handler
}

# If this value is not set, external program is not accessing this and exit -function will be used normally
[ -z "$NO_EXIT_EXTERNAL" ] && NO_EXIT_EXTERNAL=0

#***************************************************************************************************************
# Define regular colors for printout
#***************************************************************************************************************
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'
Purple='\033[0;35m'
Color_Off='\033[0m'

#***************************************************************************************************************
# Change printout type to corrent
#***************************************************************************************************************
check_valuetype () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    GLOBAL_FILESAVE=$((GLOBAL_FILESAVE + TOTALSAVE))
    check_valuetype "$TOTALSAVE"
    #TOTALSAVE=$((TOTALSAVE / 1000))

    if [ "$PRINT_INFO" == 1 ]; then
        TIMESAVED=$(date -d@${TIMESAVED} -u +%T)
        printf "Total in $CURRENTFILECOUNTER files, Size:$SAVESIZE Length:$TIMESAVED\n"
    else
        if [ "$TIMESAVED" -gt "0" ]; then
            if [ "$MASSIVE_TIME_SAVE" -gt "0" ]; then TIMESAVED=$(((ORIGINAL_DURATION / 1000) - MASSIVE_TIME_SAVE))
            else                                      TIMESAVED=$((TIMESAVED  / 1000)); fi
            calculate_time_given "$TIMESAVED"
        fi
        calculate_time_taken

        if [ "$COPY_ONLY" == 0 ] || [ "$TIMESAVED" -gt "0" ]; then printf "Totally saved $SAVESIZE ${SIZETYPE} $TIMER_SECOND_PRINT on $SUCCESFULFILECNT files in $TIMER_TOTAL_PRINT\n"
        elif [ -n "$SUBFILE" ]; then                               printf "Burned subs to $SUCCESFULFILECNT files (size change: $SAVESIZE ${SIZETYPE}) in $TIMER_TOTAL_PRINT\n"
        else                                                       printf "Handled $SUCCESFULFILECNT files to $CONV_CHECK (size change: $SAVESIZE ${SIZETYPE}) in $TIMER_TOTAL_PRINT\n"; fi

        [ "$MISSING" -gt "0" ] && printf "Number of files disappeared during process: $MISSING\n" && RETVAL=17
    fi
}

#***************************************************************************************************************
# Remove incomplete destination files
#***************************************************************************************************************
remove_interrupted_files () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    [ -f "$FILE$CONV_TYPE" ]     && delete_file "$FILE$CONV_TYPE" "22"
    [ -f "$FILE"_1"$CONV_TYPE" ] && delete_file "$FILE"_1"$CONV_TYPE" "23"
    [ -f "$FILE"_2"$CONV_TYPE" ] && delete_file "$FILE"_2"$CONV_TYPE" "24"
    [ -f "$NEWNAME" ] && delete_file "$NEWNAME" "25"
}

#***************************************************************************************************************
#If SYS_INTERRUPTted, stop process, remove files not complete and print final situation
#***************************************************************************************************************
set_int () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    mapfile CHECKLIST <<<$(ps aux |grep $APP_STRING)
    [ "${#CHECKLIST[@]}" -gt "1" ] && killall $APP_STRING -s 9
    PROCESS_INTERRUPTED=1
    shopt -u nocaseglob
    calculate_duration
    printf "\n${Yellow}Main conversion interrupted in ${TIMERVALUE}!${Color_Off}\n"
    remove_interrupted_files
    remove_broken_split_files
    EXIT_EXT_VAL=1

    [ -f "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" ] && delete_file "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" "26"

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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    printf "No input file! first input is always 'combine/merge/append' or filename (filename, file type or part of filename)\n\n"
    printf "To set dimensions Nx (where N is width, height is automatically calculated to retain aspect ratio)\n\n"
    printf "b(eg)=       -    time to remove from beginning (either seconds or X:Y:Z)\n"
    printf "e(nd)=       -    time to remove from end (calculated from the end) (either seconds or X:Y:Z)\n"
    printf "d(uration)=  -    Time from the beginning X:Y:Z, to skip the end after that\n"
    printf "t(arget)=    -    filetype to set destination filetype (mp4 as default)\n\n"
    printf "i(gnore)     -    to ignore size (both too big, or too small)\n"
    printf "I(gnore)     -    to ignore space check exit (not the space check) and continue to next file\n"
    printf "F(orce)      -    to ignore space check and pack file instead\n"
    printf "r(epack)     -    to repack file with original dimensions (if target width has been given, will repack only videos smaller than new given size)\n"
    printf "k(eep)       -    to keep the original file after succesful conversion\n"
    printf "m(p3)        -    to extract mp3 from the file\n"
    printf "M(p3)        -    pack input audio file(s) into mp3 file\n"
    printf "w(av)=       -    extract wav from input file\n"
    printf "A(udio)=     -    convert audiofile to another audio filetype\n"
    printf "a(ll)        -    print all information\n"
    printf "p(rint)      -    print only file information (if set as 1, will print everything, 2 = lessthan, 3=biggerthan, 4=else )\n"
    printf "h(evc)       -    convert with avconv instead of ffmpeg\n"
    printf "s(crub)      -    original on completion\n"
    printf "crop         -    crop black borders (experimental atm, probably will cut too much of the area)\n\n"
    printf "sub=         -    subtitle file to be burned into video, or if the file itself has subtitles embedded, the number of the wanted subtitle track (starting from 0), or self:SUB_EXT\n"
    printf "w(rite)=     -    Write printing output to file\n"
    printf "n(ame)=      -    Give file a new target name (without file extension)\n"
    printf "N=           -    Split filename with delimiter when using c= -option\n"
    printf "T(arget)=    -    Target directory for the target file\n\n"
    printf "c(ut)=       -    time where to cut,time where to cut next piece,next piece,etc\n"
    printf "c(ut)=       -    time to begin - time to end,next time to begin-time to end,etc\n"
    printf "C(ombine)=   -    same as cutting with begin-end, but will combine split videos to one\n"
    printf "             -    When setting cut or Cut, adding D as the last point, will delete the original file if successful\n\n"
    printf "max=         -    Maximum removal time in seconds, verification for combine-functionality\n\n"
    printf "P(osition)   -    Start handling only from Nth file set in position. If not set, will handle all files\n"
    printf "E(nd)        -    Stop handling files after Nth position. If set as 0 (default) will run to the end\n\n"
    printf "combine      -    If given as a first input, all input after are read as files, and are combined into one file\n"
    printf "merge        -    If given as a first input, first file after is the video, and rest all audio files to be overwritten to the video\n"
    printf "append       -    If given as a first input, first file after is the video, and all the rest of the audio is added to the video as their own tracks\n"
    printf "             -    If any input is given as 'delete', deletes all sources, if combining/merge/append is successful\n\n"
    printf "repeat       -    repeat process on failed result\n"
    printf "continue     -    ignore too many errors\n"
    printf "quit         -    Exit after an error with exit code\n\n"
    printf "vt           -    Wanted videotrack from input file, if multiple, separate each with :\n"
    printf "at           -    Wanted audiotrack from input file, if multiple, separate each with :\n"
    printf "delaudio     -    Delay audio by given seconds\n"
    printf "delvideo     -    Delay video by given seconds\n"
    printf "quick        -    Quick copy handling instead of packing (warning, will probably cause syncinc problems with the video)\n"
    printf "command      -    Print out commandline options while processing\n"
    printf "ierr         -    Ignore unknown error and proceed\n"
    printf "l(anguage)   -    Wanted output audio language with two letters, default:en\n\n"
    printf "example:     ${0} \"FILENAME\" 640x c=0:11-1:23,1:0:3-1:6:13,D\n"
}

#*************************************************************************************************************
# Find image position in a video
# 1 - Video file
# 2 - Image file
# 3 - first or last
#**************************************************************************************************************
find_image_pos () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    [[ ! "$APP_STRING" =~ "ffmpeg" ]] && printf "Can't seek images without ffmpeg!\n" && exit 1
    [ "$DEBUG_PRINT" == 1 ] && printf "Seeking time from '$1' by '$2'\n"
    IMAGEPOS=$($APP_NAME -i "$1" -r 1 -loop 1 -i "$2" -an -filter_complex "blend=difference:shortest=1,blackframe=99:32,metadata=print:file=-" -f null -v quiet -)
    IMAGETIME=$(printf "$IMAGEPOS" |grep "blackframe" -m 1)
    if [ -z "$3" ]; then IMAGETIME="${IMAGEPOS#*pts_time:}"
    else IMAGETIME="${IMAGEPOS##*pts_time:}"; fi

    IMAGETIME="${IMAGETIME%%.*}"
    [ "$DEBUG_PRINT" == 1 ] && printf " image at :$IMAGETIME\n"
}

#**************************************************************************************************************
# Crop out black borders (this needs more work, kind of hazard at the moment.
# TODO: Needs to verify dimensional changes, so it won't cut too much
#***************************************************************************************************************
check_and_crop () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ "$SPLIT_AND_COMBINE" -eq "1" ] && [[ ! "$APP_STRING" =~ "ffmpeg" ]]; then
        printf "${Red}Cannot crop files with ${Yellow}$APP_STRING${Red} Aborting!${Color_Off}\n"
        exit 1
    fi

    [ "$BUGME" -eq "1" ] && printf "\n    $Purple$APP_STRING -i \"$FILE\" -t 1 -vf cropdetect -f null$Color_Off\n"
    CROP_DATA=$($APP_NAME -i "$FILE" -t 1 -vf cropdetect -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1)
    if [ -n "$CROP_DATA" ]; then
        XC=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        YC=$(mediainfo '--Inform=Video;%Height%' "$FILE")

        if [ -n "$XC" ] && [ -n "$YC" ]; then
            CB=$(printf "$CROP_DATA" | cut -d = -f 2)
            mapfile -t -d ':' CA < <(printf "%s" "$CB")

            if [ "${CA[0]}" -ge "0" ] && [ "${CA[1]}" -ge "0" ]; then
                if [ "$XC" -ne "${CA[0]}" ] || [ "$YC" -ne "${CA[1]}" ] || [ "${CA[2]}" -gt "0" ] || [ "${CA[3]}" -gt "0" ]; then
                    if [ "${CA[0]}" -ge "320" ] && [ "${CA[1]}" -ge "240" ]; then
                        print_info
                        short_name
                        PROCESS_NOW=$(date +%T)
                        printf "$PROCESS_NOW : $FILEprint ${APP_STRING} Cropping black borders ->($CROP_DATA) \t"
                        [ "$BUGME" -eq "1" ] && printf "\n    $Purple$APP_STRING -i \"$FILE\" -vf \"$CROP_DATA\"$Color_Off\n"
                        COMMAND_LINE="-vf $CROP_DATA"
                        run_pack_app
                        calculate_duration
                        check_file_conversion
                    else
                        printf "${Yellow}$FILE ${Red}Cropping to ${CA[0]}x${CA[1]} (${CA[2]} ${CA[3]}) makes video too small! Skipping!${Color_Off}\n"
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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    ZERORETVAL="$1"
    ttime="${1:0:1}"
    [ -n "$ttime" ] && [ "$ttime" == "0" ] && ZERORETVAL="${1:1:1}"
}

#**************************************************************************************************************
# Delete file / scrub file
# 1 - path to filename
# 2 - track to source
#***************************************************************************************************************
delete_file () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]} '$1' src:$2\n"

    if [ -f "$1" ]; then
        if [ "$SCRUB" == "1" ]; then   scrub -r "$1" >/dev/null 2>&1
        elif [ "$SCRUB" == "2" ]; then scrub -r "$1"
        else                           rm -fr "$1"; fi
    fi
}

#**************************************************************************************************************
# If splitting breaks, remove broken files
#**************************************************************************************************************
remove_broken_split_files () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    RUNNING_FILE_NUMBER=1
    make_running_name

    if [ -f "${TARGET_DIR}/$RUNNING_FILENAME" ]; then
        delete_file "${TARGET_DIR}/$RUNNING_FILENAME" "1"
        while true; do
            RUNNING_FILE_NUMBER=$((RUNNING_FILE_NUMBER + 1))
            make_running_name
            [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ] && break
            delete_file "${TARGET_DIR}/$RUNNING_FILENAME" "2"
        done
    fi
}

#**************************************************************************************************************
# Check that the timelength matches with the destination files from splitting
#***************************************************************************************************************
massive_filecheck () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ "$ERROR_WHILE_SPLITTING" != "0" ] || [ "$ERROR_WHILE_MORPH" != "0" ]; then
        printf "${Red}Something went wrong with splitting $FILE${Color_Off}\n"
        RETVAL=18
        remove_broken_split_files
        return
    fi

    MASSIVE_TIME_COMP=0
    RUNNING_FILE_NUMBER=0
    MASSIVE_SIZE_COMP=0
    TOO_SMALL_FILE=0

    if [ -n "$DELIMITER" ] && [ "$MASS_SPLIT" == "1" ]; then
        DELIM_ITEM=0
        for CHECKITEM in "${SN_NAMES[@]}"; do
            DELIMNAME="${TARGET_DIR}/${SN_BEGIN}.$((DELIM_ITEM + 1)) ${SN_NAMES[$((DELIM_ITEM))]}$CONV_TYPE"
            CFT=$(mediainfo '--Inform=Video;%Duration%' "$DELIMNAME")
            MASSIVE_TIME_COMP=$((MASSIVE_TIME_COMP + CFT))
            MSC=$(du -k "$DELIMNAME" | cut -f1)
            [ "$MSC" -lt "3000" ] && TOO_SMALL_FILE=$((TOO_SMALL_FILE + 1))
            MASSIVE_SIZE_COMP=$((MASSIVE_SIZE_COMP + MSC))
            DELIM_ITEM=$((DELIM_ITEM + 1))
        done
    else
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
    fi

    [ "$IGNORE" -ne "0" ] && TOO_SMALL_FILE=0
    [ "$SPLIT_AND_COMBINE" -ne "0" ] && TOO_SMALL_FILE=0

    TIME_SHORTENED=$((ORIGINAL_DURATION - MASSIVE_TIME_COMP))
    TIME_SHORTENED=$((TIME_SHORTENED / 1000))

    if [ "$SPLIT_AND_COMBINE" -eq "1" ] && [ -n "$MAX_SHORT_TIME" ] && [ "$TIME_SHORTENED" -gt "$MAX_SHORT_TIME" ]; then
        printf "${Red}Cutting over max-time:${TIME_SHORTENED}s > ${MAX_SHORT_TIME}s, aborting!${Color_Off}\n"
        RETVAL=19
    elif [ "$MASSIVE_TIME_COMP" -ge "$MASSIVE_TIME_CHECK" ] && [ "$TOO_SMALL_FILE" == "0" ] && [ "$SPLITTING_ERROR" == "0" ]; then

        if [ "$KEEPORG" == "0" ] && [ "$ERROR_WHILE_MORPH" == "0" ]; then
            SPLITTER_TIMESAVE=$((SPLITTER_TIMESAVE + MASSIVE_TIME_COMP))
            OSZ=$(du -k "$FILE" | cut -f1)
            [ "$ERROR_WHILE_SPLITTING" == "0" ] && delete_file "$FILE" "3"
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
        RETVAL=20
    fi
}

#***************************************************************************************************************
# Split file into chunks given by input parameters, either (start-end,start-end|...) or (point,point,point,...)
# 1 - Splitting time information
#***************************************************************************************************************
new_massive_file_split () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    IGNORE=1
    MASSIVE_FILE_HANDLE=1

    if [ "$SPLIT_AND_COMBINE" -eq "1" ]; then
        if [[ ! "$APP_STRING" =~ "ffmpeg" ]]; then
            printf "${Red}Cannot combine files with ${Yellow}$APP_STRING${Red} Aborting!${Color_Off}\n"
            exit 1
        fi
    fi

    ERROR_WHILE_SPLITTING=0
    MASSIVE_TIME_CHECK=0
    FILECOUNT=1
    MASSIVE_SPLIT=1
    KEEPORG=1

    if [ -n "$DELIMITER" ]; then
        SN_BEGIN="${FILE%% *}"
        SN_END="${FILE#* }"
        SN_END="${SN_END%.*}"
        mapfile -t -d ${DELIMITER} SN_NAMES < <(printf "%s" "$SN_END")
        DELIM_ITEM=0
    fi

    if [ -f "$FILE" ]; then
        EXT_CURR="${FILE##*.}"
        LEN=$(mediainfo '--Inform=Video;%Duration%' "$FILE")
        XSS=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        LEN=${LEN%.*}
        LEN=$((LEN / 1000))
        ORG_LEN="$LEN"

        SPLIT_P2P=$(grep -o "-" <<< "$1" | wc -l)

        mapfile -t -d ',' array < <(printf "%s" "$1")
        SPLIT_MAX=${#array[@]}
        MASSIVE_COUNTER=0

        handled_index=0
        for index in "${!array[@]}"; do
            if [ "$SPLIT_P2P" -gt 0 ]; then
                mapfile -t -d '-' array2 < <(printf "%s" "${array[index]}")

                if [ "${array2[0]}" == "D" ]; then
                    KEEPORG=0
                    break
                fi

                [ "$index" -ne "0" ] && printf "\n"

                calculate_time "${array2[0]}"
                BEGTIME=$CALCTIME
                verify_time_position "$ORG_LEN" "$BEGTIME" "Beginning massive time"
                [ "$ERROR" != "0" ] && ERROR_WHILE_SPLITTING=13 && break

                calculate_time "${array2[1]}" "1"
                ENDTIME=$CALCTIME
                verify_time_position "$ORG_LEN" "$ENDTIME" "Beginning massive time"
                [ "$ERROR" != "0" ] && ERROR_WHILE_SPLITTING=14 && break

                if [ -z "$XSS" ] || [ -z "$WIDTH" ]; then
                    printf "Something wrong with width w:$WIDTH s:$XSS\ŋ"
                    ERROR_WHILE_SPLITTING=1
                    RETVAL=21
                    break
                fi

                #printf "1 - e:$ENDTIME b:$BEGTIME w:$WIDTH x:$XSS\n"

                if [ "$ENDTIME" -le "$BEGTIME" ] && [ "$ENDTIME" != "0" ] [ "$WIDTH" -ge "$XSS" ]; then
                    ERROR_WHILE_SPLITTING=2
                    printf "${Red}Split error $FILE - Time: $ENDTIME <= $BEGTIME - Size: $WIDTH >= $XSS${Color_Off}\n"
                    RETVAL=22
                    break
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
                [ "$ERROR" != "0" ] && break
                SPLIT_POINT=$CALCTIME
                calculate_time "${array[index + 1]}" "1"
                [ "$ERROR" != "0" ] && break
                SPLIT_POINT2=$CALCTIME
                if [ "$SPLIT_POINT2" -le "$SPLIT_POINT" ] && [ $SPLIT_POINT2 != "0" ] || [ "$WIDTH" -ge "$XSS" ]; then
                    ERROR_WHILE_SPLITTING=3
                    printf "${Red}Split error $FILE - Time: $SPLIT_POINT2 <= $SPLIT_POINT, - Size: $WIDTH <= $XSS${Color_Off}\n"
                    RETVAL=23
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
                handled_index=$((handled_index + 1))
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

        [ "$handled_index" -eq "1" ] && [ -z "$NEWNAME" ] && rename "s/_01//" "${FILE%.*}"*
        [ "$handled_index" -eq "1" ] && [ -n "$NEWNAME" ] &&  rename "s/_01//" "${NEWNAME%.*}"*

    else
        printf "File '$FILE' not found, cannot multisplit!\n"
        ERROR=10
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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    RUNNING_FILE_NUMBER=1

    while true; do
        make_running_name

        if [ -z "$1" ]; then
            [ ! -f "${TARGET_DIR}/temp_${RUNNING_FILE_NUMBER}$CONV_TYPE" ] && break
            delete_file "${TARGET_DIR}/temp_${RUNNING_FILE_NUMBER}$CONV_TYPE" "4"
        else
            [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ] && break

            mv "${TARGET_DIR}/$RUNNING_FILENAME" "${TARGET_DIR}/temp_${RUNNING_FILE_NUMBER}$CONV_TYPE"

            if [ "$TARGET_DIR" == "." ]; then printf "file 'temp_${RUNNING_FILE_NUMBER}$CONV_TYPE'\n" >> "packcombofile.txt"
            else                              printf "file 'temp_${RUNNING_FILE_NUMBER}$CONV_TYPE'\n" >> "${TARGET_DIR}/packcombofile.txt"; fi
        fi

        COMBINE_RUN_COUNT="$RUNNING_FILE_NUMBER"
        RUNNING_FILE_NUMBER=$((RUNNING_FILE_NUMBER + 1))
    done
}

#***************************************************************************************************************
# In case of failure, remove files meant to be combined
#***************************************************************************************************************
remove_combine_files() {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    RUNNING_FILE_NUMBER=1

    while true; do
        make_running_name

        [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ] && break
        delete_file "${TARGET_DIR}/$RUNNING_FILENAME" "5"

        COMBINE_RUN_COUNT="$RUNNING_FILE_NUMBER"
        RUNNING_FILE_NUMBER=$((RUNNING_FILE_NUMBER + 1))
    done
}

#***************************************************************************************************************
# Combine split files into one file, then remove splitted files and rename combofile
#***************************************************************************************************************
combine_split_files() {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ "$SPLITTING_ERROR" != "0" ]; then
        printf "Failed to separate all asked parts, not combining (err:$SPLITTING_ERROR)!"
        delete_file "${TARGET_DIR}/packcombofile.txt" "6"
        delete_file "${TARGET_DIR}/tmp_combo$CONV_TYPE" "7"
        [ "$EXIT_VALUE" == "1" ] && exit 1
        return 0
    fi

    make_or_remove_split_files 1
    CURRDIR="$PWD"
    cd "$TARGET_DIR" || return

    ERROR=0
    printf "%${PACKLEN}s Combining $COMBINE_RUN_COUNT split files " " "
    $APP_NAME -f concat -i "packcombofile.txt" -c copy "tmp_combo$CONV_TYPE"  -v quiet >/dev/null 2>&1
    ERROR=$?

    cd "$CURRDIR" || return
    delete_file "${TARGET_DIR}/packcombofile.txt" "8"

    if [ "$ERROR" -eq "0" ]; then
        LE_ORG_FILE="$FILE"
        FILE="temp.mp4"
        make_or_remove_split_files
    else
        printf "${Red}Failed${Color_Off}\n"
        delete_file "${TARGET_DIR}/tmp_combo$CONV_TYPE" "9"
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
    if [ -n "$NEWNAME" ]; then
        printf "${Green}Success in $TIMERVALUE/$TIMER_TOTAL_PRINT ${Yellow}${NEWNAME}${CONV_TYPE}${Color_Off} Shortened:$TIMER_SECOND_PRINT\n"
        FILE="${NEWNAME}${CONV_TYPE}"
    else
        printf "${Green}Success in $TIMERVALUE/$TIMER_TOTAL_PRINT ${Yellow}${RUNNING_FILENAME}${Color_Off} Shortened:$TIMER_SECOND_PRINT\n"
        FILE="$LE_ORG_FILE"
    fi
}

#***************************************************************************************************************
# Combine given input files to one file
#***************************************************************************************************************
combineFiles () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    FILESCOUNT=0
    DELETESOURCEFILES=0

    for file in "${COMBINELIST[@]}"; do
        [ -f "$file" ] && printf "file '$file'\n" >> "packcombofile.txt" && FILESCOUNT=$((FILESCOUNT + 1))
        [ "$file" == "delete" ] && DELETESOURCEFILES=1
        [ "$FILESCOUNT" -gt "0" ] && [ -z "$NEWNAME" ] && NEWNAME="$file"
    done

    if [ "$FILESCOUNT" -gt "1" ];  then
        [ -z "$NEWNAME" ] && NEWNAME="target_combo"

        printf "Combining $FILESCOUNT files "
        ERROR=0
        $APP_NAME -f concat -safe 0 -i "packcombofile.txt" -c copy "${TARGET_DIR}/${NEWNAME}_${CONV_TYPE}" -v quiet >/dev/null 2>&1
        ERROR=$?

        delete_file "packcombofile.txt" "10"

        if [ "$ERROR" -eq "0" ]; then
            if [ "$DELETESOURCEFILES" == "1" ]; then
                for file in "${COMBINELIST[@]}"; do
                    [ -f "$file" ] && delete_file "$file" "11"
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
        [ -f "packcombofile.txt" ] && delete_file "packcombofile.txt" "12"
        printf "${Red}No input files given to combine! Filecount:$FILESCOUNT${Color_Off}\n"
        exit 1
    fi
}

#***************************************************************************************************************
# Replace or insert audio in video file with given audio files
# 1 - If not set, is a merge, else append
#***************************************************************************************************************
mergeFiles () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

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
        [ "$BUGME" -eq "1" ] && printf "\n    $Purple$APP_STRING \"${COMMANDSTRING[*]}\" $SETUPSTRING \"${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}\"$Color_Off\n"
        $APP_NAME "${COMMANDSTRING[@]}" $SETUPSTRING "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" >/dev/null 2>&1
        ERROR=$?

        calculate_time_taken

        if [ "$ERROR" -eq "0" ]; then
            if [ "$DELETESOURCEFILES" == "1" ]; then
                for file in "${COMBINELIST[@]}"; do [ -f "$file" ] && delete_file "$file" "13"; done
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
            delete_file "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" "14"
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
# 2 - ???
#***************************************************************************************************************
calculate_time () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    re='^[0-9:.]+$'
    ERROR=0
    [[ ! "$1" =~ $re ]] && ERROR=11 && printf "${Red}${FUNCNAME[0]} -> not correct: $1${Color_Off}\n" && return

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

            mapfile -t -d ':' TA < <(printf "%s" "$MAINTIME")

            for i in "${!TA[@]}"; do
                check_zero "${TA[$i]}"
                TA[$i]=$ZERORETVAL
            done

            if [ "${#TA[@]}" == "2" ]; then
                TA[0]=$((${TA[0]} * 60))
            elif [ "${#TA[@]}" -gt "2" ]; then
                TA[0]=$((${TA[0]} * 3600))
                TA[1]=$((${TA[1]} * 60))
            fi

            for i in "${TA[@]}"; do CALCTIME=$((CALCTIME + i)); done

            [ "$ADDTIME" != "0" ] && CALCTIME+=".${ADDTIME}"
        fi
    fi
}

#**************************************************************************************************************
# Parse special handlers
# 1 - input string
# 2 - if set, will add certain values to arrays instead of immediately settings values
#***************************************************************************************************************
parse_handlers () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ -n "$1" ]; then
        if [ "$1" == "repack" ] || [ "$1" == "r" ]; then
            [ -n "$2" ] && PACK_RUN+=("$1") && return
            REPACK=1
            REPACK_GIVEN=1
            COPY_ONLY=0
        elif [ "$1" == "ierr" ]; then
            IGNORE_UNKNOWN=1
        elif [ "$1" == "bugme" ]; then
            BUGME=1
        elif [ "$1" == "quit" ]; then
            EXIT_VALUE=1
        elif [ "$1" == "repeat" ]; then
            EXIT_REPEAT=1
        elif [ "$1" == "command" ]; then
            CMD_PRINT="1"
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
        elif [ "$1" == "quick" ]; then
            QUICK=1
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
            [ -n "$2" ] && CROP_RUN+=("$1") && return
            CROP=1
        elif [ "$1" == "scrub" ] || [ "$1" == "s" ]; then
            SCRUB=1
        elif [ "$1" == "print" ] || [ "$1" == "p" ]; then
            PRINT_INFO=1
        elif [ "$1" == "hevc" ] || [ "$1" == "h" ]; then
            #IGNORE=1
            APP_NAME="/usr/bin/avconv"
            APP_STRING="avconv"
            HEVC_CONV=0
        elif [ "$1" == "D" ]; then
            DEBUG_PRINT=1
        else
            printf "Unknown handler $1\n"
            RETVAL=1
            ERROR=6
            [ "$NO_EXIT_EXTERNAL" == "0" ] && exit "$RETVAL"
        fi
    fi
}

#**************************************************************************************************************
# Parse time values to remove
# 1 - input value
# 2 - if set, will set certain values to arrays instead of setting them imediately
#***************************************************************************************************************
parse_values () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    ARRAY_INSERT=0

    if [ -n "$1" ]; then
        HANDLER=$(printf "$1" | cut -d = -f 1)
        VALUE=$(printf "$1" | cut -d = -f 2)

        if [ "$HANDLER" == "beg" ] || [ "$HANDLER" == "b" ]; then
            CUTTING=$((CUTTING + 1))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            calculate_time "$VALUE"
            [ "$ERROR" != "0" ] && return
            BEGTIME=$CALCTIME
        elif [ "$HANDLER" == "end" ] || [ "$HANDLER" == "e" ]; then
            CUTTING=$((CUTTING + 1))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            calculate_time "$VALUE" "1"
            [ "$ERROR" != "0" ] && return
            ENDTIME=$CALCTIME
        elif [ "$HANDLER" == "max" ]; then
            MAX_SHORT_TIME="$VALUE"
        elif [ "$HANDLER" == "delaudio" ]; then
            AUDIODELAY="$VALUE"
        elif [ "$HANDLER" == "delvideo" ]; then
            VIDEODELAY="$VALUE"
        elif [ "$HANDLER" == "language" ] || [ "$HANDLER" == "l" ]; then
            [ -n "$2" ] && SUB_RUN+=("$1") && return
            LANGUAGE="$VALUE"
        elif [ "$HANDLER" == "videotrack" ] || [ "$HANDLER" == "vt" ]; then
            [ -n "$2" ] && PACK_RUN+=("$1") && return
            VIDEOTRACK="$VALUE"
        elif [ "$HANDLER" == "audiotrack" ] || [ "$HANDLER" == "at" ]; then
            [ -n "$2" ] && PACK_RUN+=("$1") && return
            AUDIOTRACK="$VALUE"
        elif [ "$HANDLER" == "Position" ] || [ "$HANDLER" == "P" ]; then
            CUTTING=$((CUTTING + 1))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            START_POSITION="$VALUE"
        elif [ "$HANDLER" == "End" ] || [ "$HANDLER" == "E" ]; then
            CUTTING=$((CUTTING + 1))
            [ -n "$2" ] && PACK_RUN+=("$1") && return
            END_POSITION="$VALUE"
        elif [ "$HANDLER" == "duration" ] || [ "$HANDLER" == "d" ]; then
            CUTTING=$((CUTTING + 1))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            calculate_time "$VALUE"
            [ "$ERROR" != "0" ] && return
            DURATION_TIME=$CALCTIME
        elif [ "$HANDLER" == "target" ] || [ "$HANDLER" == "t" ]; then
            CONV_TYPE=".$VALUE"
            CONV_CHECK="$VALUE"
        elif [ "$HANDLER" == "Audio" ] || [ "$HANDLER" == "A" ]; then
            AUDIO_PACK=1
            CONV_TYPE=".$VALUE"
            CONV_CHECK="$VALUE"
        elif [ "$HANDLER" == "Combine" ] || [ "$HANDLER" == "C" ]; then
            CUTTING=$((CUTTING + 1))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            SPLIT_AND_COMBINE=1
            new_massive_file_split "$VALUE"
        elif [ "$HANDLER" == "cut" ] || [ "$HANDLER" == "c" ]; then
            CUTTING=$((CUTTING + 1))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            MASS_SPLIT=1
            new_massive_file_split "$VALUE"
        elif [ "$HANDLER" == "print" ] || [ "$HANDLER" == "p" ]; then
            PRINT_INFO=$VALUE
        elif [ "$HANDLER" == "sub" ]; then
            [ -n "$2" ] && SUB_RUN+=("$1") && return
            SUBFILE="$VALUE"
        elif [ "$HANDLER" == "w" ] || [ "$HANDLER" == "write" ]; then
            WRITEOUT="$VALUE"
        elif [ "$HANDLER" == "n" ] || [ "$HANDLER" == "name" ]; then
            CUTTING=$((CUTTING + 1))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            NEWNAME="$VALUE"
        elif [ "$HANDLER" == "N" ]; then
            CUTTING=$((CUTTING + 1))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            DELIMITER="$VALUE"
        elif [ "$HANDLER" == "T" ] || [ "$HANDLER" == "Target" ]; then
            CUTTING=$((CUTTING + 1))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            TARGET_DIR="$VALUE"
            mkdir -p "$TARGET_DIR"
        elif [ "$1" == "scrub" ] || [ "$1" == "s" ]; then
            SCRUB=$VALUE
        else
            printf "Unknown value $1\n"
            ERROR=7
            RETVAL=2
            [ "$NO_EXIT_EXTERNAL" == "0" ] && exit "$RETVAL"
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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ -n "$1" ]; then
        WIDTH=$(printf "$1" | cut -d x -f 1)
        if [ "$WIDTH" -lt "640" ]; then
            printf "$WIDTH way too small width to be used! Aborting! 640x is minimum!\n"
            exit 1
        fi
        #HEIGHT=$(printf "$1" | cut -d x -f 2)
        COPY_ONLY=0
        DIMENSION_PARSED=1
    fi
}

#**************************************************************************************************************
# Parse file information
#***************************************************************************************************************
parse_file () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ -n "$1" ]; then
        CONTINUE_PROCESS=1
        FILE="$1"
        filename="${FILE%.*}"

        if [ ! -f "$FILE" ] && [ -f "${filename}.mp4" ]; then FILE="${filename}.mp4"; fi

        if [ ! -f "$FILE" ]; then
            shopt -s nocaseglob
            FILECOUNT=$(find . -maxdepth 1 -name "*$FILE" |wc -l)
            [ "$FILECOUNT" == 0 ] && MULTIFILECOUNT=$(find . -maxdepth 1 -name "*${FILE}*" |wc -l)
            shopt -u nocaseglob
            if [ "$FILECOUNT" == "0" ] && [ "$MULTIFILECOUNT" == "0" ]; then
                CONTINUE_PROCESS=0
            fi
        fi
    fi
}

#***************************************************************************************************************
# Handle other options
#***************************************************************************************************************
handle_sub_files () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ -n "$SUBFILE" ]; then
        SINGULAR=1
        if [ -f "${FILE}" ]; then
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
                    PACKLOOP=0
                fi
            done
            shopt -u nocaseglob
        else
            ERROR=3
            printf "${Red}File(s) '$1' not found (other files)!${Color_Off}\n"
            RETVAL=3
        fi
    fi
}

#***************************************************************************************************************
# Pack sizechange only
#***************************************************************************************************************
handle_filesize_change () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ "$FILECOUNT" -le 1 ] && [ "$MULTIFILECOUNT" -le 1 ]; then
        pack_file
        FILE="${filename}${CONV_TYPE}"
    elif [ "$FILECOUNT" -gt 0 ]; then
        EXT_CURR="$FILE"
        shopt -s nocaseglob
        for f in *".$EXT_CURR"; do
            FILE="$f"
            CURRENTFILECOUNTER=$((CURRENTFILECOUNTER + 1))
            pack_file
            PACKLOOP=0
        done
        shopt -u nocaseglob
    elif [ "$MULTIFILECOUNT" -gt 0 ]; then
        shopt -s nocaseglob
        for f in *"$FILE"*; do
            if [ -f "$f" ]; then
                FILE="$f"
                CURRENTFILECOUNTER=$((CURRENTFILECOUNTER + 1))
                pack_file
                PACKLOOP=0
            fi
        done
        shopt -u nocaseglob
    else
        ERROR=4
        printf "${Red}File(s) '$1' not found (filesize change)!${Color_Off}\n"
        RETVAL=4
    fi
}

#***************************************************************************************************************
# Handle cutting settings
#***************************************************************************************************************
handle_cuttings () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ -f "$FILE" ]; then
        FILECOUNT=0
        pack_file
    elif [ "$FILECOUNT" -gt 0 ]; then
        EXT_CURR="$FILE"
        shopt -s nocaseglob
        for f in *".$EXT_CURR"; do
            FILE="$f"
            CURRENTFILECOUNTER=$((CURRENTFILECOUNTER + 1))
            pack_file
            PACKLOOP=0
        done
        shopt -u nocaseglob
    elif [ "$MULTIFILECOUNT" -gt 0 ]; then
        shopt -s nocaseglob
        for f in *"$FILE"*; do
            if [ -f "$f" ]; then
                FILE="$f"
                CURRENTFILECOUNTER=$((CURRENTFILECOUNTER + 1))
                pack_file
                PACKLOOP=0
            fi
        done
        shopt -u nocaseglob
    else
        ERROR=5
        printf "${Red}File(s) '$1' not found (cutting)!${Color_Off}\n"
        RETVAL=5
    fi
}

#***************************************************************************************************************
# Parse input data from given commandline inputs
# 1 - input option
# 2 - if set, will separate different step options
#***************************************************************************************************************
parse_data () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

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
                if [ "$xss" == "0" ]; then parse_handlers "$1" "$2"
                else                       parse_values "$1" "$2"; fi
            elif [ -n "$2" ]; then
                PACK_RUN+=("$1")
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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ -f "$FILE" ]; then
        X=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        if [ -n "$X" ]; then
            if [ "$PRINT_INFO" == "2" ] && [ "$WIDTH" -le "$X" ]; then   return 0
            elif [ "$PRINT_INFO" == "3" ] && [ "$WIDTH" -ge "$X" ]; then return 0
            elif [ "$PRINT_INFO" == "4" ] && [ "$WIDTH" == "$X" ]; then  printf "$PACKSIZE -- $X\n" && return 0; fi

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
            [ -n "$WRITEOUT" ] && printf "packAll.sh \"$FILE\" \n" >> "$WRITEOUT"
        else
            printf "$FILE is corrupted\n"
        fi
    fi
}

#***************************************************************************************************************
# Print multiple file handling information
#***************************************************************************************************************
print_info () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    TIMERR=$(date +%s)
    processing_time=$((TIMERR - process_start_time))
    TIMERVALUE=$(date -d@${processing_time} -u +%T)
}

#***************************************************************************************************************
# Cut filename shorter if it's too long, or fill with empty to match length
# 1 - filename max length
#***************************************************************************************************************
short_name () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    NAMENOEXT="${FILE%.*}"
    if [ "${#FILE}" -lt "41" ]; then
        FILEprint=$(printf "%-41s" "$FILE")
    elif [ "${#NAMENOEXT}" -lt "35" ]; then
        PART_LEN=$((40 - ${#NAMENOEXT} - ${#EXT_CURR}))
        FILEprint=$(printf "%s.%s%${PART_LEN}s" "${NAMENOEXT}" "${EXT_CURR}" " ")
    else
        FILEprint=$(printf "%-35s.%-5s" "${NAMENOEXT:0:35}" "${EXT_CURR:0:3}")
    fi
}

#***************************************************************************************************************
# Setup file packing variables
# TODO: add all other variations, like mp3 stripping
#***************************************************************************************************************
setup_file_packing () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    COMMAND_LINE=""

    if [ "$WORKMODE" == "1" ] || [ "$WORKMODE" == "3" ]; then
        verify_time_position "$DUR" "$BEGTIME" "Beginning time"
        [ "$ERROR" != "0" ] && return
        COMMAND_LINE+="-ss $BEGTIME "
    fi

    if [ "$WORKMODE" == "2" ] || [ "$WORKMODE" == "3" ]; then
        verify_time_position "$DUR" "$ENDTIME" "Ending time"
        [ "$ERROR" != "0" ] && return
        ENDO=$((DUR - ENDTIME - BEGTIME))
        COMMAND_LINE+="-t $ENDO "
    fi

    AUDIOSTUFF=$((MP3OUT + AUDIO_PACK + WAV_OUT))

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
    elif [ "$COPY_ONLY" == "0" ]; then COMMAND_LINE+="-bsf:v h264_mp4toannexb -sn -vcodec libx264 -codec:a libmp3lame -q:a 0 -v error -vf scale=$PACKSIZE "
    elif [ "$QUICK" == "1" ]; then     COMMAND_LINE+="-c:v copy -c:a copy "
    else                               COMMAND_LINE+="-c:v:1 copy " && NOMAPPING=1 ; fi

    if [ -z "$AUDIODELAY" ] && [ -z "$VIDEODELAY" ]; then
        INCREMENTOR=0

        if [ -n "$VIDEOTRACK" ] && [ "$AUDIOSTUFF" -eq "0" ]; then
            mapfile -t -d ':' video_array < <(printf "%s" "$VIDEOTRACK")

            for video in "${video_array[@]}"; do
                COMMAND_LINE+="-map $INCREMENTOR:v:$video "
                INCREMENTOR=$((INCREMENTOR + 1))
            done
        elif [ -n "$AUDIOTRACK" ]; then
            COMMAND_LINE+="-map $INCREMENTOR:v:0 "
            #INCREMENTOR=1
        fi

        if [ -n "$AUDIOTRACK" ]; then
            mapfile -t -d ':' audio_array < <(printf "%s" "$VIDEOTRACK")

            for audio in "${audio_array[@]}"; do
                COMMAND_LINE+="-map $INCREMENTOR:a:$audio "
                INCREMENTOR=$((INCREMENTOR + 1))
            done
        elif [ -n "$VIDEOTRACK" ]; then
            COMMAND_LINE+="-map $INCREMENTOR:a:0 "
        fi
    fi

    COMMAND_LINE+="-metadata title= "
}

#***************************************************************************************************************
# Find correct mapping positions for video on audio, if no streams have been set
#***************************************************************************************************************
setup_add_packing () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    COMMAND_ADD=""
    VIDEOID="-1"

    AUDIOSTUFF=$((MP3OUT + AUDIO_PACK + WAV_OUT))

    if [ "$AUDIOSTUFF" -eq "0" ]; then
        if [ -z "$VIDEOTRACK" ]; then
            VIDEOID=$(mediainfo '--Inform=Video;%ID%' "$FILE")
            VIDEOID=$((VIDEOID - 1))
        fi

        if [ -z "$AUDIOTRACK" ]; then
            AUDIO_OPTIONS=$(mediainfo '--Inform=Audio;%Language%' "$FILE")

            if [ -z "$AUDIO_OPTION" ]; then
                [ "$NOMAPPING" == "0" ] && COMMAND_ADD="-map 0 "
            else
                AUDIOID=1
                AUDIOFOUND=0

                while [ -n "${#AUDIO_OPTIONS}" ]; do
                    [ "${#AUDIO_OPTIONS}" -lt 2 ] && break
                    [ "${AUDIO_OPTIONS:0:2}" == "$LANGUAGE" ] && AUDIOFOUND=1 && break
                    AUDIO_OPTIONS="${AUDIO_OPTIONS:2}"
                    AUDIOID=$((AUDIOID + 1))
                done

                [ "$AUDIOFOUND" -eq "1" ] && [ "$VIDEOID" -ge "0" ] && [ "$AUDIOID" -ge "0" ] && COMMAND_ADD+="-map 0:v:$VIDEOID -map 1:a:$AUDIOID "
                [ "$AUDIOFOUND" -eq "0" ] && [ "$VIDEOID" -ge "0" ] && COMMAND_ADD+="-map 0 "
            fi
        fi
    fi
}

##########################################################################################
# Update still timer until app is done
# 1 - start time of PID in seconds
# 2 - pid of application
##########################################################################################
loop_pid_time () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    FIRST=1
    STR_LEN=0
    while [ -n "$1" ] && [ -n "$2" ]; do
        NOW=$(date +%s)
        DIFFER=$((NOW - $1))
        [ -f "$PACKFILE" ] && line=$(cat $PACKFILE | tail -1)
        PRINTOUT="$(date -d@${DIFFER} -u +%T) "
        if [[ "$line" == *"time="* ]]; then
            PRINT_ITEM="${line##*time=}"
            PRINT_ITEM="${PRINT_ITEM%%.*}"
            PRINTOUT+="file:${PRINT_ITEM}/${FILEDURATION}"
        fi
        printf "\033[${STR_LEN}D$PRINTOUT"
        kill -s 0 "$2" >/dev/null 2>&1                  # Check if the PID is still active
        [ "$?" -ne "0" ] && break
        sleep 1
        STR_LEN="${#PRINTOUT}"
    done
}


#***************************************************************************************************************
# Check ffmpeg output for errors and act accordingly
#***************************************************************************************************************
check_output_errors () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    err1=$(grep "Invalid data found when processing input" "$PACKFILE")
    err2=$(grep "Bitstream filter not found" "$PACKFILE")
    err3=$(grep "not found" "$PACKFILE")
    err4=$(grep "error in an external library" "$PACKFILE")
    err5=$(grep "invalid format character" "$PACKFILE")
    err6=$(grep "Unknown error" "$PACKFILE")

    if [ -n "$err1" ] || [ -n "$err2" ] || [ -n "$err3" ] || [ -n "$err4" ] || [ -n "$err5" ] || [ -n "$err6" ]; then
        printf "\n    ${APP_STRING} error:"
        [ -n "$err1" ] && printf "${Red}$err1${Color_Off} in $TIMERVALUE\n"
        [ -n "$err2" ] && printf "${Red}$err2${Color_Off} in $TIMERVALUE\n"
        [ -n "$err3" ] && printf "${Red}$err3${Color_Off} in $TIMERVALUE\n"
        [ -n "$err4" ] && printf "${Red}$err4${Color_Off} in $TIMERVALUE\n"
        [ -n "$err5" ] && printf "${Red}$err5${Color_Off} in $TIMERVALUE\n"
        [ -n "$err6" ] && printf "${Red}$err6${Color_Off} in $TIMERVALUE\n"

        [ "$ERROR" == "0" ] && ERROR=9
        if [ "$EXIT_VALUE" == "1" ]; then
            delete_file "$PACKFILE" "15"
            handle_file_rename 0
            exit 1
        fi
        RETVAL=6
    fi
    delete_file "$PACKFILE" "16"
}

#***************************************************************************************************************
# Verify that time position is withing the timelimit
# 1 - file time
# 2 - position time
# 3 - error reason
#***************************************************************************************************************
verify_time_position () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ "$2" -ge "$1" ]; then
        printf "${Red}${3} ${2}s exceeds the file time ${1}s${Color_Off}\n"
        ERROR=13
        RETVAL=7
    fi
}

#***************************************************************************************************************
# Pack file by using enviromental variables
#***************************************************************************************************************
simply_pack_file () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    setup_file_packing
    [ "$ERROR" != "0" ] && return
    setup_add_packing
    short_name

    [ "$DURATION_TIME" -gt 0 ] && ENDTIME=$((ORIGINAL_DURATION - DURATION_TIME))
    [ "$MASSIVE_SPLIT" == 1 ] && [ "$NO_EXIT_EXTERNAL" == "1" ] && [ "$MASSIVE_COUNTER" -gt "0" ] && printf "           "

    PROCESS_NOW=$(date +%T)
    PRINTLINE="$PROCESS_NOW : $FILEprint ${APP_STRING}"
    PACKLEN="${#PRINTLINE}"
    [ "$PACKLOOP" -gt "0" ] && PRINTLINE=$(printf "%${PACKLEN}s" " ")

    [ "$EXIT_REPEAT" == "2" ] && PRINTLINE+=" retrying"

    if   [ "$AUDIO_PACK" == "1" ]; then   PRINTLINE+=$(printf " packing $EXT_CURR to $CONV_CHECK ")
    elif [ "$MP3OUT" == 1 ]; then         PRINTLINE+=$(printf " extracting $CONV_CHECK ")
    elif [ "${X}" == "${X_WIDTH}" ]; then PRINTLINE+=$(printf " repacking (%04dx%04d) " "$X" "$Y")
    elif [ "$COPY_ONLY" == "0" ]; then    PRINTLINE+=$(printf " packing (%04dx%04d->%04dx%04d) " "${X}" "${Y}" "$X_WIDTH" "$Y_HEIGHT")
    elif [ "$CUTTING_TIME" -gt 0 ]; then  PRINTLINE+=$(printf " cutting (%04dx%04d) " "${X}" "${Y}")
    else                                  PRINTLINE+=$(printf " copying (%04dx%04d) " "${X}" "${Y}"); fi

    ORIGINAL_DURATION=$(mediainfo '--Inform=Audio;%Duration%' "$FILE")
    ORG_DUR=$((ORIGINAL_DURATION / 1000))
    if [ "$AUDIO_PACK" == "1" ]; then
        calculate_time_given $((ORIGINAL_DURATION / 1000))
        PRINTLINE+=$(printf " duration:%-6.6s " "$TIMER_SECOND_PRINT")
    elif [ "$MASSIVE_SPLIT" == 1 ]; then
        calculate_time_given $(((ORIGINAL_DURATION / 1000) - CUTTING_TIME))
        PRINTLINE+=$(printf "splitting to %-6.6s (mode:$WORKMODE) " "$TIMER_SECOND_PRINT")
        MASSIVE_TIME_SAVE=$((MASSIVE_TIME_SAVE + ((ORIGINAL_DURATION / 1000) - CUTTING_TIME)))
    elif [ "$MP3OUT" == 1 ] && [ "$CUTTING_TIME" -gt 0 ]; then
        calculate_time_given $(((ORIGINAL_DURATION / 1000) - CUTTING_TIME))
        PRINTLINE+=$(printf "%-6.6s (mode:$WORKMODE) " "$TIMER_SECOND_PRINT")
    elif [ "$CUTTING_TIME" -gt 0 ]; then
        calculate_time_given "$CUTTING_TIME"
        PRINTLINE+=$(printf "shortened by %-6.6s (mode:$WORKMODE) " "$TIMER_SECOND_PRINT")
    fi

    if [ "$CUTTING_TIME" -gt 0 ]; then
        verify_time_position "$ORG_DUR" "$VAL_HAND" "Cutting time"
        [ "$ERROR" != "0" ] && return
    fi

    if [ -n "$SUBFILE" ] && [ "$SUBERR" = "0" ]; then
        if [ -n "$SUBLANG" ]; then
            PRINTLINE+=$(printf "Sub:$SUBLANG ")
        elif [ -f "$SUBFILE" ]; then
            PRINTLINE+=$(printf "Sub:${SUBFILE:0:10}")
        fi
    fi

    run_pack_app
}

#***************************************************************************************************************
# Run APP NAME with given options
#***************************************************************************************************************
run_pack_app () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    process_start_time=$(date +%s)
    FILEDURATION=$(lib V d "$FILE")

    ERROR=0
    [ -n "$CMD_PRINT" ] && printf "\n$Yellow '$COMMAND_LINE' '$COMMAND_ADD' $Color_Off"
    [ "$BUGME" -eq "1" ] && printf "\n    $Purple$APP_STRING -i \"$FILE\" $COMMAND_LINE $COMMAND_ADD \"${FILE}${CONV_TYPE}\"$Color_Off\n"

    printf "${PRINTLINE} "
    if [ "$NO_EXIT_EXTERNAL" == "0" ]; then
        $APP_NAME -i "$FILE" $COMMAND_LINE $COMMAND_ADD "${FILE}${CONV_TYPE}" -v info 2>$PACKFILE &
        PIDOF=$!
        loop_pid_time "$process_start_time" "$PIDOF"
        ERROR=$?
        check_output_errors
        printf "\r%s %${STR_LEN}s\r%s" "$PRINTLINE" " " "$PRINTLINE"
    else
        #$APP_NAME -i "$FILE" $COMMAND_LINE $COMMAND_ADD "${FILE}${CONV_TYPE}" -v quiet >/dev/null 2>&1
        $APP_NAME -i "$FILE" $COMMAND_LINE $COMMAND_ADD "${FILE}${CONV_TYPE}" -v info 2>$PACKFILE
        ERROR=$?
        check_output_errors
    fi
    PACKLOOP=$((PACKLOOP + 1))
}

#***************************************************************************************************************
# Read subtitle language from embedded video
# 1 - filename
# 2 - Subtitle track ID
# 3 - If set, will not print successfully read info
#***************************************************************************************************************
get_sub_info () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    SUBERR=0
    SUBDATA=$(mediainfo "$1")
    SUBVAL="$2"
    SUBVAL=$((SUBVAL + 1))
    SINGLESUB=$(printf "%s" "$SUBDATA" |grep -e "Text #$SUBVAL" -m 1 -A 12)
    [ -z "$SINGLESUB" ] && SINGLESUB=$(printf "%s" "$SUBDATA" |grep -e "Text" -m 1 -A 12)
    SUBLANG=$(printf "%s" "$SINGLESUB" |grep -e "Language")
    SUBLANG="${SUBLANG##*: }"
    SUBTITLE=$(printf "%s" "$SINGLESUB" |grep -e "Title")
    SUBTITLE="${SUBTITLE##*: }"

    if [ -z "$SUBLANG" ]; then
        SUBCOUNT=$(mediainfo '--Inform=General;%TextCount%;' "$1")
        [ "${SUBCOUNT}" == "1" ] && SUBLANG="Unknown"
    fi

    if [ -z "$SUBLANG" ]; then
        PRINTLINE+=$(printf "${Red}language not found for index '$2' ${Color_Off}\n")
        SUBERR=1
    elif [ "$SUBLANG" != "English" ] && [ "$SUBLANG" != "Unknown" ]; then
        printf "\n    Read language is not english? Proceed with '$SUBLANG' (y/n)?"
        read -rsn1 -t 1 sinput
        [ "$sinput" != "y" ] && printf "Aborting burning\n" && SUBERR=1
    elif [ -z "$3" ]; then 
        PRINTLINE+=$(printf "Language:$SUBLANG ")
        [ -n "$SUBTITLE" ] && PRINTLINE+=$(printf "Title:'${SUBTITLE:0:20}' ")
    fi
}

#***************************************************************************************************************
# Burn subtitle file to a given video file
# 1 - Video file
# 2 - Subtitle file
#***************************************************************************************************************
burn_subs () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ "$SPLIT_AND_COMBINE" -eq "1" ] && [[ ! "$APP_STRING" =~ "ffmpeg" ]]; then
        printf "${Red}Cannot burn subs with ${Yellow}$APP_STRING${Red} Aborting!${Color_Off}\n"
        exit 1
    fi

    MKVSUB=""
    RETVAL=0
    SUB="$2"

    if [ "$SUB" == "self:" ]; then
        END="${SUB##*:}"
        SUB="${1%.*}.${END}"
    else
        re='^[0-9]+$'
        [[ $SUB =~ $re ]] && MKVSUB="$SUB" && SUB="$1"
    fi

    if [ -f "$1" ]; then
        if [ -f "$SUB" ]; then
            FILE="$1"
            short_name

            PRINTLINE=$(printf "$(date +%T) : %-41s ${APP_STRING} burning subs " "${FILEprint}")
            [ -n "$MKVSUB" ] && get_sub_info "$SUB" "$MKVSUB" || PRINTLINE+=$(printf "File:'$SUB' ")
            ERROR=0

            if [ "$SUBERR" == "0" ]; then
                FILE="$1"
                if [ -n "$MKVSUB" ]; then COMMAND_LINE="-vf subtitles='$SUB':stream_index=$MKVSUB"
                else COMMAND_LINE="-vf subtitles=$SUB"; fi
                [ "$BUGME" -eq "1" ] && printf "\n    $Purple$APP_STRING -i \"$1\" ${COMMAND_LINE}$Color_Off\n"
                run_pack_app
                ERROR=$?
                calculate_time_taken

                ORGSIZE=$(du -k "$1" | cut -f1)
                SUBSIZE=0
                [ -z "$MKVSUB" ] && SUBSIZE=$(du -k "$SUB" | cut -f1)
                NEWSIZE=$(du -k "${FILE}${CONV_TYPE}" | cut -f1)
                NEWSIZE=$((ORGSIZE + SUBSIZE - NEWSIZE))
                TOTALSAVE=$((TOTALSAVE + NEWSIZE))
                NEWSIZE=$((NEWSIZE / 1000))
                PACKLOOP=$((PACKLOOP + 1))

                if [ "$ERROR" -eq "0" ]; then
                    printf "${Green}Success${Color_Off}"
                    if [ "$KEEPORG" == "0" ]; then
                        delete_file "$1" "17"
                        [ -f "$SUB" ] && delete_file "$SUB" "18"
                        mv "${FILE}${CONV_TYPE}" "${TARGET_DIR}/${filename}${CONV_TYPE}"
                        FILE="${filename}${CONV_TYPE}"
                    fi
                    printf "${Green} saved ${NEWSIZE}Mb in $TIMER_TOTAL_PRINT${Color_Off}\n"
                    SUCCESFULFILECNT=$((SUCCESFULFILECNT + 1))
                else
                    printf "${Red}Failed ($ERROR) in ${TIMER_TOTAL_PRINT}${Color_Off}\n"
                    delete_file "${FILE}${CONV_TYPE}" "19"
                    RETVAL=8
                fi
            else
                printf "${Yellow}%11s${1:0:40} Subfile file:$SUB mkv:$MKVSUB not found!${Color_Off}\n" " "
            fi
        else
            printf "${Red}%11s${1:0:40} Subfile file:$SUB mkv:$MKVSUB not found!${Color_Off}\n" " "
        fi
    else
        printf "${Red}%11s${1:0:40} not found (subs)!${Color_Off}\n" " "
        ERROR=2
    fi

    [ "$SINGULAR" == "1" ] && [ "$ERROR" != "0" ] && exit $ERROR
}

#***************************************************************************************************************
# Make a filename with incrementing value
#***************************************************************************************************************
RUNNING_FILENAME=""

make_running_name () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ -n "$DELIMITER" ] && [ "$MASS_SPLIT" == "1" ]; then
        mv "$FILE$CONV_TYPE" "${TARGET_DIR}/${SN_BEGIN}.$((DELIM_ITEM + 1)) ${SN_NAMES[${DELIM_ITEM}]}$CONV_TYPE"
        DELIM_ITEM=$((DELIM_ITEM + 1))
    else
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
    fi
}

#***************************************************************************************************************
# Rename output file to correct format or move unsuccesful file to other directory
# 1 - If bigger than zero, check one file, if 0, process failed and remove target files
#***************************************************************************************************************
handle_file_rename () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ "$1" -gt 0 ] && [ "$ERROR" -eq 0 ] ; then
        [ "$KEEPORG" == "0" ] && delete_file "$FILE" "20"

        if [ "$KEEPORG" == "0" ]; then
            if [ -n "$DELIMITER" ] && [ "$MASS_SPLIT" == "1" ]; then
                mv "$FILE$CONV_TYPE" "${TARGET_DIR}/${SN_BEGIN}.$((DELIM_ITEM + 1)) ${SN_NAMES[${DELIM_ITEM}]}$CONV_TYPE"
                DELIM_ITEM=$((DELIM_ITEM + 1))
            elif [ "$EXT_CURR" == "$CONV_CHECK" ]; then
                if [ -z "$NEWNAME" ]; then mv "$FILE$CONV_TYPE" "${TARGET_DIR}/${FILE}"
                else
                    mv "$FILE$CONV_TYPE" "${TARGET_DIR}/$NEWNAME$CONV_TYPE"
                fi
            else
                if [ "${TARGET_DIR}" != "." ]; then
                    mv "$FILE$CONV_TYPE" "${TARGET_DIR}/${filename}${CONV_TYPE}"
                else
                    mv "$FILE$CONV_TYPE" "${filename}${CONV_TYPE}"
                fi
            fi
        else
            move_to_a_running_file
        fi
    else
        calculate_duration
        [ "$ERROR" -ne "0" ] && printf "${Red}Something went wrong, keeping original!${Color_Off} in $TIMERVALUE\n"

        delete_file "$FILE$CONV_TYPE" "21"

        if [ "$EXT_CURR" == "$CONV_CHECK" ] && [ "$COPY_ONLY" == "0" ]; then
            [ ! -d "./Failed" ] && mkdir "Failed"
            RETVAL=9
            mv "$FILE" "./Failed"
        fi

        [ "$EXIT_VALUE" == "1" ] && exit 1
    fi
}

#***************************************************************************************************************
# Calculate dimension ratio change
#***************************************************************************************************************
calculate_packsize () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"
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

    X_WIDTH="$WIDTH"
    Y_HEIGHT="$SCALE"
    PACKSIZE="$WIDTH"x"$SCALE"
}

#***************************************************************************************************************
# Move corrupted file to a Error directory
#***************************************************************************************************************
handle_error_file () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    [ ! -d "./Error" ] && mkdir "Error"

    mv "$FILE" "./Error"
    calculate_duration
    printf "${Red}Something corrupted with $FILE${Color_Off} in $TIMERVALUE\n"

    [ "$EXIT_VALUE" == "1" ] && exit 1
    RETVAL=10
}

#***************************************************************************************************************
# Check if file was a filetype conversion, and accept the bigger filesize in that case
#***************************************************************************************************************
check_alternative_conversion () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

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
            printf " ${Green}Converted. $((ORIGINAL_DURATION - NEW_DURATION))sec and ${SAVESIZE} ${SIZETYPE} in $TIMERVALUE"
            SUCCESFULFILECNT=$((SUCCESFULFILECNT + 1))
            TIMESAVED=$((TIMESAVED + DURATION_CUT))
        else
            PRINT_ERROR_DATA="Duration failed ($NEW_DURATION>$DURATION_CHECK)"
        fi
        NEW_DURATION=0
        DURATION_CHECK=0
    elif [ "$EXT_CURR" == "$CONV_CHECK" ]; then
        RETVAL=11
        ERROR_WHILE_MORPH=1
        PRINT_ERROR_DATA="Conversion check (${EXT_CURR}=${CONV_CHECK})"
    elif [ "$IGNORE_UNKNOWN" == "0" ]; then
        RETVAL=12
        ERROR_WHILE_MORPH=1
        PRINT_ERROR_DATA="Unknown"
    else
        handle_file_rename 1
        check_valuetype "$(((ORIGINAL_SIZE - NEW_FILESIZE)))"
        printf "${Yellow}Warning, ignoring unknown error:$ERROR in $TIMERVALUE, saved:${SAVESIZE}${SIZETYPE}"
    fi

    if [ -n "$PRINT_ERROR_DATA" ]; then
        calculate_duration
        handle_file_rename 0
        printf "${Red} FAILED!"
        [ "$xNEW_DURATION" -gt "$xORIGINAL_DURATION" ] && printf " time:$xNEW_DURATION>$xORIGINAL_DURATION" && PRINT_ERROR_DATA=""
        [ "$xNEW_FILESIZE" -gt "$xORIGINAL_SIZE" ] &&  printf " size:$xNEW_FILESIZE>$xORIGINAL_SIZE" && PRINT_ERROR_DATA=""
        [ -n "$PRINT_ERROR_DATA" ] && printf " Reason:$PRINT_ERROR_DATA ($ERROR)"
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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    FILE_EXISTS=0
    if [ "$MASSIVE_SPLIT" == 1 ]; then  FILE_EXISTS=1
    elif [ -f "$FILE$CONV_TYPE" ]; then FILE_EXISTS=1; fi
}

#***************************************************************************************************************
# Check file handling, if size is smaller and destination file length is the same (with 2sec error marginal)
#***************************************************************************************************************
check_file_conversion () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    #if destination file exists
    check_if_files_exist
    calculate_duration

    if [ "$FILE_EXISTS" == 1 ]; then
        if [ "$AUDIO_PACK" == "1" ]; then NEW_DURATION=$(mediainfo '--Inform=Audio;%Duration%' "$FILE$CONV_TYPE")
        else                              NEW_DURATION=$(mediainfo '--Inform=Video;%Duration%' "$FILE$CONV_TYPE"); fi
        AUDIO_DURATION=$(mediainfo '--Inform=Audio;%Duration%' "$FILE$CONV_TYPE")

        NEW_FILESIZE=$(du -k "$FILE$CONV_TYPE" | cut -f1)
        DURATION_CUT=$(((BEGTIME + ENDTIME) * 1000))

        [ "$MASSIVE_SPLIT" == "0" ] && GLOBAL_TIMESAVE=$((GLOBAL_TIMESAVE + CUTTING_TIME))

        DURATION_CHECK=$((ORIGINAL_DURATION - DURATION_CUT - 2000))
        ORIGINAL_SIZE=$(du -k "$FILE" | cut -f1)
        ORIGINAL_HOLDER=$ORIGINAL_SIZE

        [ -z "$NEW_DURATION" ] && NEW_DURATION=0
        [ "$IGNORE" == "1" ] && ORIGINAL_SIZE=$((NEW_FILESIZE + 10000))

        #if video length matches (with one second error tolerance) and destination file is smaller than original, then
        if [ -z "$AUDIO_DURATION" ]; then
            handle_file_rename 0
            printf "${Red} FAILED! Target has no Audio!${Color_Off}\n"
            TOTAL_ERR_CNT=$((TOTAL_ERR_CNT + 1))
            SPLITTING_ERROR=2
            [ "$EXIT_REPEAT" -gt "0" ] && EXIT_REPEAT=$((EXIT_REPEAT + 1))
        elif [ "$NEW_DURATION" -gt "$DURATION_CHECK" ] && [ "$ORIGINAL_SIZE" -gt "$NEW_FILESIZE" ]; then
            ORIGINAL_SIZE=$ORIGINAL_HOLDER
            ENDSIZE=$((ORIGINAL_SIZE - NEW_FILESIZE))
            TOTALSAVE=$((TOTALSAVE + ENDSIZE))
            SUCCESFULFILECNT=$((SUCCESFULFILECNT + 1))
            [ "$MASSIVE_FILE_HANDLE" -le "1" ] && GLOBAL_FILECOUNT=$((GLOBAL_FILECOUNT + 1))
            [ "$MASSIVE_FILE_HANDLE" -eq "1" ] && MASSIVE_FILE_HANDLE=2
            #ENDSIZE=$((ENDSIZE / 1000))
            TIMESAVED=$((TIMESAVED + DURATION_CUT))

            if [ "$MASSIVE_SPLIT" == 1 ]; then
                printf "${Green}Success in $TIMERVALUE${Color_Off} "
            else
                #check_valuetype "$ENDSIZE"
                #printf "${Green}Saved %-6.6s ${SIZETYPE} in $TIMERVALUE${Color_Off}\n" "$SAVESIZE"
                printf "${Green}Saved %8s in %s${Color_Off}\n" "$(lib size $ENDSIZE)" "$(lib t F $process_start_time)"
            fi
            handle_file_rename 1
        else
            check_alternative_conversion
        fi
    else
        if [ "$ERROR" != 13 ]; then
            printf "${Red}No destination file!${Color_Off} in $TIMERVALUE\n"
            [ ! -d "./Nodest" ] && mkdir "Nodest"
            mv "$FILE" "./Nodest"
        fi
        remove_interrupted_files
        RETVAL=13
        [ "$EXIT_VALUE" == "1" ] && exit 1
    fi
}

#***************************************************************************************************************
# Check what kind of file handling will be accessed
#***************************************************************************************************************
handle_file_packing () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"
    [ ! -f "$FILE" ] && return

    ORIGINAL_SIZE=$(du -k "$FILE" | cut -f1)
    get_space_left

    if [ "$ORIGINAL_SIZE" -gt "$SPACELEFT" ] && [ "$IGNORE_SPACE_SIZE" -eq "0" ]; then
        printf "Not enough space left! File:$ORIGINAL_SIZE > harddrive:$SPACELEFT\n"
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
    X_WIDTH="$XP"
    Y_HEIGHT="$Y"
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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    FULL=$(df -k "${TARGET_DIR}" |grep "/")
    mapfile -t -d ' ' space_array < <(printf "%s" "$FULL")
    f_cnt=0
    SPACELEFT=0

    # Seek out the fourth column, since it's split by spaces
    for m_cnt in "${!space_array[@]}"; do
        if [ -n "${space_array[$m_cnt]}" ]; then
            f_cnt=$((f_cnt + 1))
            if [ "$f_cnt" -ge "4" ]; then
                SPACELEFT=${space_array[$m_cnt]}
                break
            fi
        fi
    done
}

#***************************************************************************************************************
# Main file handling function
#***************************************************************************************************************
pack_file () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"
    process_start_time=$(date +%s)

    [ "$FILECOUNT" == "0" ] && EXT_CURR="${FILE##*.}"
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
                printf "${Red}$FILE is not found (pack file)!${Color_Off}\n"
                ERROR=6
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
                RETVAL=14
            else
                printf "${Yellow}%11s$FILE already at desired size wanted:${WIDTH} current:${X}${Color_Off}\n" " "
            fi
        elif [ "$PRINT_ALL" == 1 ]; then
            print_info
            printf "$FILE width:$X skipping\n"
        fi
    fi
}

#***************************************************************************************************************
# Calculate time taken to process data
#***************************************************************************************************************
calculate_time_taken () {
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ -z "$1" ]; then
        TIMER_SECOND_PRINT="0"
        VAL_HAND=0
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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

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
    [ "$DEBUG_PRINT" == 1 ] && printf "${FUNCNAME[0]}\n"

    if [ "$#" -le 0 ]; then
        print_help
        EXIT_EXT_VAL=1
        exit 1
    fi
}

#***************************************************************************************************************
# The MAIN VOID function
#***************************************************************************************************************

reset_handlers
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
        parse_data "$var" "1"
        [ "$ERROR" != "0" ] && break
        CHECKRUN=$((CHECKRUN + 1))
    fi
done

if [ "$ERROR" != "0" ]; then
    printf "Something went ($file) wrong with calculation (or something else)!\n"
    RETVAL="$ERROR"

elif [ "$COMBINEFILE" == "1" ]; then
    combineFiles

elif [ "$COMBINEFILE" == "2" ]; then
    mergeFiles

elif [ "$COMBINEFILE" == "3" ]; then
    mergeFiles "append"

elif [ "$CHECKRUN" == "0" ]; then
    print_help
    RETVAL=15

elif [ "$CONTINUE_PROCESS" == "1" ]; then
    if [ "${#SUB_RUN[@]}" -gt "0" ]; then
        reset_handlers
        for var in "${SUB_RUN[@]}"; do parse_data "$var"; done
        [ "$ERROR" == "0" ] && handle_sub_files
    fi

    if [ "${#CROP_RUN[@]}" -gt "0" ]; then
        reset_handlers
        for var in "${CROP_RUN[@]}"; do parse_data "$var"; done
        [ "$ERROR" == "0" ] && handle_filesize_change
    fi

    if [ "${#PACK_RUN[@]}" -gt "0" ] && [ "${ERROR}" == "0" ]; then
        reset_handlers
        for var in "${PACK_RUN[@]}"; do parse_data "$var"; done
        if [ "$CUTTING" -eq "0" ]; then
            for var in "${CUT_RUN[@]}"; do parse_data "$var"; done
            CUT_RUN=()
        fi
        [ "$ERROR" == "0" ] && handle_filesize_change
    fi

    if [ "${#CUT_RUN[@]}" -gt "0" ] && [ "${ERROR}" == "0" ]; then
        reset_handlers
        for var in "${CUT_RUN[@]}"; do parse_data "$var"; done
        if [ "${SPLIT_AND_COMBINE}" == "0" ] && [ "${MASS_SPLIT}" == "0" ] && [ "$ERROR" == "0" ]; then handle_cuttings; fi
    fi

    if [ "${#CUT_RUN[@]}" -eq "0" ] && [ "${#PACK_RUN[@]}" -eq "0" ] && [ "${#SUB_RUN[@]}" -eq "0" ]; then
        [ "$ERROR" == "0" ] && handle_filesize_change
    fi

    if [ "$CURRENTFILECOUNTER" -gt "1" ]; then print_total
    else GLOBAL_FILESAVE=$((GLOBAL_FILESAVE + TOTALSAVE)); fi
else
    printf "${Red}No file(s) found!${Color_Off}\n"
    ERROR=8
    RETVAL=16
fi

[ "$MASSIVE_TIME_SAVE" -gt "0" ] && GLOBAL_TIMESAVE=$((GLOBAL_TIMESAVE + (ORIGINAL_DURATION / 1000) - MASSIVE_TIME_SAVE))

[ "$NO_EXIT_EXTERNAL" == "0" ] && exit "$RETVAL"
