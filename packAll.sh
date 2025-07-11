#!/bin/bash

SCRUB=0                         # Instead of rm, use scrub, if this is set

WORKMODE=4                      # Workmode handler (which part is to be split)
WORKNAME=""                     # Workmode string
TOTALSAVE=0                     # Totally saved size

FILECOUNT=0                     # Number of files to be handled
CURRENTFILECOUNTER=0            # Currently processed file number
MISSING=0                       # File existance checker
SUCCESFULFILECNT=0              # Number of successfully handled files
START_POSITION=0                # File to start handling from
END_POSITION=0                  # File where to no longer handle files

EXT_CURR=""                     # Current files extension
CONV_TYPE=".mp4"                # Target filetype
CONV_CHECK="mp4"                # Target filetype extension handler
MP3OUT=0                        # Extract mp3 data, if set
AUDIO_PACK=0                    # Pack input file into target audio
WAV_OUT=0                       # extract wav from video

CALCTIME=0                      # Global variable to handle calculated time in seconds
IGNORE=0                        # Ignore bigger target file size
IGNORE_SPACE=0                  # Ignore space warning and proceed to next file
IGNORE_SPACE_SIZE=0             # Ignore too little space warning
TIMESAVED=0                     # Time cut out from modifying videos

CHECKRUN=0                      # Verificator of necessary inputs
CONTINUE_PROCESS=0              # If something went wrong, or file was split into multiple files, don't continue process
KEEPORG=0                       # If set, will not delete original file after success
KEEP_ORG=0                      # Value handler for original value

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
PRINTSIZE=0                     # Info printout size
PRINTLENGTH=0                   # Info printout time

DEBUG_PRINT=0                   # Print function name in this mode
DEBUG_FILE="pack_debug.txt"     # Debug output file
MASSIVE_TIME_SAVE=0             # Save each split total to this handler
MASSIVE_COUNTER=0               # Counter of multisplit items handled

MASSIVE_TIME_CHECK=0            # Wanted total time of output files
MASSIVE_TIME_COMP=0             # Actual total time of output files
SPLIT_MAX=0                     # Number of files input is to be split into
SUBERR=0                        # Subfile error checker
PIDOF=0                         # Current running pid of ffmpeg

script_start_time=$(date +%s)   # Time in seconds, when the script started running
process_start_time=$(date +%s)  # Time in seconds, when processing started

RETVAL=0                        # If everything was done as expected, is set to 0
SPACELEFT=0                     # Target directory drive space left
SIZETYPE="Mb"                   # Saved size type
SAVESIZE=0                      # Calculated value of size saved
ERROR_WHILE_MORPH=0             # Conversion error handler
SPLITTER_TIMESAVE=0             # Time saved during splitting
LOOPSAVE=0                      # Loop save size

APP_NAME="/usr/bin/ffmpeg"      # current application file to be used
APP_STRING="ffmpeg"             # current application name

COMBINELIST=()                  # combine file list
COMBINEFILE=0                   # variable for combining files handler
PACK_RUN=()                     # packing variables
CUT_RUN=()                      # Cutting variables
SUB_RUN=()                      # subtitle handling options
CROP_RUN=()                     # cropping handling options
MASS_RUN=()                     # massive split and/or combo handlers
SKIPLIST=()                     # list of string in filename to skip
NAME_RUN=()                     # Items for renaming functionalities

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
filename=""                     # Current filename without extension
PRINTLINE=""                    # Status output string handler
PACKLEN=61                      # Length of packloop base printout
NO_CODEC=0                      # If enabled, won't use codecs
save_written=false              # Indicator if the final situation was changed already
LANGUAGE="en"                   # Wanted audiotrack language

RND_VAL="$(more /dev/urandom | tr -cd 'a-f0-9' | head -c 32)"   # Create a random string to avoid possible collisions
[ -z "${GLOBAL_TIMESAVE}" ] && export GLOBAL_TIMESAVE=0
[ -z "${GLOBAL_FILESAVE}" ] && export GLOBAL_FILESAVE=0

SIZEFILE="/tmp/packsave.txt"             # Temporary file to hold the latest interrupted sizesave
PACKFILE="/tmp/ffmpeg_${RND_VAL}.txt"    # Temporary file to handle output for non-blocking run
RUNFILE="/tmp/pack_run.txt"              # Indicator that app is currently running
COMBOFILE="packcombofile_${RND_VAL}.txt" # Target combination filename
CUTTING=0                                # If any cutting is being done, set this value
SPLIT_TIME=0                             # Indicator if the pid looper is running for splitting
export RUNTIMES=0                        # Indicator of how many different processes were done to the same one file
CUTTING_TIME=0                           # Initial time that is to be cut from a file
CROP_HAPPENED=0                          # Indicator if file was already cropped

export PROCESS_INTERRUPTED=0    # Interruption handler for external access
export ERROR=0                  # Global error indicator
export EXIT_EXT_VAL             # External exit value handler

#***************************************************************************************************************
# Reset all runtime handlers
# 1 - possible command from where this was called
#***************************************************************************************************************
reset_handlers() {
    debug_print

    TARGET_DIR="."                  # Target directory for successful file
    NEWNAME=""                      # New target filename, if not set, will use input filename
    FETCHURL=""                     # If set, will try to find name from url
    DELIMITER=""                    # Delimiter to split the filename into pieces with splitting function
    COMMAND_LINE=()                 # command line options to be set up later
    FAILED_FUNC=""                  # Indicator of the function, where error happened

    # Don't reset everything if renaming is up
    if [ "${1}" == "rename" ]; then return; fi

    MASSIVE_SPLIT=0                 # Splitting one file into multiple files
    SPLIT_AND_COMBINE=0             # If set, will combine a new file from splitted files
    MASS_SPLIT=0                    # Mass split enabled handler
    MASS_SPLIT_VALUE=""             # Handler for mass split value
    CUTTING_INDICATOR=0             # Timer split size handler
    COMBINE_RUN_COUNT=0             # Combined items running counter
    RUNNING_FILENAME=""             # Running numbered filename handler
    DIMENSION_PARSED=0              # Handler to tell if the dimension was already parsed
    REPACK=0                        # Repack file instead of changing dimensions
    REPACK_GIVEN=0                  # Repack value holder
    COPY_ONLY=1                     # Don't pack file, just copy data
    CROP=""                         # Crop video handler
    BEGTIME=0                       # Time where video should begin
    ENDTIME=0                       # Time where video ending is wanter
    VIDEOTRACK=""                   # Videotrack number
    AUDIOTRACK=""                   # Audiotrack number
    ENDPOINT=0                      # Point where to stop instead of time from the end
    SUBFILE=""                      # Path to subtitle file to be burned into target video
    WIDTH=0                         # Width of the video
    VAL_HAND=0                      # Splitting timer value handler
    LANGUAGE_SELECTED=""            # If language is selected, this will be used
    DELETE_AT_END=1                 # Variable to indicate, if file is to be deleted at the end
    [ "$KEEPORG" == "1" ] && DELETE_AT_END=0
    MASSIVE_ENDSIZE=0               # Size of the splitted files combined
    c_col=0                         # Print starting position handlers
    #c_row=0;
}

# If this value is not set, external program is not accessing this and exit -function will be used normally
[ -z "$NO_EXIT_EXTERNAL" ] && NO_EXIT_EXTERNAL=0

#***************************************************************************************************************
# Define regular colors for printout
#***************************************************************************************************************
CR=$(tput setaf 1)   # Red
CG=$(tput setaf 10)  # Green
CY=$(tput setaf 11)  # Yellow
CB=$(tput setaf 14)  # Blue
C13=$(tput setaf 13) # Purple
CP=$(tput setaf 5)   # Magenta
CC=$(tput setaf 6)   # Cyan
CT=$(tput setaf 9)   # Orange
CO=$(tput sgr0)      # Color off

#***************************************************************************************************************
# Print or log debugging info
# @ - additional info, otherwise
#***************************************************************************************************************
debug_print() {
    [ "${DEBUG_PRINT}" -eq "0" ] && return

    if [ "${DEBUG_PRINT}" -eq "1" ]; then printf "FUNC:%s '%s'\n" "${FUNCNAME[1]}" "${*}" >> "$DEBUG_FILE"
    else printf "FUNC:%s '%s'\n" "${FUNCNAME[1]}" "${*}"; fi
}

#***************************************************************************************************************
# Update number of chars in row and print the row empty
#***************************************************************************************************************
clear_column() {
    TL=$(tput cols)      # Number of chars in current bash column
    ((TL--))
    [ "${TL}" -gt "194" ] && TL=194
    printf "\r%${TL}s" " "
}

#***************************************************************************************************************
# Change printout type to corrent
#***************************************************************************************************************
check_valuetype() {
    debug_print

    SAVESIZE=0; SIZETYPE="kb"; HAND_VAL="$1"; COUT="${CG}"

    [ -z "$1" ] && return
    [ "$1" -lt "0" ] && HAND_VAL=$((HAND_VAL * -1)) && COUT="${CR}"

    if [ "$HAND_VAL" -lt "1000" ]; then      SIZETYPE="kb"; SAVESIZE="$1"
    elif [ "$HAND_VAL" -lt "1000000" ]; then SIZETYPE="Mb"; SAVESIZE=$(bc <<<"scale=2; $1 / 1000")
    else                                     SIZETYPE="Gb"; SAVESIZE=$(bc <<<"scale=2; $1 / 1000000"); fi

    printf "%s%s%s%s" "${COUT}" "$SAVESIZE" "$SIZETYPE" "${CO}"
}

#***************************************************************************************************************
# Print total handled data information
#***************************************************************************************************************
print_total() {
    debug_print

    ((GLOBAL_FILESAVE += TOTALSAVE))
    #TOTALSAVE=$((TOTALSAVE / 1000))

    if [ "$PRINT_INFO" -ge "1" ]; then
        TIMESAVED=$(date -d@${TIMESAVED} -u +%T)
        printf "Total in %s files, Size:%s Length:%s\n" "$CURRENTFILECOUNTER" "$(check_valuetype "$TOTALSAVE")" "$TIMESAVED"
    else
        update_saved_time

        if [ "$COPY_ONLY" == 0 ] || [ "$TIMESAVED" -gt "0" ]; then
             printf "Totally saved %s " "$(check_valuetype "$TOTALSAVE")"
             [ "$TIMESAVED" -gt "0" ] && printf "%s " "$(calc_giv_time "$TIMESAVED")"
             printf "on %s files %sin %s%s\n" "$SUCCESFULFILECNT" "$CC" "$(calc_time_tk)" "$CO"
        elif [ -n "$SUBFILE" ]; then
             printf "Burned subs to %s files (size change: %s) %sin %s%s\n" "$SUCCESFULFILECNT" "$(check_valuetype "$TOTALSAVE")" "$CC" "$(calc_time_tk)" "$CO"
        else printf "Handled %s files to %s (size change:%s) %sin %s%s\n" "$SUCCESFULFILECNT" "$CONV_CHECK" "$(check_valuetype "$TOTALSAVE")" "$CC" "$(calc_time_tk)" "$CO"; fi

        [ "$MISSING" -gt "0" ] && printf "Number of files disappeared during process: %s\n" "$MISSING" && RETVAL=17
    fi
}

#***************************************************************************************************************
# Remove incomplete destination files
#***************************************************************************************************************
remove_interrupted_files() {
    debug_print

    [ -f "${FILE}${CONV_TYPE}" ] && delete_file "${FILE}${CONV_TYPE}" "22"
    [ -f "${NEWNAME}" ]          && delete_file "${NEWNAME}" "25"
}

#***************************************************************************************************************
# Write latest save information to temp file
#***************************************************************************************************************
save_sizefile() {
    if ${save_written}; then return; fi

    {
        printf "time=%s\n" "$(date +%s)"
        if [ "${GLOBAL_FILESAVE}" -gt "0" ]; then printf "size=%s\n" "${GLOBAL_FILESAVE}"
        else printf "size=%s\n" "${TOTALSAVE}"; fi

        if [ "${GLOBAL_TIMESAVE%.*}" -gt "0" ]; then printf "timesave=%s\n" "${GLOBAL_TIMESAVE%.*}"
        else printf "timesave=%s\n" "${TIMESAVED}"; fi

    } >"${SIZEFILE}"

    save_written=true
}

#***************************************************************************************************************
# Read possible previously save information from file, if less than 30min has passed
#***************************************************************************************************************
read_sizefile() {
    [ -z "${GLOBAL_FILESAVE}" ] && GLOBAL_FILESAVE=0
    [ -z "${GLOBAL_TIMESAVE}" ] && GLOBAL_TIMESAVE=0
    if [ ! -f "${SIZEFILE}" ] || [ "${GLOBAL_FILESAVE}" -gt "0" ] || [ "${GLOBAL_TIMESAVE}" -gt "0" ] ; then return; fi

    read_size=false; nowtime="$(date +%s)"; printtime=false

    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [[ "${line}" == "time="* ]]; then
            thentime="$(printf "%s" "${line##*=}" | xargs)"
            if [[ "$((nowtime - thentime))" -lt "1800" ]]; then
                read_size=true
                if [[ "$((nowtime - thentime))" -gt "120" ]]; then printtime=true; fi
            fi
        fi

        if [[ "${line}" == "size="* ]] && ${read_size}; then GLOBAL_FILESAVE="$(printf "%s" "${line##*=}" | xargs)"
        elif [[ "${line}" == "timesave="* ]] && ${read_size}; then GLOBAL_TIMESAVE="$(printf "%s" "${line##*=}" | xargs)"
        fi

    done < "${SIZEFILE}"

    if ${printtime}; then printf "Loaded previous data size:%s time:%s\n" "$(check_valuetype "$GLOBAL_FILESAVE")" "$(calc_giv_time "$GLOBAL_TIMESAVE")" ; fi
    if ${printtime} || [ -n "${URL_DATA}" ]; then printf "\n"; fi
    delete_file "${GLOBAL_FILESAVE}" "199"
}

#***************************************************************************************************************
#If SYS_INTERRUPTted, stop process, remove files not complete and print final situation
#***************************************************************************************************************
set_int() {
    printf "%s" "${CO}"
    debug_print

    mapfile CHECKLIST <<<"$(pgrep -f $APP_STRING)"
    mapfile -t -d ' ' PIDLIST <<<"$(pidof ${APP_NAME})"
    [ "${#CHECKLIST[@]}" -gt "1" ] && [ "$PRINT_INFO" -eq "0" ] && [ -z "${wait_start}" ] && killall -s 9 "${PIDLIST[@]}"
    [ "${PIDOF}" != "0" ] && wait ${PIDOF} 2>/dev/null
    PROCESS_INTERRUPTED=1
    shopt -u nocaseglob
    printf "\n%s%s conversion interrupted %s%s!%s\n" "$(print_info)" "$CR" "$CC" "$(calc_dur)" "$CO"
    EXIT_EXT_VAL=1
    ERROR=66

    [ -f "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" ] && delete_file "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" "26"

    [ "${MASSIVE_TIME_SAVE%.*}" -gt "0" ] && ((GLOBAL_TIMESAVE =+ (ORIGINAL_DURATION / 1000) - ${MASSIVE_TIME_SAVE%.*}))

    if [ "$NO_EXIT_EXTERNAL" -ne "0" ]; then
        [ "$SPLITTER_TIMESAVE" -gt "0" ] && SPLITTER_TIMESAVE=$(((ORIGINAL_DURATION - SPLITTER_TIMESAVE) / 1000))
        printf "Globally saved %s and removed time:%s\n" "$(check_valuetype "$GLOBAL_FILESAVE")" "$(calc_giv_time "$((GLOBAL_TIMESAVE + SPLITTER_TIMESAVE))")"
    else
        print_total
    fi
    save_sizefile

    [ "$PRINT_INFO" -eq "0" ] && temp_file_cleanup "1"
}

trap set_int SIGINT SIGTERM

#**************************************************************************************************************
# Print script functional help
#***************************************************************************************************************
print_help() {
    debug_print

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
    printf "s(crub)      -    original on completion\n"
    printf "crop         -    crop black borders automatically\n"
    printf "crop=        -    crop black borders with given values X-right:Y-bottom:pixels from left:pixels from top or width-pixels:height-pixels\n\n"
    printf "sub=         -    subtitle file to be burned into video, or the number of the wanted embedded subtitle track (starting from 0), or self:SUB_EXT\n"
    printf "w(rite)=     -    Write printing output to file\n"
    printf "n(ame)=      -    Give file a new target name (without file extension)\n"
    printf "N=           -    Split filename with delimiter when using c= -option\n"
    printf "url=         -    Rename file by data read from given url\n"
    printf "T(arget)=    -    Target directory for the target file\n\n"
    printf "c(ut)=       -    time where to cut,time where to cut next piece,next piece,etc\n"
    printf "c(ut)=       -    time to begin - time to end,next time to begin-time to end,etc\n"
    printf "C(ombine)=   -    same as cutting with begin-end, but will combine split videos to one\n"
    printf "             -    When setting cut or Combine, adding D as the last point, will delete the original file if successful\n\n"
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
    printf "l(anguage)   -    Wanted output audio language with two letters, default:en\n"
    printf "skip=        -    Skip files with given string in the filename, separate multiple with ;\n\n"
    printf "example:     %s \"FILENAME\" 640x c=0:11-1:23,1:0:3-1:6:13,D\n" "${0}"
}

#*************************************************************************************************************
# Get current cursor position
#*************************************************************************************************************
get_cursor_position() {
    exec < /dev/tty
    savedtty=$(stty -g)

    stty raw -echo min 0
    echo -en "\e[6n" > /dev/tty
    IFS=';' read -r -d R -a rawpos
    stty "$savedtty"

    #c_row=${rawpos[0]:2}  # Remove the leading 'ESC['
    c_col=${rawpos[1]}
    t_cols="$(tput cols)"; t_cols=$(((t_cols / 3) * 2))
    re='^[0-9]+$'
    if [[ ! "${c_col}" =~ $re ]] ; then c_col="${PACKLEN}"; fi
    if [[ "${c_col}" -ge "${t_cols}" ]]; then c_col="${t_cols}"; fi
}

#*************************************************************************************************************
# Print information to last read position, or to a given position
# 1 - String to print
# 2 - alternative row number
# 3 - alternative column position
#*************************************************************************************************************
print_last_pos() {
    [ -z "${c_col}" ] && c_col=0
    if [ "${c_col}" -le "0" ]; then get_cursor_position; fi
    last_row="$(tput lines)"

    if [ -n "${2}" ] && [ -n "${3}" ]; then printf "%s\33[%d;%dH" "${1}" "${2}" "${3}"
    else                                    printf "%s\33[%d;%dH" "${1}" "${last_row}" "${c_col}"; fi
}

#*************************************************************************************************************
# See if given filename is in the skiplist
# 1 - Filename string
#*************************************************************************************************************
check_fileskip() {
    SKIPTRUE=0
    [ -z "${1}" ] && return

    for skip in "${SKIPLIST[@]}"; do
        if [[ "${1,,}" == *"${skip,,}"* ]] || [[ "${1,,}" == *".part" ]]; then
            SKIPTRUE=1
            break
        fi
    done
}

#*************************************************************************************************************
# Find image position in a video
# 1 - Video file
# 2 - Image file
# 3 - first or last
#**************************************************************************************************************
find_image_pos() {
    debug_print

    [[ ! "$APP_STRING" =~ "ffmpeg" ]] && printf "Can't seek images without ffmpeg!\n" && temp_file_cleanup "1"
    debug_print "Seeking time from '$1' by '$2'"

    ((RUNTIMES++))
    IMAGEPOS=$($APP_NAME -i "$1" -r 1 -loop 1 -i "$2" -an -filter_complex "blend=difference:shortest=1,blackframe=99:32,metadata=print:file=-" -f null -v quiet -)
    IMAGETIME=$(printf "%s" "$IMAGEPOS" |grep "blackframe" -m 1)
    if [ -z "$3" ]; then IMAGETIME="${IMAGEPOS#*pts_time:}"
    else IMAGETIME="${IMAGEPOS##*pts_time:}"; fi

    IMAGETIME="${IMAGETIME%%.*}"

    debug_print " image at:$IMAGETIME"
}

##########################################################################################
# Calculate estimated total time
# 1 - current time
##########################################################################################
calculate_estimated_read_time() {
    ((AVG_CNT++))
    AVG_MID=$(bc <<< "scale=3;(${1} / $AVG_CNT)")
    AVG_EST=$(bc <<< "scale=0;($MAX_ROWS / $AVG_MID)")
}

#**************************************************************************************************************
# Get all different crop values, remove repeated values from list for quicker handling
#**************************************************************************************************************
get_diff_for_crop() {
    DATA_OUTPUT=$(awk -F'crop=' '
    {
        split($2, a, /[ \t]/);   # Get the value after crop= and split at whitespace
        if (a[1] != last) {
            print;
            last = a[1];
        }
    }
    ' "$PACKFILE")

    mapfile -t CROP_ARRAY< <(printf "%s" "${DATA_OUTPUT}")
}

#**************************************************************************************************************
# Read crop data from ffmpeg outputfile and get the biggest dimension data
#**************************************************************************************************************
read_biggest_crop_resolution() {
    debug_print

    get_diff_for_crop
    MAX_ROWS="${#CROP_ARRAY[@]}"; X_MAX=0; Y_MAX=0; CROP_DATA=""; LAST_DIFFER=0; CURR_ROW=1; SEEK_START=$(date +%s); AVG_CNT=0; AVG_EST=0

    for c_info in "${CROP_ARRAY[@]}"; do
        [ "${PROCESS_INTERRUPTED}" -eq "1" ] && break
        DIFFER=$(($(date +%s) - SEEK_START))
        if [[ "$c_info" == *"crop="* ]]; then
            read_data="${c_info##*crop=}"
            mapfile -t -d ':' CROP_POINT < <(printf "%s" "$read_data")
            if [ "$X_MAX" -lt "${CROP_POINT[0]}" ] || [ "$Y_MAX" -lt "${CROP_POINT[1]}" ]; then
                X_MAX="${CROP_POINT[0]}"; Y_MAX="${CROP_POINT[1]}"; CROP_DATA="$read_data"
            fi
        fi

        if [ "$DIFFER" != "$LAST_DIFFER" ]; then
            calculate_estimated_read_time "${CURR_ROW}"
            printf "%s Searching best crop resolution %s %s%s/%s row:%d/%d%s\r" "$(print_info)" "${CROP_DATA}" "$CB" "$(date -d@${DIFFER} -u +%T)" "$(calc_giv_time "${AVG_EST}")" "$CURR_ROW" "$MAX_ROWS" "$CO"
        fi
        ((CURR_ROW++))
        LAST_DIFFER="$DIFFER"
    done

    delete_file "$PACKFILE" "29"
    clear_column
    printf "\r%s Searching best crop resolution -> found:%s%s %s%s%s\n" "$(print_info)" "$CY" "$CROP_DATA" "$CC" "$(calc_dur)" "$CO"
}

#**************************************************************************************************************
# Verify cropping data is valid
# 1 - cropping string
# 2 - original x value
# 3 - original y value
#**************************************************************************************************************
verify_crop_information() {
    CROP_ERR=""; ORGX="${2}"; ORGY="${3}"
    if [ "${IGNORE}" -ne "0" ]; then return; fi

    mapfile -t -d ':' CUT < <(printf "%s" "${1}")

    if [ "${#CUT[@]}" -eq "2" ]; then
        if [ "${CUT[0]}" -eq "0" ] && [ "${CUT[1]}" -eq "0" ]; then CROP_ERR="No crop data found from ${1}!"; return; fi
    elif [ "${#CUT[@]}" -eq "4" ]; then
        if [ "${CUT[2]}" -eq "0" ] && [ "${CUT[3]}" -eq "0" ]; then CROP_ERR="No crop data found from ${1}!"; return; fi
    else
        CROP_ERR="Invalid crop data ${1}"; return
    fi

    if [ "${CROP}" == "seek" ]; then return; fi

    if [ "${#CUT[@]}" -eq "2" ]; then CA=("$((ORGX - (2 * CUT[0])))" "$((ORGY - (2 * CUT[1])))" "${CUT[0]}" "${CUT[1]}" )
    elif [ "${#CUT[@]}" -ne "4" ]; then CROP_ERR="Uncompatible data '${1}'"; return
    elif { [ "${CUT[2]}" -gt "0" ] || [ "${CUT[3]}" -gt "0" ]; } && [ "${CROP}" != "seek" ];  then
        if [ "${CUT[0]}" -eq "${ORGX}" ] && [ "${CUT[1]}" -eq "${ORGY}" ]; then CA=("$((ORGX - (2 * CUT[2])))" "$((ORGY - (2 * CUT[3])))" "${CUT[2]}" "${CUT[3]}")
        else CA=("${CUT[@]}"); fi
    else CROP_ERR="Uncompatible data '${1}'"; fi

    if [ -z "${CROP_ERR}" ] && [ "${IGNORE}" -eq "0" ]; then
        if [ "${CA[0]}" -lt "100" ] || [ "${CA[1]}" -lt "100" ] || { [ "${CA[2]}" -eq "0" ] && [ "${CA[3]}" -eq "0" ]; }; then CROP_ERR="End file too small ${CA[*]}"
        else CROP_DATA="${CA[*]}"; CROP_DATA="${CROP_DATA// /:}"; fi
    fi
}

#**************************************************************************************************************
# If cropped but also has cutout time, get the best time from beginning to end
#**************************************************************************************************************
get_possible_cutout_range() {
    for var in "${CUT_RUN[@]}"; do parse_data "$var"; done

    if [ -n "${MASS_SPLIT_VALUE}" ]; then
        mapfile -t -d ',' split_array < <(printf "%s" "${MASS_SPLIT_VALUE}")
        mapfile -t -d '-' start_array < <(printf "%s" "${split_array[0]}")
        LAST_ITEM="${#split_array[@]}"; ((LAST_ITEM--))
        [ "${split_array[LAST_ITEM]}" == "D" ] && ((LAST_ITEM--))
        mapfile -t -d '-' end_array < <(printf "%s" "${split_array[LAST_ITEM]}")

        COMMAND_LINE+=("-ss" "${start_array[0]}")
        if [ -n "${end_array[1]}" ]; then COMMAND_LINE+=("-to" "${end_array[1]}")
        else COMMAND_LINE+=("-to" "${end_array[0]}"); fi
    else
        if [ "${BEGTIME}" -gt "0" ]; then COMMAND_LINE+=("-ss" "${BEGTIME}"); fi

        if [ "${ENDTIME}" -gt "0" ]; then
            DUR=$((ORIGINAL_DURATION / 1000))
            ENDO=$(bc <<< "scale=2;(${DUR} - ${ENDTIME} - ${BEGTIME})")
            COMMAND_LINE+=("-t" "${ENDO}")
        fi
    fi
}

#**************************************************************************************************************
# Crop out black borders (this needs more work, kind of hazard at the moment.
#***************************************************************************************************************
check_and_crop() {
    debug_print

    if [ "$SPLIT_AND_COMBINE" -eq "1" ] && [[ ! "$APP_STRING" =~ "ffmpeg" ]]; then
        printf "%s %s Cannot crop files with %s%s%s aborting!%s\n" "$(print_info)" "$CR" "$CY" "$APP_STRING" "$CR" "$CO"
        temp_file_cleanup "1"
    fi

    [ "$BUGME" -eq "1" ] && printf "\n    %s%s -i \"%s\" -vf cropdetect -f null%s\n" "$CP" "$APP_STRING" "$FILE" "$CO"

    if [ "${CROP}" == "seek" ] || [ "${CROP}" == "print" ]; then
        PRINTLINE="$(print_info) Reading crop data "
        COMMAND_LINE=("-vf" "cropdetect" "-f" "null")

        if [ "${#CUT_RUN[@]}" -gt "0" ]; then get_possible_cutout_range; fi
        run_pack_app
        printf "%sdone %s%s%s\n" "$CG" "$CC" "$(calc_dur)" "$CO"
        read_biggest_crop_resolution
    else
        CROP_DATA="${CROP}"
    fi

    [ "${PROCESS_INTERRUPTED}" -eq "1" ] && return

    if [ "${CROP}" == "print" ]; then
        printf "%s Read crop data: %s\n" "$(print_info)" "${CROP_DATA}"
        verify_crop_information "${CROP_DATA}" "${XC}" "${YC}"
        printf "%s Re-calculated crop data: %s\n" "$(print_info)" "${CROP_DATA}"
    elif [ -n "$CROP_DATA" ]; then
        XC=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        YC=$(mediainfo '--Inform=Video;%Height%' "$FILE")

        if [ -n "$XC" ] && [ -n "$YC" ]; then
            verify_crop_information "${CROP_DATA}" "${XC}" "${YC}"

            if [ -z "${CROP_ERR}" ]; then
                PRINTLINE="$(printf "%s Cropping black borders (%sx%s->%s) " "$(print_info)" "$XC" "$YC" "${CROP_DATA}")"
                [ "$BUGME" -eq "1" ] && printf "\n    %s%s -i \"%s\" -vf \"%s\"%s\n" "$CP" "$APP_STRING" "$FILE" "$CROP_DATA" "$CO"
                COMMAND_LINE=("-vf" "crop=$CROP_DATA")
                run_pack_app
                check_file_conversion
                delete_file "$PACKFILE" "30"
                [ "$ERROR" -eq "0" ] && FILE="${filename}${CONV_TYPE}"
            else
                ERROR="57"; FAILED_FUNC="${FUNCNAME[0]}"
                printf "%s%s Crop error:%s %s%s\n" "$CC" "$(print_info)" "${CROP_ERR}" "$(calc_dur)" "$CO"
            fi
        fi
    else
        printf "%s%s Cropping data not found, skipping!%s" "$(print_info)" "$CR" "$CO"
    fi
}

#**************************************************************************************************************
# Check WORKMODE for removing time data
#***************************************************************************************************************
check_workmode() {
    debug_print
    if [ -z "${BEGTIME}" ] || [ -z "${ENDTIME}" ]; then return; fi

    WORKNAME=""
    if [ "$BEGTIME" != "D" ]; then
        if [ "${BEGTIME%.*}" -gt 0 ] && [ "${ENDTIME%.*}" -gt 0 ]; then      WORKMODE=3; WORKNAME="mid"
        elif [ "${BEGTIME%.*}" -gt 0 ] && [ "${ENDPOINT%.*}" -gt 0 ]; then   WORKMODE=3; WORKNAME="mid"
        elif [ "${BEGTIME%.*}" -gt 0 ]; then                                 WORKMODE=1; WORKNAME="beg"
        elif [ "${ENDTIME%.*}" -gt 0 ] || [ "${ENDPOINT%.*}" -gt 0 ]; then   WORKMODE=2; WORKNAME="end"; fi
    fi
}

#***************************************************************************************************************
# Get file duration
# 1 - filename
# 2 - if set as 1, get audio length
# 3 - if set, will also divide by 1000
#***************************************************************************************************************
get_file_duration() {
    if [ -n "$2" ] && [ "$2" == "1" ]; then FDUR=$(mediainfo '--Inform=Audio;%Duration%' "$1")
    else FDUR=$(mediainfo '--Inform=Video;%Duration%' "$1"); fi
    [[ "$FDUR" == *"."* ]] && FDUR="${FDUR%%.*}"
    [ -n "$3" ] && FDUR=$((FDUR / 1000))
    printf "%s" "$FDUR"
}

#***************************************************************************************************************
# Check if given value starts with a 0 and remove it
# 1 - Value to be verified and modified
#***************************************************************************************************************
check_zero() {
    debug_print

    ZERORETVAL="$1"; ttime="${1:0:1}"
    [ -n "$ttime" ] && [ "$ttime" == "0" ] && ZERORETVAL="${1:1:1}"
    printf "%s" "$ZERORETVAL"
}

#**************************************************************************************************************
# Delete file / scrub file
# 1 - path to filename
# 2 - track to source
#***************************************************************************************************************
delete_file() {
    debug_print "'$1' src:$2"

    if [ -f "$1" ]; then
        if [ "$SCRUB" == "1" ]; then   scrub -r "$1" >/dev/null 2>&1
        elif [ "$SCRUB" == "2" ]; then scrub -r "$1"
        else                           rm -fr "$1"; fi
    fi
}

#**************************************************************************************************************
# If splitting breaks, remove broken files
#**************************************************************************************************************
remove_broken_split_files() {
    debug_print

    make_running_name "-"

    if [ -f "${TARGET_DIR}/$RUNNING_FILENAME" ]; then
        delete_file "${TARGET_DIR}/$RUNNING_FILENAME" "1"
        while true; do
            make_running_name "+"
            [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ] && break
            delete_file "${TARGET_DIR}/$RUNNING_FILENAME" "2"
        done
    fi
}

#**************************************************************************************************************
# Check that the timelength matches with the destination files from splitting
#***************************************************************************************************************
massive_filecheck() {
    debug_print

    if [ "$ERROR_WHILE_SPLITTING" != "0" ] || [ "$ERROR_WHILE_MORPH" != "0" ]; then
        printf "%sSomething went wrong with splitting %s%s\n" "$CR" "$FILE" "$CO"
        RETVAL=18
        remove_broken_split_files
        return
    fi

    MASSIVE_TIME_COMP=0; RUNNING_FILE_NUMBER=0; MASSIVE_SIZE_COMP=0; TOO_SMALL_FILE=0

    while [ "$RUNNING_FILE_NUMBER" -lt "$SPLIT_MAX" ]; do
        make_running_name "+"
        if [ -f "${TARGET_DIR}/${RUNNING_FILENAME}" ]; then
            CFT=$(get_file_duration "${TARGET_DIR}/${RUNNING_FILENAME}")
            ((MASSIVE_TIME_COMP += CFT))
            MSC=$(du -k "${TARGET_DIR}/$RUNNING_FILENAME" | cut -f1)
            [ "$MSC" -lt "3000" ] && ((TOO_SMALL_FILE++))
            ((MASSIVE_SIZE_COMP += MSC))
        else
            break
        fi
    done

    if [ "$IGNORE" -ne "0" ] || [ "$SPLIT_AND_COMBINE" -ne "0" ]; then TOO_SMALL_FILE=0; fi
    TIME_SHORTENED=$(((ORIGINAL_DURATION - MASSIVE_TIME_COMP) / 1000))

    if [ "$SPLIT_AND_COMBINE" -eq "1" ] && [ -n "$MAX_SHORT_TIME" ] && [ "$TIME_SHORTENED" -gt "$MAX_SHORT_TIME" ]; then
        printf "%sCutting over max-time:%s > %s, aborting!%s\n" "$CR" "$(lib t f "${TIME_SHORTENED}")" "$(lib t f "${MAX_SHORT_TIME}")" "$CO"
        RETVAL=19
    elif [ "$MASSIVE_TIME_COMP" -ge "${MASSIVE_TIME_CHECK%.*}" ] && [ "$TOO_SMALL_FILE" == "0" ] && [ "$SPLITTING_ERROR" == "0" ]; then
        if [ "$KEEPORG" == "0" ] && [ "$ERROR_WHILE_MORPH" == "0" ]; then
            ((SPLITTER_TIMESAVE += MASSIVE_TIME_COMP))
            OSZ=$(du -k "$FILE" | cut -f1)
            [ "$ERROR_WHILE_SPLITTING" == "0" ] && delete_file "$FILE" "3"
            ((OSZ -= MASSIVE_SIZE_COMP))
            [ "$SPLIT_AND_COMBINE" -eq "0" ] && printf "%s %sSaved %s and %s with splitting%s\n" "$(print_info)" "$CT" "$(check_valuetype "$OSZ")" "$(calc_giv_time "$TIME_SHORTENED")" "$CO"
            ((GLOBAL_FILESAVE += OSZ))
        fi
    else
        printf "%sSomething wrong with cut-out time (%s < %s) Small files: %s%s\n" "$CR" "$MASSIVE_TIME_COMP" "$MASSIVE_TIME_CHECK" "$TOO_SMALL_FILE" "$CO"
        RETVAL=20
    fi
}

#***************************************************************************************************************
# Set and check beginning and ending time
# 1 - beginning time
# 2 - ending time
# 3 - full file length
#***************************************************************************************************************
set_beg_end() {
    debug_print

    BEGTIME="$(calculate_time "${1}")"
    verify_time_position "$3" "$BEGTIME" "Beginning massive time pos:$COMBOARRAYPOS"
    [ "$ERROR" != "0" ] && return
    ENDTIME=$(calculate_time "${2}")
    verify_time_position "$3" "$ENDTIME" "Ending massive time pos:$COMBOARRAYPOS"

    if [ "${ENDTIME%.*}" -le "${BEGTIME%.*}" ] && [ "${ENDTIME%.*}" != "0" ]; then
        printf "%sending(%s) smaller than start(%s)%s\n" "$CR" "$ENDTIME" "$BEGTIME" "$CO"
        ERROR=14; FAILED_FUNC="${FUNCNAME[0]}"; RETVAL=24
    fi
}

#***************************************************************************************************************
# Set error info from splitting
# 1 - error string
# 2 - error number
#***************************************************************************************************************
set_split_error() {
    debug_print

    printf "%s\n" "$1"
    ERROR_WHILE_SPLITTING=1; RETVAL="$2"
}

#***************************************************************************************************************
# Split file into chunks given by input parameters, either (start-end,start-end|...) or (point,point,point,...)
# 1 - Splitting time information
#***************************************************************************************************************
new_massive_file_split() {
    debug_print

    if [ "$SPLIT_AND_COMBINE" -eq "1" ]; then
        if [[ ! "$APP_STRING" =~ "ffmpeg" ]]; then
            printf "%sCannot combine files with %s%s%s Aborting!%s\n" "$CR" "$CY" "$APP_STRING" "$CR" "$CO"
            temp_file_cleanup "1"
        fi
    fi

    ERROR_WHILE_SPLITTING=0; MASSIVE_TIME_CHECK=0; MASSIVE_SPLIT=1; KEEPORG=1; IGNORE=1; DELETE_AT_END=0

    if [ -f "$FILE" ]; then
        EXT_CURR="${FILE##*.}"
        LEN=$(get_file_duration "$FILE" "0" "1")
        XSS=$(mediainfo '--Inform=Video;%Width%' "$FILE")
        if [ -z "$XSS" ]; then set_split_error "Something wrong with width $FILE:$XSS\n" "21"; return; fi
        ORG_LEN="$LEN"
        SPLIT_P2P=$(grep -o "-" <<< "$1" | wc -l)

        mapfile -t -d ',' array < <(printf "%s" "$1")
        SPLIT_MAX=${#array[@]}
        MASSIVE_COUNTER=0; LAST_SPLIT=0; DELETE_SET=0; COMBOARRAYPOS=1; KEEPORG=1

        # Verify each time point before doing anything else
        for index in "${!array[@]}"; do
            if [[ "${array[index]}" == *"D"* ]]; then DELETE_AT_END=1; break; fi
            if [ "$SPLIT_P2P" -gt "0" ]; then
                mapfile -t -d '-' array2 < <(printf "%s" "${array[index]}")
                set_beg_end "${array2[0]}" "${array2[1]}" "$ORG_LEN"
            else
                SPLIT_POINT=$(calculate_time "${array[index]}")
                verify_time_position "$ORG_LEN" "$SPLIT_POINT" "Beginning point split"
            fi
            [ "$ERROR" != "0" ] && ERROR_WHILE_SPLITTING=3 && break
            ((COMBOARRAYPOS++))
        done

        COMBOARRAYSIZE=$((${#array[@]} - DELETE_AT_END)); COMBOARRAYPOS=1

        # If all time signatures are correct, start splitting
        for index in "${!array[@]}"; do
            [ "$ERROR" != "0" ] && break
            if [[ "${array[index]}" == *"D"* ]]; then KEEPORG=0; DELETE_SET=1; break; fi

            if [ "$SPLIT_P2P" -gt "0" ]; then
                mapfile -t -d '-' array2 < <(printf "%s" "${array[index]}")

                set_beg_end "${array2[0]}" "${array2[1]}" "$ORG_LEN"
                #[ "$ENDTIME" != "0" ] && ENDTIME=$((LEN - ENDTIME))

                pack_file
                MASSIVE_TIME_CHECK=$(bc <<< "scale=0;(${MASSIVE_TIME_CHECK} + (${ENDTIME} - ${BEGTIME}))")
            else
                SPLIT_POINT=$(calculate_time "${array[index]}")
                verify_time_position "$ORG_LEN" "$SPLIT_POINT" "Beginning point split"

                if [ "$SPLIT_POINT" -le "$LAST_SPLIT" ] && [ "$SPLIT_POINT" != "0" ]; then
                    ERROR_WHILE_SPLITTING=4
                    printf "%sSplit error %s - Time: %s <= %s%s\n" "$CR" "$FILE" "$LAST_SPLIT" "$SPLIT_POINT" "$CO"
                    RETVAL=23
                else
                    BEGTIME="$LAST_SPLIT"
                    if [ "$SPLIT_POINT" == "0" ]; then
                        ENDTIME=0
                        MASSIVE_TIME_CHECK=$(bc <<< "scale=0;(${MASSIVE_TIME_CHECK} + (${LEN} - ${BEGTIME}))")
                    else
                        ENDTIME=$(bc <<< "scale=0;(${LEN} - ${SPLIT_POINT})")
                        MASSIVE_TIME_CHECK=$(bc <<< "scale=0;(${MASSIVE_TIME_CHECK} + (${ENDTIME} - ${BEGTIME}))")
                    fi

                    pack_file
                    LAST_SPLIT="$SPLIT_POINT"
                fi
            fi

            ((MASSIVE_COUNTER++))
            ((COMBOARRAYPOS++))
        done

        if [ "$SPLIT_P2P" == "0" ] && [ "$ENDTIME" != "0" ]; then
            BEGTIME="$ENDTIME"; ENDTIME=0; KEEPORG=1
            pack_file
            [ "$DELETE_SET" == "1" ] && KEEPORG=0
        fi

        massive_filecheck

        if [ "$SPLIT_AND_COMBINE" -eq "1" ]; then
            if [ "$RETVAL" -eq "0" ] && [ "$MASSIVE_COUNTER" -gt "1" ]; then combine_split_files
            elif [ "$RETVAL" -eq "0" ] && [ "$MASSIVE_COUNTER" == "1" ]; then rename_unique_combo_file
            else remove_combine_files; fi
        elif [ "$DELETE_AT_END" == "1" ] && [ "${#NAME_RUN[@]}" -eq "0" ]; then
            [ "$MASSIVE_COUNTER" -eq "1" ] && [ -z "$NEWNAME" ] && rename "s/_01//" "${FILE%.*}"*
            [ "$MASSIVE_COUNTER" -eq "1" ] && [ -n "$NEWNAME" ] && rename "s/_01//" "${NEWNAME%.*}"*
        fi

        if [ "$RETVAL" -eq "0" ]; then
            if [ "$DELETE_AT_END" == "1" ]; then ((TOTALSAVE += (ORIGINAL_HOLDER - MASSIVE_ENDSIZE) ))
            else ((TOTALSAVE -= MASSIVE_ENDSIZE)); fi
        fi

    else
        printf "File '%s' not found, cannot multisplit!\n" "$FILE"
        ERROR=10; FAILED_FUNC="${FUNCNAME[0]}"
        [ "$EXIT_VALUE" == "1" ] && temp_file_cleanup "1"
    fi

    KEEPORG="${KEEP_ORG}"
}

#***************************************************************************************************************
# If only one file was set to be combined, then just rename the outcome
#***************************************************************************************************************
rename_unique_combo_file() {
    if [ "${#NAME_RUN[@]}" -gt "0" ]; then return; fi

    make_running_name "-"
    if [ -n "$NEWNAME" ]; then move_file "${TARGET_DIR}/${RUNNING_FILENAME}" "${TARGET_DIR}" "$NEWNAME$CONV_TYPE" "17"
    else move_file "${TARGET_DIR}/${RUNNING_FILENAME}" "${TARGET_DIR}" "$FILE" "18"; fi
    ((RUNTIMES++))
}

#***************************************************************************************************************
# Make combine output file from existing COMBO_ files
#***************************************************************************************************************
make_combine_file() {
    debug_print

    RUNNING_FILE_NUMBER=0

    while true; do
        make_running_name "+"

        [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ] && break
        if [ "$TARGET_DIR" == "." ]; then printf "file '%s'\n" "${RUNNING_FILENAME}" >> "${COMBOFILE}"
        else                              printf "file '%s'\n" "${RUNNING_FILENAME}" >> "${TARGET_DIR}/${COMBOFILE}"; fi

        COMBINE_RUN_COUNT="$RUNNING_FILE_NUMBER"
    done
}

#***************************************************************************************************************
# In case of failure, remove files meant to be combined
#***************************************************************************************************************
remove_combine_files() {
    debug_print

    RUNNING_FILE_NUMBER=0

    while true; do
        make_running_name "+"

        [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ] && break
        delete_file "${TARGET_DIR}/$RUNNING_FILENAME" "5"

        COMBINE_RUN_COUNT="$RUNNING_FILE_NUMBER"
    done

    [ "$EXIT_VALUE" == "1" ] && temp_file_cleanup "1"
}

#***************************************************************************************************************
# Combine split files into one file, then remove splitted files and rename combofile
#***************************************************************************************************************
combine_split_files() {
    debug_print

    if [ "$SPLITTING_ERROR" != "0" ]; then
        printf "Failed to separate all asked parts, not combining (err:%s func:%s)\n" "$SPLITTING_ERROR" "$FAILED_FUNC"
        delete_file "${TARGET_DIR}/${COMBOFILE}" "6"
        delete_file "${TARGET_DIR}/tmp_combo$CONV_TYPE" "7"
        [ "$EXIT_VALUE" == "1" ] && temp_file_cleanup "1"
        return 0
    fi

    make_combine_file
    CURRDIR="$PWD"
    cd "$TARGET_DIR" || return

    ERROR=0
    printf "%s Combining %s split files " "$(print_info)" "$COMBINE_RUN_COUNT"
    ((RUNTIMES++))
    $APP_NAME -f concat -safe 0 -i "${COMBOFILE}" -c copy "tmp_combo$CONV_TYPE" -v info 2>"${PACKFILE}" || ERROR=$?
    [ "$ERROR" != "0" ] && FAILED_FUNC="${FUNCNAME[0]}"
    check_output_errors

    cd "$CURRDIR" || return
    delete_file "${TARGET_DIR}/${COMBOFILE}" "8"
    remove_combine_files

    if [ "$ERROR" -ne "0" ]; then
        printf "%sFailed%s\n" "$CR" "$CO"
        delete_file "${TARGET_DIR}/tmp_combo$CONV_TYPE" "9"
        [ "$EXIT_VALUE" == "1" ] && temp_file_cleanup "1"
        return
    fi

    if [ -f "${TARGET_DIR}/$FILE" ]; then
        make_new_running_name ""
        if [ -z "$NEWNAME" ]; then move_file "${TARGET_DIR}/tmp_combo$CONV_TYPE" "${TARGET_DIR}" "${RUNNING_FILENAME}" "4" "1"
        else                       move_file "${TARGET_DIR}/tmp_combo$CONV_TYPE" "${TARGET_DIR}" "${NEWNAME}${CONV_TYPE}" "5" "1"; fi
    else
        if [ -z "$NEWNAME" ]; then move_file "${TARGET_DIR}/tmp_combo$CONV_TYPE" "${TARGET_DIR}" "${FILE}" "6" "1"
        else                       move_file "${TARGET_DIR}/tmp_combo$CONV_TYPE" "${TARGET_DIR}" "${NEWNAME}${CONV_TYPE}" "7" "1"; fi
    fi

    printf "%sSuccess %s%s%s\n" "$CG" "$CC" "$(calc_dur)" "$CO"
}

#***************************************************************************************************************
# Combine given input files to one file
#***************************************************************************************************************
combineFiles() {
    debug_print

    FILESCOUNT=0; DELETESOURCEFILES=0

    for file in "${COMBINELIST[@]}"; do
        [ -f "$file" ] && printf "file '%s'\n" "$file" >> "${COMBOFILE}" && ((FILESCOUNT++))
        [ "$file" == "delete" ] && DELETESOURCEFILES=1
        [ "$FILESCOUNT" -gt "0" ] && [ -z "$NEWNAME" ] && NEWNAME="$file"
    done

    if [ "$FILESCOUNT" -gt "1" ];  then
        [ -z "$NEWNAME" ] && NEWNAME="target_combo"

        printf "Combining %s files " "$FILESCOUNT"
        ERROR=0
        ((RUNTIMES++))
        $APP_NAME -f concat -safe 0 -i "${COMBOFILE}" -c copy "${TARGET_DIR}/${NEWNAME}_${CONV_TYPE}" -v info 2>"${PACKFILE}" || ERROR=$?
        [ "$ERROR" != "0" ] && FAILED_FUNC="${FUNCNAME[0]}"
        check_output_errors

        delete_file "${COMBOFILE}" "10"

        if [ "$ERROR" -eq "0" ]; then
            if [ "$DELETESOURCEFILES" == "1" ]; then
                for file in "${COMBINELIST[@]}"; do [ -f "$file" ] && delete_file "$file" "11"; done
                printf "%sCombined %s files to %s/%s_%s,%s deleted all sourcefiles\n" "$CG" "$FILESCOUNT" "${TARGET_DIR}" "${NEWNAME}" "${CONV_TYPE}" "$CO"
            else
                printf "%sCombined %s files to %s/%s_%s%s\n" "$CG" "$FILESCOUNT" "${TARGET_DIR}" "${NEWNAME}" "${CONV_TYPE}" "$CO"
            fi
            temp_file_cleanup "0"
        else
            printf "%sFailed to combine %s as %s/%s_%s%s\n" "$CR" "$FILESCOUNT" "${TARGET_DIR}" "${NEWNAME}" "${CONV_TYPE}" "$CO"
            temp_file_cleanup "1"
        fi
    else
        [ -f "${COMBOFILE}" ] && delete_file "${COMBOFILE}" "12"
        printf "%sNo input files given to combine! Filecount:%s%s\n" "$CR" "$FILESCOUNT" "$CO"
        temp_file_cleanup "1"
    fi
}

#***************************************************************************************************************
# Replace or insert audio in video file with given audio files
# 1 - If not set, is a merge, else append
#***************************************************************************************************************
mergeFiles() {
    debug_print

    if [ -z "$1" ]; then SETUPSTRING=("-map" "0:v") && TYPE="Merge"
    else SETUPSTRING=("-map" "0") && TYPE="Append"; fi

    FILESCOUNT=0; DELETESOURCEFILES=0; COMMANDSTRING=(); ORIGNAME=""; ORGSIZE=0

    for file in "${COMBINELIST[@]}"; do
        if [ -f "$file" ]; then
            COMMANDSTRING+=(-i "${file}")
            OSIZE=$(du -k "$file" | cut -f1)
            [ "$FILESCOUNT" -gt "0" ] && SETUPSTRING+=("-map" "${FILESCOUNT}:a")
            ((FILESCOUNT++))
            ((ORIGSIZE += OSIZE))
        fi
        [ "$file" == "delete" ] && DELETESOURCEFILES=1
        [ "$FILESCOUNT" -gt "0" ] && [ -z "$NEWNAME" ] && NEWNAME="$file" && ORIGNAME="$file"
        [[ "$ORIGNAME" == *"${CONV_TYPE}"* ]] && ORIGNAME="${ORIGNAME%.*}.${CONV_TYPE}"
    done

    SETUPSTRING+=("-c:v" "copy" "-shortest")

    if [ "$FILESCOUNT" -gt "1" ];  then
        [ -z "$NEWNAME" ] && NEWNAME="target_combo"
        [ -f "${TARGET_DIR}/${NEWNAME}_${CONV_TYPE}" ] && NEWNAME="merged_$NEWNAME"

        printf "%s %s %s files " "$(date -u +%T)" "$TYPE" "$FILESCOUNT"
        ERROR=0
        [ "$BUGME" -eq "1" ] && printf "\n    %s%s \"%s\" %s \"%s/%s%s\"%s\n" "$CP" "$APP_STRING" "${COMMANDSTRING[*]}" "${SETUPSTRING[*]}" "${TARGET_DIR}" "${NEWNAME}" "${CONV_TYPE}" "$CO"
        ((RUNTIMES++))
        $APP_NAME "${COMMANDSTRING[@]}" "${SETUPSTRING[@]}" "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" -v info 2>"${PACKFILE}" || ERROR=$?
        [ "$ERROR" != "0" ] && FAILED_FUNC="${FUNCNAME[0]}"
        check_output_errors

        if [ "$ERROR" -eq "0" ]; then
            if [ "$DELETESOURCEFILES" == "1" ]; then
                for file in "${COMBINELIST[@]}"; do [ -f "$file" ] && delete_file "$file" "13"; done
                NEWSIZE=$(du -k "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" | cut -f1)
                NEWSIZE=$((ORGSIZE - NEWSIZE))
                [ "$NEWNAME" != "$ORIGNAME" ] && move_file "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" "${TARGET_DIR}" "${ORIGNAME}" "8"
                printf "%sSuccess into %s/%s,%s deleted all sources %sin %s%s saved %s\n" "$CG" "${TARGET_DIR}" "${ORIGNAME}" "$CO" "$CC" "$(calc_time_tk)" "$CO" "$(check_valuetype "${NEWSIZE}")"
            else
                printf "%sSuccess into %s/%s%s%s in %s%s\n" "$CG" "${TARGET_DIR}" "${NEWNAME}" "${CONV_TYPE}" "$CC" "$(calc_time_tk)" "$CO"
            fi

            temp_file_cleanup "0"
        else
            printf "%sFailed!%s in %s%s\n" "$CR" "$CC" "$(calc_time_tk)" "$CO"
            delete_file "${TARGET_DIR}/${NEWNAME}.${CONV_TYPE}" "14"
            temp_file_cleanup "1"
        fi
    else
        printf "%s %sNot enough input files given to %s! Filecount:%s%s\n" "$(print_info)" "$CR" "$TYPE" "$FILESCOUNT" "$CO"
        temp_file_cleanup "1"
    fi
}

#***************************************************************************************************************
# Separate and calculate given time into seconds and set to corresponting placeholder
# 1 - time value in hh:mm:ss.ms / mm:ss.ms / ss.ms or a filename
#***************************************************************************************************************
calculate_time() {
    debug_print

    re='^[0-9:.]+$'
    [[ ! "$1" =~ $re ]] && ERROR=11 && FAILED_FUNC="${FUNCNAME[0]}" && printf "0" && return #printf "%s%s -> not correct: '%s'%s\n" "$CR" "${FUNCNAME[0]}" "$1" "$CO" && return
    ERROR=0; CALCTIME=0; ADDTIME=0

    if [ -n "$1" ]; then
        [ "$1" == "D" ] && return

        if [ -f "$1" ]; then
            find_image_pos "$FILE" "$1" "$2"
            CALCTIME="$IMAGETIME"
        else
            MAINTIME="${1%.*}"
            [[ "$1" == *"."* ]] && ADDTIME="${1##*.}"

            mapfile -t -d ':' TA < <(printf "%s" "$MAINTIME")

            for i in "${!TA[@]}"; do TA[$i]=$(check_zero "${TA[$i]}"); done

            if [ "${#TA[@]}" == "2" ]; then
                TA[0]=$((TA[0] * 60))
            elif [ "${#TA[@]}" -gt "2" ]; then
                TA[0]=$((TA[0] * 3600))
                TA[1]=$((TA[1] * 60))
            fi

            for i in "${TA[@]}"; do ((CALCTIME += i)); done
            [ "$ADDTIME" != "0" ] && CALCTIME+=".${ADDTIME}"
        fi
    fi

    printf "%s" "$CALCTIME"
}

#**************************************************************************************************************
# Fetch video name from possible url, NEWNAME or original filename
# 1 - position value for delimiter (starting from 1)
#**************************************************************************************************************
fetchname() {
    SEASON=""; EPISODE=""; EPNAME=""; EXTRA=""; DELIM="${1:-1}"

    if [ -n "${DELIMITER}" ]; then
        SN_BEGIN="${FILE%% *}"
        SN_END="${FILE#* }"
        SN_END="${SN_END%.*}"
        mapfile -t -d "${DELIMITER}" SN_NAMES < <(printf "%s" "$SN_END")
    elif [ -n "${FETCHURL}" ] && [ -n "${URL_DATA}" ]; then
        pos=0
        re='^[0-9]+$'
        season=false
        episode=false

        while true; do
            CHAR="${FILE:pos:1}"
            [ -z "${CHAR}" ] && break

            if [ "${CHAR,,}" == "s" ]; then season=true
            elif [ "${CHAR,,}" == "e" ]; then season=false; episode=true
            elif [[ "${CHAR}" =~ $re ]]; then
                if $episode; then EPISODE+="${CHAR}"
                elif $season; then SEASON+="${CHAR}"
                else EXTRA+="${CHAR}"; fi
            elif [ "${CHAR,,}" == "x" ] && [ -n "${EXTRA}" ]; then SEASON="${EXTRA}"; episode=true
            elif [ "${#EPISODE}" -ge "2" ] && [ "${#SEASON}" -ge "1" ]; then break
            else EPISODE=""; SEASON=""; EXTRA=""; season=false; episode=false; fi

            ((pos++))
        done

        if [ -n "${SEASON}" ] && [ -n "${EPISODE}" ] && [ "${SEASON}" -gt "0" ] && [ "${EPISODE}" -gt "0" ]; then
            if [ "${SEASON:0:1}" == "0" ]; then SEASON="${SEASON:1:1}"; fi

            if [[ "${FETCHURL,,}" == *"epguides"* ]]; then mapfile -t -d '>' URLDATA< <(printf "%s" "${URL_DATA}" |grep "${SEASON}x${EPISODE}"); fi
            if [ "${EPISODE:0:1}" == "0" ]; then EPISODE="${EPISODE:1:1}"; fi
            if [[ "${FETCHURL,,}" == *"wikipedia"* ]]; then mapfile -t URLDATA< <(printf "%s" "${URL_DATA}" | tr '<>' '\n'); fi

            if [[ "${FETCHURL,,}" == *"epguides"* ]]; then
                for i in "${URLDATA[@]}"; do
                    if [[ "${i}" == *"</a" ]]; then
                        EPNAME="$(printf "%s" "${i%<*}" | recode html..ascii)"
                    fi
                done
            elif [[ "${FETCHURL,,}" == *"wikipedia"* ]]; then
                season=0; episode=0; c_count=0; t_count=0
                for i in "${URLDATA[@]}"; do
                    if [ "${season}" == "0" ]; then
                        if [[ "${i}" == *"id=\"ep"* ]]; then ((c_count++)); fi
                        if [[ "${i}" == "h3 id=\"Season_${SEASON}_"* ]]; then season=1; t_count="$((c_count + EPISODE))";fi
                    elif [ "${episode}" == "0" ]; then
                        if [[ "${i}" == *"id=\"ep${t_count}"* ]]; then episode=1; fi
                    elif [[ "${i}" == "\""* ]]; then
                        EPNAME="${i//\"/}"; break
                    fi
                done
            fi
        fi
    fi

    filename="${FILE%.*}"
    if [ -n "${SEASON}" ] && [ -n "${EPISODE}" ] && [ -n "${EPNAME}" ]; then printf "%d%02d %s%s" "${SEASON}" "${EPISODE}" "${EPNAME//\/-}" "${CONV_TYPE}"
    elif [ -n "${DELIMITER}" ]; then printf "%s.%d %s%s" "${SN_BEGIN}" "${DELIM}" "${SN_NAMES[$((DELIM - 1))]}" "$CONV_TYPE"
    elif [ -n "${NEWNAME}" ] && [[ "${NEWNAME}" != "COMBO_"* ]]; then printf "%s%s" "${NEWNAME}" "${CONV_TYPE}"
    else printf "%s%s" "${filename}" "${CONV_TYPE}"; fi
}

#**************************************************************************************************************
# Parse special handlers
# 1 - input string
# 2 - if set, will add certain values to arrays instead of immediately settings values
#***************************************************************************************************************
parse_handlers() {
    debug_print

    if [ -n "$1" ]; then
        if [ "$1" == "repack" ] || [ "$1" == "r" ]; then
            [ "$CROP_HAPPENED" -eq "1" ] && return
            [ -n "$2" ] && PACK_RUN+=("$1") && return
            REPACK=1; REPACK_GIVEN=1; COPY_ONLY=0
        elif [ "$1" == "crop" ] || [ "$1" == "s" ]; then
            [ -n "$2" ] && CROP_RUN+=("$1") && return
            CROP="seek"
        elif [ "$1" == "ierr" ]; then                      IGNORE_UNKNOWN=1
        elif [ "$1" == "bugme" ]; then                     BUGME=1
        elif [ "$1" == "quit" ]; then                      EXIT_VALUE=1
        elif [ "$1" == "repeat" ]; then                    EXIT_REPEAT=1
        elif [ "$1" == "command" ]; then                   CMD_PRINT="1"
        elif [ "$1" == "continue" ]; then                  EXIT_CONTINUE=1
        elif [ "$1" == "nocodec" ]; then                   NO_CODEC=1
        elif [ "$1" == "D" ]; then                         DEBUG_PRINT=1
        elif [ "$1" == "D2" ]; then                        DEBUG_PRINT=2
        elif [ "$1" == "quick" ]; then                     QUICK=1
        elif [ "$1" == "scrub" ] || [ "$1" == "s" ]; then  SCRUB=1
        elif [ "$1" == "ignore" ] || [ "$1" == "i" ]; then IGNORE=1
        elif [ "$1" == "Ignore" ] || [ "$1" == "I" ]; then IGNORE_SPACE=1
        elif [ "$1" == "Force" ] || [ "$1" == "F" ]; then  IGNORE_SPACE_SIZE=1
        elif [ "$1" == "keep" ] || [ "$1" == "k" ]; then   KEEPORG=1; KEEP_ORG=1; DELETE_AT_END=0
        elif [ "$1" == "wav" ] || [ "$1" == "w" ]; then    KEEPORG=1; AUDIO_PACK=1; CONV_TYPE=".wav"; CONV_CHECK="wav"; WAV_OUT=1
        elif [ "$1" == "Mp3" ] || [ "$1" == "M" ]; then    KEEPORG=1; AUDIO_PACK=1; CONV_TYPE=".mp3"; CONV_CHECK="mp3"
        elif [ "$1" == "mp3" ] || [ "$1" == "m" ]; then    KEEPORG=1; MP3OUT=1; CONV_TYPE=".mp3"; CONV_CHECK="mp3"
        elif [ "$1" == "flac" ] || [ "$1" == "f" ]; then   KEEPORG=1; AUDIO_PACK=1; CONV_TYPE=".flac"; CONV_CHECK="flac"
        elif [ "$1" == "all" ] || [ "$1" == "a" ]; then    PRINT_ALL=1
        elif [ "$1" == "print" ] || [ "$1" == "p" ]; then  PRINT_INFO=1
        else
            printf "%sUnknown handler %s %s%s\n" "${CR}" "$1" "${FUNCNAME[0]}" "${CO}"
            RETVAL=1; ERROR=6; FAILED_FUNC="${FUNCNAME[0]}"
            [ "$NO_EXIT_EXTERNAL" == "0" ] && temp_file_cleanup "$RETVAL"
        fi
    fi
}

#**************************************************************************************************************
# Read data from url to a handler, if not already read
# 1 - url to read from
#**************************************************************************************************************
update_url() {
    [ -n "${URL_DATA}" ] && return

    ALTFILE="${1//\//}"
    ALTFILE="${ALTFILE//:/}"
    nowtime="$(date +%s)"

    if [ -f "/tmp/${ALTFILE}" ]; then
        read -r TIMEDATA < "/tmp/${ALTFILE}"
        if [[ "$((nowtime - TIMEDATA))" -lt "50000" ]]; then
            URL_DATA="$(cat "/tmp/${ALTFILE}")"
            printf "%s: Reading information from file '%s'" "$(date +%H:%M:%S)" "${1}"
            return
        fi
    fi

    fcnt=0
    printf "%s: Reading information from url '%s' " "$(date +%H:%M:%S)" "${1}"

    while [ -z "${URL_DATA}" ]; do
        URL_DATA="$(timeout -v 15s wget url "${1}" -qO -)"
        ((fcnt++)); [ "${fcnt}" -ge "10" ] && break
        if [[ "${URL_DATA}" != *"1x01"* ]] && [[ "${URL_DATA}" != *"id=\"ep1"* ]]; then URL_DATA=""; fi
    done

    if [ -z "${URL_DATA}" ]; then printf "%sFAILED! No data read!%s\n" "${CR}" "${CO}" && exit 1
    elif [[ "${URL_DATA}" != *"1x01"* ]] && [[ "${URL_DATA}" != *"id=\"ep1"* ]]; then printf "%sFAILED! No correct information found!%s %s\n" "${CR}" "${CO}" "${1}" && exit 2
    else
        printf "%sSuccess!%s\n" "${CG}" "${CO}"
        printf "%s\n%s\n" "${nowtime}" "${URL_DATA}" >"/tmp/${ALTFILE}"
    fi
}

#**************************************************************************************************************
# Parse time values to remove
# 1 - input value
# 2 - if set, will set certain values to arrays instead of setting them imediately
#***************************************************************************************************************
parse_values() {
    debug_print

    if [ -n "$1" ]; then
        HANDLER=$(printf "%s" "$1" | cut -d = -f 1)
        VALUE=$(printf "%s" "$1" | cut -d = -f 2)
        [ -z "$VALUE" ] && return

        if [ "$HANDLER" == "beg" ] || [ "$HANDLER" == "b" ]; then
            ((CUTTING++))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            BEGTIME="$(calculate_time "$VALUE")"
        elif [ "$HANDLER" == "end" ] || [ "$HANDLER" == "e" ]; then
            ((CUTTING++))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            ENDTIME="$(calculate_time "$VALUE")"
        elif [ "$HANDLER" == "language" ] || [ "$HANDLER" == "l" ]; then
            LANGUAGE="$VALUE"
        elif [ "$HANDLER" == "videotrack" ] || [ "$HANDLER" == "vt" ]; then
            [ -n "$2" ] && PACK_RUN+=("$1") && return
            VIDEOTRACK="$VALUE"
        elif [ "$HANDLER" == "audiotrack" ] || [ "$HANDLER" == "at" ]; then
            [ -n "$2" ] && PACK_RUN+=("$1") && return
            AUDIOTRACK="$VALUE"
        elif [ "$HANDLER" == "duration" ] || [ "$HANDLER" == "d" ]; then
            ((CUTTING++))
            [ -n "$2" ] && CUT_RUN+=("$1") && return
            ENDPOINT="$(calculate_time "$VALUE")"
        elif [ "$HANDLER" == "Combine" ] || [ "$HANDLER" == "C" ]; then
            ((CUTTING++))
            [ -n "$2" ] && MASS_RUN+=("$1") && return
            SPLIT_AND_COMBINE=1; MASS_SPLIT_VALUE="${VALUE}"
            [ -z "${CROP}" ] && new_massive_file_split "$VALUE"
        elif [ "$HANDLER" == "cut" ] || [ "$HANDLER" == "c" ]; then
            ((CUTTING++))
            [ -n "$2" ] && MASS_RUN+=("$1") && return
            MASS_SPLIT=1; MASS_SPLIT_VALUE="${VALUE}"
            [ -z "${CROP}" ] && new_massive_file_split "$VALUE"
        elif [ "$HANDLER" == "sub" ]; then
            [ -n "$2" ] && SUB_RUN+=("$1") && return
            SUBFILE="$VALUE"
        elif [ "$HANDLER" == "n" ] || [ "$HANDLER" == "name" ]; then
            [ -n "$2" ] && NAME_RUN+=("$1") && return
            VALUE="${VALUE//\'/}"; NEWNAME="$VALUE"
        elif [ "$HANDLER" == "url" ]; then
            update_url "${VALUE}"
            [ -n "$2" ] && NAME_RUN+=("$1") && return
            FETCHURL="${VALUE}"
        elif [ "$HANDLER" == "N" ]; then
            if [ -n "$2" ]; then NAME_RUN+=("$1"); return; fi
            DELIMITER="$VALUE"
        elif [ "$HANDLER" == "T" ] || [ "$HANDLER" == "Target" ]; then
            [ -n "$2" ] && NAME_RUN+=("$1") && return
            TARGET_DIR="$VALUE"
        elif [ "$HANDLER" == "crop" ] || [ "$HANDLER" == "s" ]; then
            [ -n "$2" ] && CROP_RUN+=("$1") && return
            CROP="${VALUE}"
        elif [ "$HANDLER" == "skip" ]; then                              mapfile -t -d ';' SKIPLIST < <(printf "%s" "$VALUE")
        elif [ "$HANDLER" == "max" ]; then                               MAX_SHORT_TIME="$VALUE"
        elif [ "$HANDLER" == "delaudio" ]; then                          AUDIODELAY="$VALUE"
        elif [ "$HANDLER" == "delvideo" ]; then                          VIDEODELAY="$VALUE"
        elif [ "$HANDLER" == "Position" ] || [ "$HANDLER" == "P" ]; then START_POSITION="$VALUE"
        elif [ "$HANDLER" == "End" ] || [ "$HANDLER" == "E" ]; then      END_POSITION="$VALUE"
        elif [ "$HANDLER" == "target" ] || [ "$HANDLER" == "t" ]; then   CONV_TYPE=".$VALUE"; CONV_CHECK="$VALUE"
        elif [ "$HANDLER" == "Audio" ] || [ "$HANDLER" == "A" ]; then    AUDIO_PACK=1; CONV_TYPE=".$VALUE"; CONV_CHECK="$VALUE"
        elif [ "$HANDLER" == "print" ] || [ "$HANDLER" == "p" ]; then    PRINT_INFO=$VALUE
        elif [ "$1" == "scrub" ] || [ "$1" == "s" ]; then                SCRUB=$VALUE
        else
            printf "%sUnknown value %s %s%s\n" "${CR}" "$1" "${FUNCNAME[0]}" "${CO}"
            ERROR=7; RETVAL=2; FAILED_FUNC="${FUNCNAME[0]}"
            [ "$NO_EXIT_EXTERNAL" == "0" ] && temp_file_cleanup "$RETVAL"
        fi
        check_workmode
    fi
    CALCTIME=0
}

#**************************************************************************************************************
# Parse dimension values
# 1 - dimension value Width x Height
#***************************************************************************************************************
parse_dimension() {
    debug_print

    if [ -n "$1" ]; then
        WIDTH=$(printf "%s" "$1" | cut -d x -f 1)
        if [ "$WIDTH" -lt "640" ]; then
            printf "%s way too small width to be used! Aborting! 640x is minimum!\n" "$WIDTH"
            temp_file_cleanup "1"
        fi
        #HEIGHT=$(printf "%s" "$1" | cut -d x -f 2)
        COPY_ONLY=0; DIMENSION_PARSED=1
    fi
}

#**************************************************************************************************************
# Parse file information
#***************************************************************************************************************
parse_file() {
    debug_print

    if [ -n "$1" ]; then
        CONTINUE_PROCESS=1; FILE_STR="$1"; filename="${FILE_STR%.*}"

        if [ ! -f "$FILE_STR" ] && [ -f "${filename}.mp4" ]; then FILE_STR="${filename}.mp4"; fi

        if [ ! -f "$FILE_STR" ]; then
            filename=""; FILECOUNT=$(find . -maxdepth 1 -iname "*$FILE_STR*" |wc -l)
            [ "$FILECOUNT" == "0" ] && CONTINUE_PROCESS=0
        elif [ ! -f "${PACKFILE}" ]; then
            $APP_NAME -i "$FILE_STR" -v info 2>"${PACKFILE}"
            check_output_errors
            [ "$ERROR" != "0" ] && CONTINUE_PROCESS=0
        fi
    fi
}

#***************************************************************************************************************
# Print directory path, if not current folder
# 1- Target directory
#***************************************************************************************************************
print_dir() {
    printf "%s" "$([ "${1}" != "." ] && printf "%s/" "${1}")"
}

#***************************************************************************************************************
# Rename all files to designated names
#***************************************************************************************************************
rename_files() {
    FNAME="$(fetchname)"; loopitem=1

    [ "${PROCESS_INTERRUPTED}" -eq "1" ] && return

    if [ "$MASS_SPLIT" == "1" ]; then
        if [ "${MASSIVE_COUNTER}" -eq "1" ]; then
            if [ "${DELETE_AT_END}" -eq "1" ]; then rename "s/_01//" "${FILE%.*}"*
            else make_running_name "-" ; FILE="${RUNNING_FILENAME}"; fi

            if [ "${FNAME}" != "${FILE}" ] || [ "${TARGET_DIR}" != "." ]; then move_file "${FILE}" "${TARGET_DIR}" "${FNAME}" "109"
            else RUNNING_FILENAME="${FNAME}"; fi
            printf "%s %sMoved to %s%s%s\n" "$(print_info)" "$CT" "$(print_dir "${TARGET_DIR}")" "${RUNNING_FILENAME}" "$CO"
        else
            make_running_name "-" "${FILE}"
            while [ -f "${RUNNING_FILENAME}" ]; do
                CURR_FILENAME="${RUNNING_FILENAME}"
                if [ -n "${DELIMITER}" ]; then RUNNING_FILENAME="$(fetchname "${loopitem}")"; P_OUT="Delimiter"
                else make_running_name "${FNAME}"; P_OUT="Splitted"; fi

                move_file "${CURR_FILENAME}" "${TARGET_DIR}" "${RUNNING_FILENAME}" "107"
                printf "%s %s%s file %d/%d to %s%s%s\n" "$(print_info)" "$CT" "${P_OUT}" "${loopitem}" "${MASSIVE_COUNTER}" "$(print_dir "${TARGET_DIR}")" "${RUNNING_FILENAME}" "$CO"
                make_running_name "+" "${FILE}"
                ((loopitem++))
            done
        fi
    else
        if [ "${SPLIT_AND_COMBINE}" -eq "1" ] && [ "${DELETE_AT_END}" -eq "0" ]; then make_running_name "-"; FILE="${RUNNING_FILENAME}"; fi

        if [ "${FNAME}" != "${FILE}" ] || [ "${TARGET_DIR}" != "." ]; then
            move_file "$FILE" "${TARGET_DIR}" "${FNAME}" "106"
            printf "%s %sRenamed to %s%s%s\n" "$(print_info)" "$CT" "$(print_dir "${TARGET_DIR}")" "${RUNNING_FILENAME}" "$CO"
        fi
    fi
    ((RUNTIMES++))
}

#***************************************************************************************************************
# Handle packing by type
# 1 - packing type selector string (subs,file,cut)
#***************************************************************************************************************
handle_packing() {
    debug_print

    if [ "${1}" == "rename" ]; then rename_files
    elif [ -f "$FILE" ] && [ "$ERROR" == "0" ]; then
        if [ "$1" == "subs" ] && [ -n "$SUBFILE" ]; then burn_subs "$SUBFILE"
        elif [ "$1" == "file" ] || [ "$1" == "cut" ] || [ "$1" == "repack" ] || [ "$1" == "mass" ]; then
            pack_file
            if [ "$1" == "file" ] && [ ! -f "${FILE}" ]; then
                filename="${FILE%.*}"; [ -f "${filename}${CONV_TYPE}" ] && FILE="${filename}${CONV_TYPE}"
            fi
        elif [ "$1" == "other" ]; then
            for var in "${CUT_RUN[@]}"; do parse_data "$var"; done
            pack_file
        else printf "%sUnknown handler %s for '%s'%s\n" "$CR" "$1" "$FILE" "$CO"; ERROR=3; FAILED_FUNC="${FUNCNAME[0]}"; RETVAL=3; fi
    elif [ -d "$FILE" ]; then
        printf "%s %sSkipping directory%s\n" "$(print_info)" "$CY" "$CO"
    else
        printf "%s %sFile(s) '%s' not found (handle:%s)! or Error:%s%s\n" "$(print_info)" "$CR" "$FILE" "$1" "$ERROR" "$CO"
        RETVAL=4; ERROR=4; FAILED_FUNC="${FUNCNAME[0]}"
    fi
}

#***************************************************************************************************************
# Parse input data from given commandline inputs
# 1 - input option
# 2 - if set, will separate different step options
#***************************************************************************************************************
parse_data() {
    debug_print

    if [ -n "$1" ]; then
        if [ "$CHECKRUN" == 0 ] || [ -f "${1}" ]; then
            parse_file "$1"
        else
            xss=0
            [ -z "${DIMENSION_PARSED}" ] && DIMENSION_PARSED=0
            if [ "$DIMENSION_PARSED" -eq "0" ] && [ ! -f "${1}" ]; then
                re='^[0-9x]+$'
                [[ "$1" =~ $re ]] && xss=$(grep -o "x" <<< "$1" | wc -l)
                if [ "${xss}" -gt "0" ]; then
                    re='^[0-9]+$'
                    if [[ "${xss}" =~ $re ]]; then xss=$(grep -o "x" <<< "$1" | wc -l)
                    else xss=0; fi
                fi
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
# Update the time saved by splitting
#***************************************************************************************************************
update_saved_time() {
    debug_print

    if [ "$TIMESAVED" -gt "0" ] && [ "$DELETE_AT_END" == "1" ]; then
        if [ "${MASSIVE_TIME_SAVE%.*}" -gt "0" ]; then TIMESAVED=$(((ORIGINAL_DURATION / 1000) - ${MASSIVE_TIME_SAVE%.*}))
        else                                           TIMESAVED=$((TIMESAVED  / 1000)); fi
    fi
}

#***************************************************************************************************************
# Print multiple file handling information
# 1 - if set will print everything, otherwise, will print empty for the base-size
#***************************************************************************************************************
print_info() {
    debug_print

    if [ -z "$1" ]; then printf "%${PACKLEN}s" " "; return; fi

    INFO_OUT=""

    if [ -n "$MAX_ITEMS" ] && [ -n "$COUNTED_ITEMS" ]; then
        STROUT_P="${#MAX_ITEMS}"
        [ "$COUNTED_ITEMS" -gt "1" ] && [ "$PRINT_INFO" -eq "0" ] && printf "\n"
        INFO_OUT="$(printf "%${STROUT_P}d/%-${STROUT_P}d " "$COUNTED_ITEMS" "$MAX_ITEMS")"
    elif [ "$FILECOUNT" -gt 1 ]; then
        STROUT_P="${#FILECOUNT}"
        [ "$CURRENTFILECOUNTER" -gt "1" ] && [ "$PRINT_INFO" -eq "0" ] && printf "\n"
        INFO_OUT="$(printf "%${STROUT_P}d/%-${STROUT_P}d " "$CURRENTFILECOUNTER" "$FILECOUNT")"
    fi

    INFO_OUT+="$(date +%T): $(short_name)"
    INFO_X=$(mediainfo '--Inform=Video;%Width%' "$FILE"); INFO_Y=$(mediainfo '--Inform=Video;%Height%' "$FILE")
    INFO_DUR=$(get_file_duration "$FILE" "0" "1"); INFO_SIZE=$(du -k "$FILE" | cut -f1)
    if [ "$PRINT_INFO" -gt "0" ]; then ((PRINTSIZE += INFO_SIZE)); ((PRINTLENGTH += INFO_DUR)); fi

    INFO_COLOR=""
    [ "$PRINT_INFO" == "0" ] && INFO_COLOR="Initial "
    INFO_COLOR+="$(printf "%4dx%-4d Size:%-9s Lenght:%-9s" "${INFO_X}" "${INFO_Y}" "$(check_valuetype "${INFO_SIZE}")" "$(calc_giv_time "$INFO_DUR")")"
    printf "%s %s%s%s\n" "$INFO_OUT" "$CY" "$INFO_COLOR" "$CO"
}

#***************************************************************************************************************
# Update possible printlen if more than one file in printout
#***************************************************************************************************************
update_printlen() {
    debug_print

    STROUT_P=0
    if [ -n "$MAX_ITEMS" ] && [ -n "$COUNTED_ITEMS" ]; then STROUT_P="${#MAX_ITEMS}"
    elif [ "$FILECOUNT" -gt 1 ]; then STROUT_P="${#FILECOUNT}"; fi

    if [ "${STROUT_P}" -gt "0" ]; then PACKLEN="$((PACKLEN + 2 + (2 * STROUT_P)))"; fi
}

#***************************************************************************************************************
# Calculate time from current time data for one process and total
#***************************************************************************************************************
calc_dur() {
    debug_print

    TIMERR=$(date +%s)
    processing_time=$((TIMERR - process_start_time))
    printf "in %s%s" "$(date -d@${processing_time} -u +%T)" "$(calc_giv_time "${AVG_EST}" "/")"
    process_start_time="$TIMERR"
}

#***************************************************************************************************************
# Cut filename shorter if it's too long, or fill with empty to match length
# 1 - filename max length
#***************************************************************************************************************
short_name() {
    debug_print

    NAMENOEXT="${FILE%.*}"; NAMEEXT="${FILE##*.}"; PART_LEN=$((50 - ${#NAMENOEXT} - ${#NAMEEXT}))

    if [ "${#FILE}" -lt "51" ]; then        FILEprint=$(printf "%-51s" "$FILE")
    elif [ "${#NAMENOEXT}" -lt "46" ]; then FILEprint=$(printf "%s.%s%${PART_LEN}s" "${NAMENOEXT}" "${NAMEEXT}" " ")
    else                                    FILEprint=$(printf "%-45s~.%-3s" "${NAMENOEXT:0:46}" "${NAMEEXT:0:3}"); fi

    printf "%s" "$FILEprint"
}

#***************************************************************************************************************
# Setup file packing variables
#***************************************************************************************************************
setup_file_packing() {
    debug_print

    COMMAND_LINE=()
    if [ "${IGNORE_UNKNOWN}" -eq "1" ]; then COMMAND_LINE+=("-err_detect" "ignore"); fi

    if [ "$WORKMODE" == "1" ] || [ "$WORKMODE" == "3" ]; then
        verify_time_position "$DUR" "$BEGTIME" "Beginning time"
        [ "$ERROR" != "0" ] && return
        COMMAND_LINE+=("-ss" "${BEGTIME}")
    fi

    if [ "$WORKMODE" == "2" ] || [ "$WORKMODE" == "3" ]; then
        verify_time_position "$DUR" "$ENDTIME" "Ending time"
        [ "$ERROR" != "0" ] && return
        if [ "${MASSIVE_SPLIT}" -gt "0" ]; then
            COMMAND_LINE+=("-to" "${ENDTIME}")
        elif [ "${ENDPOINT}" != "0" ]; then
            COMMAND_LINE+=("-to" "${ENDPOINT}")
        else
            ENDO=$(bc <<< "scale=2;(${DUR} - ${ENDTIME} - ${BEGTIME})")
            COMMAND_LINE+=("-t" "${ENDO}")
        fi
    fi

    AUDIOSTUFF=$((MP3OUT + AUDIO_PACK + WAV_OUT))

    if [ "$AUDIOSTUFF" -gt "0" ]; then
        if [ "$CONV_CHECK" == "wav" ]; then     COMMAND_LINE+=("-vn" "-acodec" "pcm_s16le" "-ar" "44100" "-ac" "2")
        elif [ "$CONV_CHECK" == "flac" ]; then  COMMAND_LINE+=("-vn" "-c:a" "flac")
        elif [ "$CONV_CHECK" == "mp3" ]; then   COMMAND_LINE+=("-vn" "-q:a" "0" "-map" "a")
        elif [ "$AUDIO_PACK" == "1" ]; then     COMMAND_LINE+=("-vn" "-codec:a" "libmp3lame" "-q:a" "0" "-v" "error")
        else                                    COMMAND_LINE+=("-q:a" "0" "-map" "a"); fi
    elif [ "${NO_CODEC}" -eq "0" ]; then
        if [ -n "$AUDIODELAY" ]; then      COMMAND_LINE+=("-itsoffset" "$AUDIODELAY" "-c:a" "copy" "-c:v" "copy" "-map" "0:a:0" "-map" "0:v:0")
        elif [ -n "$VIDEODELAY" ]; then    COMMAND_LINE+=("-itsoffset" "$VIDEODELAY" "-c:v" "copy" "-c:a" "copy" "-map" "0:v:0" "-map" "0:a:0")
        elif [ "$COPY_ONLY" == "0" ]; then COMMAND_LINE+=("-bsf:v" "h264_mp4toannexb" "-sn" "-vcodec" "libx264" "-codec:a" "libmp3lame" "-q:a" "0" "-v" "error" "-vf" "scale=$PACKSIZE")
        elif [ "$QUICK" == "1" ]; then     COMMAND_LINE+=("-c:v" "copy" "-c:a" "copy")
        else                               COMMAND_LINE+=("-c:v:1" "copy") && NOMAPPING=1 ; fi

        if [ -z "$AUDIODELAY" ] && [ -z "$VIDEODELAY" ]; then
            if [ -n "$VIDEOTRACK" ] && [ "$AUDIOSTUFF" -eq "0" ]; then
                INCREMENTOR=0
                mapfile -t -d ':' video_array < <(printf "%s" "$VIDEOTRACK")
                for video in "${video_array[@]}"; do COMMAND_LINE+=("-map" "$INCREMENTOR:v:$video"); ((INCREMENTOR++)); done
            elif [ -n "$AUDIOTRACK" ]; then
                COMMAND_LINE+=("-map" "$INCREMENTOR:v:0")
            fi

            if [ -n "$AUDIOTRACK" ]; then
                INCREMENTOR=0
                mapfile -t -d ':' audio_array < <(printf "%s" "$AUDIOTRACK")
                for audio in "${audio_array[@]}"; do COMMAND_LINE+=("-map" "$INCREMENTOR:a:$audio"); ((INCREMENTOR++)); done
            elif [ -n "$VIDEOTRACK" ]; then
                COMMAND_LINE+=("-map" "$INCREMENTOR:a:0")
            fi
        fi
    fi


    [[ "$FILE" == *".mkv" ]] && [ "${#SUB_RUN[@]}" -eq "0" ] && COMMAND_LINE+=("-sn")
    COMMAND_LINE+=("-metadata" "title=")
}

#***************************************************************************************************************
# Find correct mapping positions for video on audio, if no streams have been set
#***************************************************************************************************************
setup_add_packing() {
    debug_print
    [ "${NO_CODEC}" -ne "0" ] && return

    VIDEOID="-1"; AUDIOSTUFF=$((MP3OUT + AUDIO_PACK + WAV_OUT))

    if [ "$AUDIOSTUFF" -eq "0" ]; then
        if [ -z "$VIDEOTRACK" ]; then
            VIDEOID=$(mediainfo '--Inform=Video;%ID%' "$FILE")
            ((VIDEOID--))
        fi

        if [ -z "$AUDIOTRACK" ]; then
            AUDIO_OPTIONS=$(mediainfo '--Inform=Audio;%Language%' "$FILE")

            if [ -z "$AUDIO_OPTIONS" ]; then
                [ "$NOMAPPING" == "0" ] && COMMAND_LINE+=("-map" "0")
            else
                AUDIOID=0; AUDIOFOUND=0

                while [ -n "${#AUDIO_OPTIONS}" ]; do
                    [ "${#AUDIO_OPTIONS}" -lt 2 ] && break
                    [ "${AUDIO_OPTIONS:0:2}" == "$LANGUAGE" ] && AUDIOFOUND=1 && break
                    AUDIO_OPTIONS="${AUDIO_OPTIONS:2}"
                    ((AUDIOID++))
                done

                if [ "$AUDIOFOUND" -eq "1" ] && [ "$VIDEOID" -ge "0" ] && [ "$AUDIOID" -ge "0" ]; then
                    COMMAND_LINE+=("-map" "0:v:$VIDEOID" "-map" "0:a:$AUDIOID")
                    [ "$AUDIOID" -gt "0" ] && LANGUAGE_SELECTED="audio:$LANGUAGE($AUDIOID)"
                else [ "$AUDIOFOUND" -eq "0" ] && [ "$VIDEOID" -ge "0" ]
                    COMMAND_LINE+=("-map" "0")
                fi
            fi
        fi
    fi
}

##########################################################################################
# Calculate estimated total time
# 1 - current time
# 2 - possible video cutout time
##########################################################################################
calculate_estimated_time() {
    T_NOW="$(calculate_time "${1}")"

    if [ "${2}" == "0" ]; then T_VID="$((ORIGINAL_DURATION / 1000))"
    elif [ "${SPLIT_TIME}" -eq "2" ]; then T_VID="${CUTTING_INDICATOR%.*}"
    else T_VID="$(((ORIGINAL_DURATION / 1000) - ${CUTTING_INDICATOR%.*}))"; fi

    ((AVG_CNT++))
    [ "${T_NOW%%.*}" -gt "0" ] && AVG_EST=$(bc <<< "scale=3;(($T_VID / ($T_NOW / $AVG_CNT)) + $SEEKTIME)")
}

##########################################################################################
# Read current fileposition in crop search
# 1 - data line from ffmpeg log
##########################################################################################
read_crop_data_time() {
    DATA="${1}"
    DATA1="${DATA##* t:}"
    CALC_CROP_DATA="${DATA1%.*}"
    re='^[0-9]+$'
    [[ "${CALC_CROP_DATA}" =~ $re ]] && CROP_TIME="${CALC_CROP_DATA}"
    calculate_estimated_time "${CROP_TIME}" "0"
}

##########################################################################################
# Update still timer until app is done
# 1 - start time of PID in seconds
# 2 - pid of application
##########################################################################################
loop_pid_time() {
    debug_print

    AVG_EST=0; AVG_CNT=0; SEEKTIME=1; c_col=0; LAST_DIFFER=0 #c_row=0;

    while [ -n "$1" ] && [ -n "$2" ]; do
        [ "$PROCESS_INTERRUPTED" == "1" ] && break
        DIFFER=$(($(date +%s) - $1))
        if [ "$DIFFER" != "$LAST_DIFFER" ]; then
            [ -f "$PACKFILE" ] && line=$(cat < "${PACKFILE}" | tail -1)
            PRINTOUT_TIME=" $(date -d@${DIFFER} -u +%T)"
            if [[ "$line" == *"time="* ]] || [[ "$line" == *"cropdetect"* ]]; then
                if [[ "$line" != *"cropdetect"* ]]; then
                    PRINT_ITEM="${line##*time=}"
                    calculate_estimated_time "${PRINT_ITEM%% *}" "${CUTTING_INDICATOR}";
                    PRINT_ITEM="${PRINT_ITEM%%.*}"
                else
                    read_crop_data_time "${line}"
                    PRINT_ITEM="$(calc_giv_time "${CROP_TIME}")"
                fi
                [ "${AVG_EST}" != "0" ] && PRINTOUT_TIME+="/$(calc_giv_time "${AVG_EST}")"

                if [ "$SPLIT_TIME" -eq "0" ]; then PRINTOUT=" file:${PRINT_ITEM}/${FILEDURATION}"
                elif [ "$SPLIT_TIME" -eq "2" ]; then PRINTOUT=" file:${PRINT_ITEM}/$(calc_giv_time "${CUTTING_INDICATOR}")"
                else PRINTOUT=" file:${PRINT_ITEM}/$(calc_giv_time "$(((ORIGINAL_DURATION / 1000) - ${CUTTING_INDICATOR%.*}))")"; fi
            elif [ "$MASSIVE_SPLIT" -gt "0" ] || [ "${CUTTING_TIME%.*}" -gt "0" ]; then
                PRINTOUT=" seeking position"
                ((SEEKTIME++))
            fi

            if [[ "$PRINTOUT" != *"seeking"* ]]; then PRINTOUT_ITEM="$(printf "%s%s%s%s" "$CC" "$PRINTOUT_TIME" "${CB}" "$PRINTOUT")"
            else PRINTOUT_ITEM="$(printf "%s%s%s%s" "$CC" "$PRINTOUT_TIME" "${CY}" "$PRINTOUT")"; fi
            print_last_pos "${PRINTOUT_ITEM}      "

            if ! kill -s 0 "$2" >/dev/null 2>&1; then break; fi
        fi
        [ "$PROCESS_INTERRUPTED" == "1" ] && break
        LAST_DIFFER="$DIFFER"
    done

    printf "%s" "${CO}"
}

#***************************************************************************************************************
# Check ffmpeg output for errors and act accordingly
#***************************************************************************************************************
check_output_errors() {
    debug_print
    [ ! -f "$PACKFILE" ] && return

    app_err=$(grep -E 'Invalid data found when processing input|not found|error in an external library|invalid format character|Unknown error' "$PACKFILE" | awk -F ':' '{print $2}')

    if [ -n "$app_err" ]; then
        #printf "\n    %s error:%s%s%s %s%s\n" "${APP_STRING}" "$CR" "$app_err" "$CC" "$(calc_dur)" "$CO"
        [ "$ERROR" == "0" ] && ERROR=9 && FAILED_FUNC="${FUNCNAME[0]} err:${app_err}"

        if [ "$EXIT_VALUE" == "1" ]; then
            delete_file "$PACKFILE" "15"
            handle_file_rename 0 6
            temp_file_cleanup "1"
        fi
        RETVAL=6
    fi

    # Cropping uses the outputfile to find the best dimensions, so keep the file
    [ -z "$CROP" ] && delete_file "$PACKFILE" "16"
}

#***************************************************************************************************************
# Verify that time position is withing the timelimit
# 1 - file time
# 2 - position time
# 3 - error reason
#***************************************************************************************************************
verify_time_position() {
    debug_print
    if [ -z "$1" ] || [ -z "$2" ] || [ "$1" == "D" ] || [ "$2" == "D" ]; then return; fi

    if [ "${2%.*}" -gt "${1%.*}" ]; then
        printf "%s %s%s %s exceeds the file time %s%s\n" "$(print_info)" "$CR" "${3}" "$(lib t f "${2}")" "$(lib t f "${1}")" "$CO"
        ERROR=13; RETVAL=7; FAILED_FUNC="${FUNCNAME[0]}"
    fi
}

#***************************************************************************************************************
# Pack file by using enviromental variables
#***************************************************************************************************************
simply_pack_file() {
    debug_print

    setup_file_packing
    [ "$ERROR" != "0" ] && return
    [ "$ENDPOINT" != "0" ] && ENDTIME="${ENDPOINT}"

    PRINTLINE="$(print_info)"
    [ "$EXIT_REPEAT" == "2" ] && PRINTLINE+=" retrying"

    SPLIT_TIME=0
    if   [ "$AUDIO_PACK" == "1" ]; then         PRINTLINE+=$(printf " Packing %s to %s " "$EXT_CURR" "$CONV_CHECK")
    elif [ "$MP3OUT" == 1 ]; then               PRINTLINE+=$(printf " Extracting %s " "$CONV_CHECK")
    elif [ "${X}" == "${X_WIDTH}" ]; then
        if [[ "$FILE" != *"$CONV_TYPE" ]]; then PRINTLINE+=$(printf " Transforming to %s " "$CONV_TYPE")
        else                                    PRINTLINE+=$(printf " Repacking "); fi
    elif [ "$COPY_ONLY" == "0" ]; then          PRINTLINE+=$(printf " Packing to %4dx%-4d " "$X_WIDTH" "$Y_HEIGHT")
    elif [ "$SPLIT_AND_COMBINE" == "1" ]; then  PRINTLINE+=$(printf " Combo split %2d/%-2d " "${COMBOARRAYPOS}" "${COMBOARRAYSIZE}") && SPLIT_TIME=2
    elif [ "$MASS_SPLIT" == "1" ]; then         PRINTLINE+=$(printf " Splitting %2d/%-2d " "${COMBOARRAYPOS}" "${COMBOARRAYSIZE}") && SPLIT_TIME=2
    elif [ "${CUTTING_TIME%.*}" -gt 0 ]; then   PRINTLINE+=$(printf " Cutting ") && SPLIT_TIME=1
    else                                        PRINTLINE+=$(printf " Copying "); fi

    ORIGINAL_DURATION=$(get_file_duration "$FILE" "1")
    ORG_DUR=$((ORIGINAL_DURATION / 1000))

    if [ "$MASSIVE_SPLIT" == 1 ] || [ "${ENDPOINT}" != "0" ]; then  PRINTLINE+=$(printf "to %-6s " "$(calc_giv_time "${CUTTING_INDICATOR%.*}")")
    elif [ "$AUDIO_PACK" == "1" ]; then                             PRINTLINE+=$(printf "audio ")
    elif [ "$MP3OUT" == 1 ] && [ "${CUTTING_TIME%.*}" -gt 0 ]; then PRINTLINE+=$(printf "%-6s " "$(calc_giv_time $((ORG_DUR - ${CUTTING_TIME%.*})))")
    elif [ "${CUTTING_TIME%.*}" -gt 0 ]; then                       PRINTLINE+=$(printf "by %-s " "$(calc_giv_time "${CUTTING_TIME%.*}")"); fi

    [ -n "$WORKNAME" ] && PRINTLINE+="(mode:$WORKNAME) "
    [ -n "$LANGUAGE_SELECTED" ] && PRINTLINE+="$LANGUAGE_SELECTED "
    [ "$MASSIVE_SPLIT" == 1 ] && MASSIVE_TIME_SAVE="$(bc <<< "scale=0;(${MASSIVE_TIME_SAVE} + (${ORG_DUR} - ${CUTTING_TIME}))")"

    if [ "${CUTTING_TIME%.*}" -gt 0 ]; then
        verify_time_position "$ORG_DUR" "$CUTTING_INDICATOR" "Cutting time"
        [ "$ERROR" != "0" ] && return
    fi

    if [ -n "$SUBFILE" ] && [ "$SUBERR" = "0" ]; then
        if [ -n "$SUBLANG" ]; then   PRINTLINE+=$(printf "Sub:%s " "$SUBLANG")
        elif [ -f "$SUBFILE" ]; then PRINTLINE+=$(printf "Sub:%s " "${SUBFILE:0:10}"); fi
    fi

    run_pack_app
}

#***************************************************************************************************************
# Run APP NAME with given options
#***************************************************************************************************************
run_pack_app() {
    debug_print
    setup_add_packing

    process_start_time=$(date +%s); FILEDURATION=$(lib V d "$FILE"); ERROR=0

    [ -n "$CMD_PRINT" ] && printf "\n%s %s %s\n" "$CY" "${COMMAND_LINE[*]}" "$CO"
    [ "$BUGME" -eq "1" ] && printf "\n    %s%s -i \"%s\" %s \"%s%s\"%s\n" "$CP" "$APP_STRING" "$FILE" "${COMMAND_LINE[*]}" "${FILE}" "${CONV_TYPE}" "$CO"

    printf "%s" "${PRINTLINE}"

    ((RUNTIMES++))
    $APP_NAME -i "$FILE" "${COMMAND_LINE[@]}" "${FILE}${CONV_TYPE}" -v info 2>"${PACKFILE}" &
    PIDOF=$!
    loop_pid_time "$process_start_time" "$PIDOF"
    PIDOF=0
    [ "$PROCESS_INTERRUPTED" == "1" ] && return
    clear_column
    printf "\r%s" "$PRINTLINE"
    check_output_errors
}

#***************************************************************************************************************
# Read subtitle language from embedded video
# 1 - filename
# 2 - Subtitle track ID
# 3 - If set, will not print successfully read info
#***************************************************************************************************************
get_sub_info() {
    debug_print

    SUBERR=0; SUBDATA=$(mediainfo "$1"); SUBVAL="$2"; ((SUBVAL++)); SINGLESUB=$(printf "%s" "$SUBDATA" |grep -e "Text #$SUBVAL" -m 1 -A 12)
    [ -z "$SINGLESUB" ] && SINGLESUB=$(printf "%s" "$SUBDATA" |grep -e "Text" -m 1 -A 12)
    SUBLANG=$(printf "%s" "$SINGLESUB" |grep -e "Language"); SUBLANG="${SUBLANG##*: }"; SUBTITLE=$(printf "%s" "$SINGLESUB" |grep -e "Title"); SUBTITLE="${SUBTITLE##*: }"

    if [ -z "$SUBLANG" ]; then
        SUBCOUNT=$(mediainfo '--Inform=General;%TextCount%;' "$1")
        [ "${SUBCOUNT}" == "1" ] && SUBLANG="Unknown"
    fi

    if [ -z "$SUBLANG" ]; then
        PRINTLINE+=$(printf "%slanguage not found for index '%s' %s\n" "$CR" "$2" "$CO")
        SUBERR=1
    elif [ "$SUBLANG" != "English" ] && [ "$SUBLANG" != "Unknown" ]; then
        printf "\n    Read language is not english? Proceed with '%s' (y/n)?" "$SUBLANG"
        read -rsn1 -t 1 sinput
        [ "$sinput" != "y" ] && printf "Aborting burning\n" && SUBERR=1 && ERROR=59 && FAILED_FUNC="${FUNCNAME[0]}"
    elif [ -z "$3" ]; then
        PRINTLINE+=$(printf "Language:%s " "$SUBLANG")
        [ -n "$SUBTITLE" ] && PRINTLINE+=$(printf "Title:'%s' " "${SUBTITLE:0:20}")
    fi
}

#***************************************************************************************************************
# Burn subtitle file to a given video file
# 1 - Subtitle file
#***************************************************************************************************************
burn_subs() {
    debug_print

    if [ "$SPLIT_AND_COMBINE" -eq "1" ] && [[ ! "$APP_STRING" =~ "ffmpeg" ]]; then
        printf "%sCannot burn subs with %s%s%s Aborting!%s\n" "$CR" "$CY" "$APP_STRING" "$CR" "$CO"
        temp_file_cleanup "1"
    fi

    MKVSUB=""; RETVAL=0; SUB="$1"

    if [ "$SUB" == "self:" ]; then
        END="${SUB##*:}"
        SUB="${1%.*}.${END}"
    else
        re='^[0-9]+$'
        [[ $SUB =~ $re ]] && MKVSUB="$SUB" && SUB="$FILE"
    fi

    if [ -f "$FILE" ]; then
        if [ -f "$SUB" ]; then
            PRINTLINE="$(print_info) burning subs "
            [ -n "$MKVSUB" ] && get_sub_info "$SUB" "$MKVSUB" || PRINTLINE+=$(printf "File:'%s' " "$SUB")
            ERROR=0
            X=$(mediainfo '--Inform=Video;%Width%' "$FILE")
            Y=$(mediainfo '--Inform=Video;%Height%' "$FILE")
            ORIGINAL_DURATION=$(get_file_duration "$FILE")
            #PRINTLINE+="$(printf "(%4dx%-4d|%s) " "$X" "$Y" "$(calc_giv_time "$((ORIGINAL_DURATION / 1000))")")"

            if [ "$SUBERR" == "0" ]; then
                if [ -n "$MKVSUB" ]; then COMMAND_LINE=("-vf" "subtitles='$SUB':stream_index=$MKVSUB")
                else COMMAND_LINE=("-vf" "subtitles=$SUB"); fi
                [ "$BUGME" -eq "1" ] && printf "\n    %s%s -i \"%s\" %s%s\n" "$CP" "$APP_STRING" "$FILE" "${COMMAND_LINE[*]}" "$CO"
                run_pack_app

                ORGSIZE=$(du -k "$FILE" | cut -f1); SUBSIZE=0
                [ -z "$MKVSUB" ] && SUBSIZE=$(du -k "$SUB" | cut -f1)
                NEWSIZE=$(du -k "${FILE}${CONV_TYPE}" | cut -f1)
                NEWSIZE=$((ORGSIZE + SUBSIZE - NEWSIZE))
                ((TOTALSAVE += NEWSIZE))

                if [ "$ERROR" -eq "0" ]; then
                    if [ "$KEEPORG" == "0" ]; then
                        delete_file "$FILE" "17"
                        [ -f "$SUB" ] && delete_file "$SUB" "18"
                        filename="${FILE%.*}"
                        move_file "${FILE}${CONV_TYPE}" "${TARGET_DIR}" "${filename}${CONV_TYPE}" "9" "1"
                    fi
                    printf "%ssaved %s %sin %s%s\n" "$CG" "$(check_valuetype "${NEWSIZE}")" "$CC" "$(calc_time_tk)" "$CO"
                else
                    printf "%sFailed (%s) %sin %s%s\n" "$CR" "$ERROR" "$CC" "$(calc_time_tk)" "$CO"
                    delete_file "${FILE}${CONV_TYPE}" "19"
                    RETVAL=8
                fi
            else
                printf "%s%s%s Subfile file:%s mkv:%s not found! suberr:%s%s\n" "$CY" "$(print_info)" "${1:0:40}" "$SUB" "$MKVSUB" "$SUBERR" "$CO"
            fi
        else
            printf "%s%s%s Subfile file:%s mkv:%s not found!%s\n" "$CY" "$(print_info)" "${1:0:40}" "$SUB" "$MKVSUB" "$CO"
        fi
    else
        printf "%s%s%s not found (subs)!%s\n" "$CR" "$(print_info)" "${1:0:40}" "$CO"
        ERROR=2; FAILED_FUNC="${FUNCNAME[0]}"
    fi

    [ "$EXIT_VALUE" == "1" ] && [ "$ERROR" != "0" ] && temp_file_cleanup "$ERROR"
}

#***************************************************************************************************************
# Make a filename with incrementing value
# 1 - if set, will be used as the new name (no extension!)
#     + to increase the filenumber automatically
#     - to reset the filenumber to 1
# 2 - if set 1 set as + then this will be used as the new name (no extension!)
#***************************************************************************************************************
make_running_name() {
    debug_print
    O_FILE=""; NNAME=""

    if [ -n "$1" ]; then
        if [ "${1}" == "+" ]; then ((RUNNING_FILE_NUMBER++)); shift
        elif [ "${1}" == "-" ]; then RUNNING_FILE_NUMBER=1; shift
        else O_FILE="$FILE"; FILE="$1"; NNAME="1"; shift; fi
    fi

    if [ -n "$1" ]; then O_FILE="$FILE"; FILE="$1"; NNAME="1"; shift; fi

    ExtLen=${#EXT_CURR}; NameLen=${#FILE}; LEN_NO_EXT=$((NameLen - ExtLen - 1))
    [ "${LEN_NO_EXT}" -le "0" ] && LEN_NO_EXT="${#1:-${#FILE}}"

    if [ -z "$NEWNAME" ] || [ -n "${NNAME}" ]; then RUNNING_FILENAME="${FILE:0:$LEN_NO_EXT}"
    else                                            RUNNING_FILENAME="$NEWNAME"; fi

    RUNNING_FILENAME+="$(printf "_%02d%s" "$RUNNING_FILE_NUMBER" "$CONV_TYPE")"
    if [ "$SPLIT_AND_COMBINE" == "1" ] && [ -z "${NNAME}" ]; then RUNNING_FILENAME="COMBO_${RUNNING_FILENAME}"; fi

    if [ -n "${O_FILE}" ]; then FILE="$O_FILE"; fi
}

#***************************************************************************************************************
# Make a new running filename
# 1 - if set, will be used as new name, instead of $FILE
#***************************************************************************************************************
make_new_running_name() {
    debug_print

    if [ -n "$1" ]; then O_FILE="$FILE"; FILE="${1##*/}"; fi
    make_running_name "-"

    if [ -f "${TARGET_DIR}/$RUNNING_FILENAME" ]; then
        while true; do
            make_running_name "+"
            [ ! -f "${TARGET_DIR}/$RUNNING_FILENAME" ] && break
        done
    fi

    if [ -n "$1" ]; then FILE="$O_FILE"; fi
}

#***************************************************************************************************************
# When keeping an original file, make the extracted piece it's own unique number, so many parts can be extracted
#***************************************************************************************************************
move_to_a_running_file() {
    debug_print

    make_new_running_name ""
    move_file "$FILE$CONV_TYPE" "${TARGET_DIR}" "${RUNNING_FILENAME}" "16"
}

#***************************************************************************************************************
# Rename output file to correct format or move unsuccesful file to other directory
# 1 - If bigger than zero, check one file, if 0, process failed and remove target files
#***************************************************************************************************************
handle_file_rename() {
    debug_print

    if [ "$1" -gt 0 ] && [ "$ERROR" -eq 0 ] ; then
        [ "$KEEPORG" == "0" ] && delete_file "$FILE" "20"

        if [ "$KEEPORG" == "0" ]; then
            FNAME="$(fetchname)"
            move_file "$FILE$CONV_TYPE" "${TARGET_DIR}" "${FNAME}" "14" "1"
        else
            move_to_a_running_file
            if [ "${SPLIT_AND_COMBINE}" -eq "0" ] && [ "${MASS_SPLIT}" -eq "0" ]; then FILE="${RUNNING_FILENAME}"; fi
        fi
    else
        [ "$ERROR" -ne "0" ] && printf "%sSomething went wrong, keeping original!%s %s%s err:%s src:%s\n" "$CR" "$CC" "$(calc_dur)" "$CO" "$ERROR" "$2"

        delete_file "$FILE$CONV_TYPE" "21"

        if [ "$EXT_CURR" == "$CONV_CHECK" ] && [ "$COPY_ONLY" == "0" ]; then
            RETVAL=9
            move_file "$FILE" "./Failed" "." "15"
        fi

        [ "$EXIT_VALUE" == "1" ] && temp_file_cleanup "1"
    fi
}

#***************************************************************************************************************
# Calculate dimension ratio change
#***************************************************************************************************************
calculate_packsize() {
    debug_print

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
    ((SCALE -= SCALECORR))

    X_WIDTH="$WIDTH"
    Y_HEIGHT="$SCALE"
    PACKSIZE="$WIDTH"x"$SCALE"
}

#***************************************************************************************************************
# Move file to wanted name/target
# 1 - filename
# 2 - target directory (skipped if set as .)
# 3 - new name (skipped if set as .)
# 4 - source ID for debugging
# 5 - If set, will set new name as FILE
#***************************************************************************************************************
move_file() {
    debug_print "'$1'->'$2/$3' src:$4 update:$5"
    SRCNAME="${1}"; TRGNAME="${3}"; DIRNAME="${2:-.}"

    if [ -z "${TRGNAME}" ]; then
        if [ -f "${DIRNAME}/${SRCNAME}" ]; then make_new_running_name "${SRCNAME}"
        else RUNNING_FILENAME="${SRCNAME}"; fi
    elif [ -f "${DIRNAME}/${TRGNAME}" ]; then make_new_running_name "${TRGNAME}"
    else RUNNING_FILENAME="${TRGNAME}"; fi

    [ ! -d "${DIRNAME}" ] && mkdir -p "${DIRNAME}"
    mv "${SRCNAME}" "${DIRNAME}/${RUNNING_FILENAME}" || ERROR=22
    if [ "${ERROR}" == "22" ]; then
        printf -- "\n%s %smv failed! 1:%s 2:%s 3:%s FILE:%s RUN:%s %s " "${CR}" "${1}" "${2}" "${3}" "${FILE}" "${RUNNING_FILENAME}" "${CO}" "${FUNCNAME[1]}"
    elif [ "${#NAME_RUN[@]}" -eq "0" ] && [ "${FILE}" != "${RUNNING_FILENAME}" ] && [ "$SPLIT_AND_COMBINE" != "1" ]; then
        printf -- "\n%s   -> %s'%s%s'%s " "$(print_info)" "$CT" "$(print_dir "${DIRNAME}")" "${RUNNING_FILENAME}" "$CO"; fi
    [ -n "$5" ] && FILE="${RUNNING_FILENAME}"
}

#***************************************************************************************************************
# Move corrupted file to a Error directory
#***************************************************************************************************************
handle_error_file() {
    debug_print

    #move_file "$FILE" "./Error" "" "1"
    ERROR=19; FAILED_FUNC="${FUNCNAME[0]}"; printf "%s %sSomething corrupted %s%s%s\n" "$(print_info)" "$CR" "$CC" "$(calc_dur)" "$CO"

    [ "$EXIT_VALUE" == "1" ] && temp_file_cleanup "1"
    RETVAL=10
}

#***************************************************************************************************************
# Check how the file was converted and print out accordingly
#***************************************************************************************************************
check_alternative_conversion() {
    debug_print

    xNEW_DURATION=$((NEW_DURATION / 1000)); xORIGINAL_DURATION=$((ORIGINAL_DURATION / 1000)); xNEW_FILESIZE=$((NEW_FILESIZE / 1000)); xORIGINAL_SIZE=$((ORIGINAL_SIZE / 1000))
    PRINT_ERROR_DATA=""; ORIGINAL_SIZE=$ORIGINAL_HOLDER; ENDSIZE=$((ORIGINAL_SIZE - NEW_FILESIZE));
    [ "$IGNORE" == "1" ] && ORIGINAL_SIZE=$((NEW_FILESIZE + 10000))

    if [ "$ORIGINAL_SIZE" -gt "$NEW_FILESIZE" ] || [ "$NEW_DURATION" -lt "$ORIGINAL_DURATION" ]; then
        if [ -n "$CROP" ]; then printf "%sCropped, saved:%s " "$CG" "$(check_valuetype "${ENDSIZE}")"
        elif [ "$SPLIT_AND_COMBINE" == "1" ] || [ "$MASS_SPLIT" == "1" ]; then printf "%ssplit into:%s " "$CG" "$(check_valuetype "${NEW_FILESIZE}")"
        elif [ "$ORIGINAL_SIZE" -gt "$NEW_FILESIZE" ] || [ "$NEW_DURATION" -lt "$ORIGINAL_DURATION" ]; then
            [ "$ENDSIZE" -ge "0" ] && printf "%sResized and saved:%s " "$CG" "$(check_valuetype "${ENDSIZE}")"
            [ "$ENDSIZE" -lt "0" ] && printf "%sResized and saved:%s " "$CR" "$(check_valuetype "${ENDSIZE}")"
            [ "${CUTTING_TIME%.*}" -gt "0" ] && printf "%sShortened by %s " "$CG" "$(lib t f "${CUTTING_TIME%.*}")"
        elif [ "$NEW_DURATION" -gt "$ORIGINAL_DURATION" ] || [ "$ORIGINAL_SIZE" -gt "$NEW_FILESIZE" ]; then
            [ "$NEW_DURATION" -gt "$ORIGINAL_DURATION" ] && PRINT_ERROR_DATA="Duration $(lib t f "$NEW_DURATION")>$(lib t f "$ORIGINAL_DURATION") "
            [ "$ORIGINAL_SIZE" -gt "$NEW_FILESIZE" ] && PRINT_ERROR_DATA="Size $(check_valuetype "$ORIGINAL_SIZE")<$(check_valuetype "$NEWSIZE") "
        else PRINT_ERROR_DATA="Unknown end situation "; fi

        if [ -z "$PRINT_ERROR_DATA" ]; then
            handle_file_rename 1 1
            [ "$DELETE_AT_END" == "1" ] && [ "${DURATION_CUT%.*}" != "0" ] && ((TIMESAVED += ${DURATION_CUT%.*}))
            if [ "$MASSIVE_SPLIT" == "0" ]; then ((TOTALSAVE += ENDSIZE))
            else ((MASSIVE_ENDSIZE += NEW_FILESIZE)); fi
            printf "%s%s" "$CC" "$(calc_dur)"
        fi

        NEW_DURATION=0
    elif [ "$EXT_CURR" == "$CONV_CHECK" ]; then RETVAL=11; ERROR_WHILE_MORPH=1; PRINT_ERROR_DATA="Conversion check (${EXT_CURR}=${CONV_CHECK}) "
    elif [ "$IGNORE_UNKNOWN" == "0" ]; then
        RETVAL=12; ERROR_WHILE_MORPH=1; PRINT_ERROR_DATA="Unknown C:$COPY_ONLY e:$EXT_CURR=$CONV_CHECK "
    else
        handle_file_rename 1 2
        printf "%sWarning, ignoring unknown error:%s %s%s%s, saved:%s" "$CY" "$ERROR" "$CC" "$(calc_dur)" "$CY" "$(check_valuetype "$((ORIGINAL_SIZE - NEW_FILESIZE))")"
    fi

    if [ -n "$PRINT_ERROR_DATA" ]; then
        handle_file_rename 0 3
        printf "%s FAILED!" "$CR"
        [ "$xNEW_DURATION" -gt "$xORIGINAL_DURATION" ] && printf " time:%s>%s" "$xNEW_DURATION" "$xORIGINAL_DURATION" && PRINT_ERROR_DATA=""
        [ "$xNEW_FILESIZE" -gt "$xORIGINAL_SIZE" ] &&  printf " size:%s>%s" "$xNEW_FILESIZE" "$xORIGINAL_SIZE" && PRINT_ERROR_DATA=""
        [ -n "$PRINT_ERROR_DATA" ] && printf " Reason:%s(%s)" "$PRINT_ERROR_DATA" "$ERROR"
        printf " %s%s" "$CC" "$(calc_dur)"
        ((TOTAL_ERR_CNT++)); SPLITTING_ERROR=1; ERROR=91; FAILED_FUNC="${FUNCNAME[0]}"
        [ "$EXIT_REPEAT" -gt "0" ] && ((EXIT_REPEAT++))
    fi

    printf "%s\n" "$CO"

    [ "$TOTAL_ERR_CNT" -gt "3" ] && [ "$EXIT_CONTINUE" == "0" ] && printf "\nToo many errors (%s), aborting!\n" "$TOTAL_ERR_CNT" && temp_file_cleanup "1"
}

#***************************************************************************************************************
# Check file handling, if size is smaller and destination file length is the same (with 2sec error marginal)
#***************************************************************************************************************
check_file_conversion() {
    debug_print

    [ "$PROCESS_INTERRUPTED" == "1" ] && return

    if [ -f "$FILE$CONV_TYPE" ]; then
        if [ "$AUDIO_PACK" == "1" ]; then NEW_DURATION=$(get_file_duration "$FILE$CONV_TYPE" "1")
        else                              NEW_DURATION=$(get_file_duration "$FILE$CONV_TYPE"); fi
        AUDIO_DURATION=$(get_file_duration "$FILE$CONV_TYPE" "1")
        [ -z "$NEW_DURATION" ] && NEW_DURATION=0

        NEW_FILESIZE=$(du -k "$FILE$CONV_TYPE" | cut -f1)
        DURATION_CUT=$(bc <<< "scale=0;((${BEGTIME} + ${ENDTIME}) * 1000)")

        [ "$MASSIVE_SPLIT" == "0" ] && GLOBAL_TIMESAVE="$(bc <<< "scale=0;(${GLOBAL_TIMESAVE} + ${CUTTING_TIME})")"

        ORIGINAL_SIZE=$(du -k "$FILE" | cut -f1)
        ORIGINAL_HOLDER=$ORIGINAL_SIZE

        #if video length matches (with one second error tolerance) and destination file is smaller than original, then
        if [ -z "$AUDIO_DURATION" ]; then
            handle_file_rename 0 4
            printf "%s FAILED! Target has no Audio!%s\n" "$CR" "$CO"
            ((TOTAL_ERR_CNT++))
            SPLITTING_ERROR=2; ERROR=79; FAILED_FUNC="${FUNCNAME[0]}"
            [ "$EXIT_REPEAT" -gt "0" ] && ((EXIT_REPEAT++))
        else
            check_alternative_conversion
        fi

        if [ "$ERROR" == "0" ] && [ -n "$CROP" ]; then CROP_HAPPENED=1; fi
    else
        if [ "$ERROR" != 13 ]; then
            printf "%sNo destination file!%s %s (func:%s)%s\n" "$CR" "$CC" "$(calc_dur)" "$FAILED_FUNC" "$CO"
            #move_file "$FILE" "./Nodest" "" "2"
        fi
        remove_interrupted_files
        RETVAL=13
        [ "$EXIT_VALUE" == "1" ] && temp_file_cleanup "1"
    fi
}

#***************************************************************************************************************
# Check what kind of file handling will be accessed
#***************************************************************************************************************
handle_file_packing() {
    debug_print

    [ ! -f "$FILE" ] && return

    ORIGINAL_SIZE=$(du -k "$FILE" | cut -f1)
    get_space_left

    if [ "$ORIGINAL_SIZE" -gt "$SPACELEFT" ] && [ "$IGNORE_SPACE_SIZE" -eq "0" ]; then
        printf "%s%s Not enough space left! File:%s > harddrive:%s%s\n" "${CR}" "$(print_info)" "$ORIGINAL_SIZE" "$SPACELEFT" "${CO}"
        [ "$IGNORE_SPACE" -eq "0" ] && [ "$NO_EXIT_EXTERNAL" == "0" ] && temp_file_cleanup "1"
        EXIT_EXT_VAL=1; ERROR=99; FAILED_FUNC="${FUNCNAME[0]}"
        return
    fi

    Y=$(mediainfo '--Inform=Video;%Height%' "$FILE")
    ORIGINAL_DURATION=$(get_file_duration "$FILE")
    DUR=$((ORIGINAL_DURATION / 1000))
    if [ "${ENDPOINT}" != "0" ]; then CUTTING_TIME=$(bc <<< "scale=0;(${ENDPOINT} - ${BEGTIME})")
    else CUTTING_TIME=$(bc <<< "scale=0;(${BEGTIME} + ${ENDTIME})"); fi

    if [ "$SPLIT_AND_COMBINE" -gt "0" ] || [ "$MASS_SPLIT" -gt "0" ]; then CUTTING_INDICATOR=$(bc <<< "scale=0;(${ENDTIME} - ${BEGTIME})")
    elif [ "${ENDPOINT}" != "0" ]; then CUTTING_INDICATOR=$(bc <<< "scale=0;(${ENDPOINT} - ${BEGTIME})")
    else CUTTING_INDICATOR=$(bc <<< "scale=0;(${ENDTIME} + ${BEGTIME} + ${ENDPOINT})"); fi

    XP=$(mediainfo '--Inform=Video;%Width%' "$FILE")
    X_WIDTH="$XP"; Y_HEIGHT="$Y"
    if [ "$REPACK" == 1 ] && [[ "$DIMENSION_PARSED" == "0" || "$XP" -le "$WIDTH" ]]; then
        PACKSIZE="${XP}:${Y}"
        COPY_ONLY=0
    else
        calculate_packsize
    fi

    if [ -n "$CROP" ]; then check_and_crop
    else simply_pack_file; check_file_conversion; fi
}

#***************************************************************************************************************
# Get space left on target directory
#***************************************************************************************************************
get_space_left() {
    debug_print

    [ ! -d "${TARGET_DIR}" ] && mkdir -p "${TARGET_DIR}"
    FULL=$(df -k "${TARGET_DIR}" |grep "/")
    mapfile -t -d ' ' space_array < <(printf "%s" "$FULL")
    f_cnt=0; SPACELEFT=0

    # Seek out the fourth column, since it's split by spaces
    for m_cnt in "${!space_array[@]}"; do
        if [ -n "${space_array[$m_cnt]}" ]; then
            ((f_cnt++))
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
pack_file() {
    debug_print

    check_workmode
    process_start_time=$(date +%s)

    EXT_CURR="${FILE##*.}"
    [ "$START_POSITION" -gt "$CURRENTFILECOUNTER" ] && return
    [ "$END_POSITION" -gt "0" ] && [ "$CURRENTFILECOUNTER" -ge "$END_POSITION" ] && return
    # if not SYS_INTERRUPTrupted and WORKMODE is for an existing dimensions
    X=$(mediainfo '--Inform=Video;%Width%' "$FILE")
    [ "$EXIT_REPEAT" -gt "0" ] && EXIT_REPEAT=1

    if [ ! -f "$FILE" ]; then
        ((MISSING++))
        if [ "$PRINT_ALL" == 1 ]; then ERROR=6; FAILED_FUNC="${FUNCNAME[0]}"; printf "%s %sis not found (pack file)!%s\n" "$(print_info)" "$CR" "$CO"; fi
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
            printf "%s %scannot be packed %s <= %s%s\n" "$(print_info)" "$CY" "$X" "$WIDTH" "$CO"
            RETVAL=14
        else
            [ -z "${desired}" ] && printf "%s %sAlready at desired size wanted:%s current:%s%s\n" "$(print_info)" "$CT" "${WIDTH}" "${X}" "$CO"
            desired=1
            [[ "${FILE}" == *"${CONV_TYPE}" ]] && [ -z "${FETCHURL}" ] && ((RUNTIMES++))
        fi
    elif [ "$PRINT_ALL" == 1 ]; then
        printf "%s width:%s skipping\n" "$(print_info)" "$X"
    fi
}

#***************************************************************************************************************
# Calculate time taken to process data
# 1 - if set, get looptime instead
#***************************************************************************************************************
calc_time_tk() {
    debug_print

    JUST_NOW=$(date +%s)
    SCRIPT_TOTAL_TIME=$((JUST_NOW - script_start_time))
    LOOP_TOTAL_TIME=$((JUST_NOW - loop_start_time))
    LOOP_TOTAL_TIME=$(date -d@${LOOP_TOTAL_TIME} -u +%T)
    if [ -n "$1" ]; then printf "%s" "$LOOP_TOTAL_TIME"; return; fi

    if [ "$SCRIPT_TOTAL_TIME" -gt "86399" ]; then
        DAYS_TOTAL=0

        while [ "$SCRIPT_TOTAL_TIME" -gt "86399" ]; do
            ((DAYS_TOTAL++))
            ((SCRIPT_TOTAL_TIME -= 86400))
        done

        TIMER_TOTAL_PRINT=$(date -d@${SCRIPT_TOTAL_TIME} -u +%T)
        TIMER_TOTAL_PRINT="${DAYS_TOTAL}:${TIMER_TOTAL_PRINT}"
    else
        TIMER_TOTAL_PRINT=$(date -d@${SCRIPT_TOTAL_TIME} -u +%T)
    fi

    printf "%s" "$TIMER_TOTAL_PRINT"
}

#***************************************************************************************************************
# Change given time in seconds to HH:MM:SS.MS
# 1 - time in seconds
# 2 - If set, will add this string to the beginning of the printout
#***************************************************************************************************************
calc_giv_time() {
    debug_print
    re='^[0-9.]+$'
    if [[ ! "${1}" =~ $re ]]; then printf "%s" "${1} - ${FUNCNAME[1]}"; return; fi
    [ "${1%.*}" -eq "0" ] && return

    if [ -z "$1" ]; then
        TIMER_SECOND_PRINT="0"; VAL_HAND=0
    else
        VAL_HAND="${1%.*}"
        [ "${VAL_HAND}" -lt "0" ] && VAL_HAND=$((VAL_HAND * -1))

        if [ "$VAL_HAND" -lt "60" ]; then     TIMER_SECOND_PRINT="$VAL_HAND"
        elif [ "$VAL_HAND" -lt "3600" ]; then TIMER_SECOND_PRINT=$(date -d@${VAL_HAND} -u +%M:%S)
        else                                  TIMER_SECOND_PRINT=$(date -d@${VAL_HAND} -u +%T); fi
    fi

    printf "%s" "${2}${TIMER_SECOND_PRINT}"
}

#***************************************************************************************************************
# Verify that all necessary programs are installed
#***************************************************************************************************************
verify_necessary_programs() {
    debug_print

    missing=()
    hash ffmpeg 2>/dev/null || missing+=("ffmpeg")
    hash mediainfo 2>/dev/null || missing+=("mediainfo")
    hash rename 2>/dev/null || missing+=("rename")
    hash recode 2>/dev/null || missing+=("recode")

    if [ "${#missing[@]}" -gt 0 ]; then
        printf "Missing necessary programs: "
        for miss in "${missing[@]}"; do printf "%s " "$miss"; done; printf "\n"
        EXIT_EXT_VAL=1
        temp_file_cleanup "1"
    fi
}

#***************************************************************************************************************
# Verify that filename doesn't have apostrophe, as that will break the combining-part
#***************************************************************************************************************
check_filename_acceptance() {
    debug_print

    NAMECHANGE="${FILE//\'/}"
    #NAMECHANGE=$(printf "%s" "$NAMECHANGE" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")
    [ "$NAMECHANGE" != "$FILE" ] && move_file "$FILE" "" "$NAMECHANGE" "19" "1"
}

#***************************************************************************************************************
# Remove all unnecessary files after process is interrupted or done
# 1 - Exit errorcode
# 2 - if set, means basic exit, remove only partial files
#***************************************************************************************************************
temp_file_cleanup() {
    debug_print

    [ -n "$wait_start" ] && exit 0
    [ -z "$2" ] && remove_interrupted_files
    [ -z "$2" ] && remove_broken_split_files
    delete_file "$PACKFILE" "27"
    [ -z "$2" ] && remove_combine_files
    [ "$PRINT_INFO" -eq "0" ] && delete_file "$RUNFILE" "31"
    save_sizefile
    [ "$NO_EXIT_EXTERNAL" == "0" ] && exit "$1"
}

#***************************************************************************************************************
# Run packing command
# 1 - packing type
# 2@ - the command array
#***************************************************************************************************************
run_pack_command() {
    debug_print

    CMD="$1"
    shift
    reset_handlers "${CMD}"
    [ "$CMD" == "repack" ] && parse_handlers "repack"
    for var in "${@}"; do parse_data "$var"; done
    [ "$CMD" != "mass" ] && handle_packing "$CMD"
}

#***************************************************************************************************************
# Wait for other running packAll to finish
#***************************************************************************************************************
wait_for_running_package() {
    debug_print

    PID_ITEMS="$(pidof ${APP_NAME})"
    [ -z "${PID_ITEMS}" ] && rm "${RUNFILE}" && return

    lcnt=0
    wait_start=$(date +%s)
    RND_NMB="$(more /dev/urandom | tr -cd '2-9' | head -c 1)"   # Create a random string to avoid possible collisions

    while [ -f "$RUNFILE" ]; do
        printf "Already running another copy, delaying! (found: %s). Waited for %s\r" "$RUNFILE" "$(lib t F "$wait_start")"
        sleep 1
        ((lcnt++))
        [ ! -f "${RUNFILE}" ] && sleep "${RND_NMB}"
    done
    [ "$lcnt" -gt "0" ] && printf "\n"
    wait_start=""
}

#***************************************************************************************************************
# The MAIN VOID function
#***************************************************************************************************************
if [ "$#" -le 0 ]; then print_help; exit 0; fi

if [ "$1" == "combine" ]; then COMBINEFILE=1; shift
elif [ "$1" == "merge" ]; then COMBINEFILE=2; shift
elif [ "$1" == "append" ]; then COMBINEFILE=3; shift; fi

print_last_pos "" "" ""
for var in "$@"; do
    if [ "$COMBINEFILE" != "0" ]; then
        COMBINELIST+=("$var")
    else
        parse_data "$var" "1"
        [ "$ERROR" != "0" ] && break
        ((CHECKRUN++))
    fi
done
update_printlen

if [ "$PRINT_INFO" -eq "0" ]; then
    [ -f "$RUNFILE" ] && wait_for_running_package
    printf "run" > "$RUNFILE"
fi

[ "${PRINT_INFO}" -eq "0" ] && reset_handlers
verify_necessary_programs

if [ "$ERROR" != "0" ]; then
    printf "%sSomething went (%s/%s) wrong with calculation (or something else)! Error:%s in :%s%s\n" "${CR}" "${1}" "${FILE_STR}" "$ERROR" "$FAILED_FUNC" "${CO}"
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
    read_sizefile
    shopt -s nocaseglob
    if [ "$PRINT_INFO" -gt "0" ]; then for var in "${PACK_RUN[@]}"; do parse_data "$var"; done; fi

    for FILE in *"$FILE_STR"*; do
        [ "${PROCESS_INTERRUPTED}" -ne "0" ] && break
        check_fileskip "${FILE}"

        check_filename_acceptance "${FILE}"
        loop_start_time=$(date +%s); RUNTIMES=0; DURATION_CUT=0; ERROR=0; ((CURRENTFILECOUNTER++))

        print_info "1"
        [ "${SKIPTRUE}" -gt "0" ] && printf "%s%s File in skiplist, nothing to do!%s\n" "$(print_info)" "${CT}" "${CO}" && continue
        [ "$PRINT_INFO" -gt "0" ] && continue
        #ORIGINAL_FILENAME="${FILE}"

        if [ "${#SUB_RUN[@]}" -gt "0" ]; then                         run_pack_command "subs" "${SUB_RUN[@]}"; fi
        if [ "${#CROP_RUN[@]}" -gt "0" ] && [ "$ERROR" == "0" ]; then run_pack_command "file" "${CROP_RUN[@]}"; fi

        if [ "$ERROR" == "0" ] && { [ "${#PACK_RUN[@]}" -gt "0" ] || [[ "$FILE" != *"$CONV_TYPE" ]]; }; then
            if [ "$CUTTING" -eq "0" ]; then for var in "${CUT_RUN[@]}"; do PACK_RUN+=("$var"); done; CUT_RUN=(); fi
            if [[ "$FILE" != *"$CONV_TYPE" ]] && [ "$ERROR" == "0" ]; then run_pack_command "repack" "${PACK_RUN[@]}"
            else                                                           run_pack_command "file" "${PACK_RUN[@]}"; fi
        fi

        if [ "${#MASS_RUN[@]}" -gt "0" ] && [ "${ERROR}" == "0" ]; then for mass in "${MASS_RUN[@]}"; do run_pack_command "mass" "${CUT_RUN[@]}" "$mass"; done
        elif [ "${#CUT_RUN[@]}" -gt "0" ] && [ "${ERROR}" == "0" ]; then                                 run_pack_command "cut" "${CUT_RUN[@]}"; fi

        if [ "${#NAME_RUN[@]}" -gt "0" ] && [ "${ERROR}" == "0" ]; then run_pack_command "rename" "${NAME_RUN[@]}"; fi

        if [ "$RUNTIMES" -eq "0" ] && [ "$ERROR" == "0" ]; then printf "%s No specific rules given, checking if there's something to do\n" "$(print_info)"; handle_packing "other"; fi
        if [ "$ERROR" == "0" ] && [ "$RUNTIMES" -gt "0" ]; then ((SUCCESFULFILECNT++)); fi

        if [ "$RUNTIMES" -gt "1" ] && [ "$ERROR" -eq "0" ]; then
            LOOPSAVE=$((TOTALSAVE - LOOPSAVE))
            update_saved_time
            printf "%s%s TOTAL saved size:%s time:%s%s in %s%s\n" "$CG" "$(print_info)" "$(check_valuetype "$LOOPSAVE")" "$(calc_giv_time "$TIMESAVED")" "$C13" "$(calc_time_tk "loop")" "$CO"
            [ -n "$GLOBAL_FILECOUNT" ] && ((GLOBAL_FILECOUNT++))
        elif [ "$ERROR" != "0" ] && [ "$ERROR" != "66" ]; then
            printf "%s%s Error:%s at function:%s %sin %s%s\n" "$CR" "$(print_info)" "$ERROR" "$FAILED_FUNC" "$CC" "$(calc_time_tk "loop")" "$CO"
        fi

        desired=""
        [ "${PROCESS_INTERRUPTED}" -eq "1" ] && break
    done
    shopt -u nocaseglob

    if [ "$CURRENTFILECOUNTER" -gt "1" ] && [ "$PRINT_INFO" == "0" ]; then print_total
    else ((GLOBAL_FILESAVE += TOTALSAVE)); fi
else
    printf "%sNo file(s) found (first step)!%s\n" "$CR" "$CO"
    ERROR=8; RETVAL=16
fi

[ "$PRINT_INFO" -gt "0" ] && printf "Total Size:%s Duration:%s in %s files\n" "$(check_valuetype "${PRINTSIZE}")" "$(calc_giv_time "$PRINTLENGTH")" "$CURRENTFILECOUNTER"

[ "${MASSIVE_TIME_SAVE%.*}" -gt "0" ] && ((GLOBAL_TIMESAVE += (ORIGINAL_DURATION / 1000) - ${MASSIVE_TIME_SAVE%.*}))
[ "$PRINT_INFO" -eq "0" ] && temp_file_cleanup "$RETVAL" "1"
save_sizefile
