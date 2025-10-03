#!/bin/bash

#**************************************************************************************************************
# Print error and exit
#**************************************************************************************************************
err() {
    Color.sh red
    printf "%s\n" "${1}"
    Color.sh

    exit 1
}

#**************************************************************************************************************
# Print function debug if enabled
#**************************************************************************************************************
debug() {
    if [ "$DEBUG_PRINT" == 1 ]; then printf "%s\n" "${FUNCNAME[1]}"; fi
}

#**************************************************************************************************************
# If the script is cancelled, will stop all functionlity
#**************************************************************************************************************
set_int () {
    err "$0 has been interrupted!"
}

trap set_int SIGINT SIGTERM

#**************************************************************************************************************
# Initialize arguments
#**************************************************************************************************************
init () {
    FILENAME=""         # Current filename
    SILENCEDATA=""      # Current file's silencedata
    DURATION=5          # Duration of silence to be seeked
    NOISE=0.001         # Noise limit, to be concidered silence
    FILE=""             # Output filename for filelist
    SPLIT=false         # Enable split of file
    TARGET_EXT=""       # Convert input to this format
    DELETE=false        # Delete original file after done
    ERROR=0             # Error has happened during extraction
    error_code=0        # Error checking code for external functionalities
    NAMEPATH=""         # path to text file with previously given filenames in order
    CURRENT_NAME=""     # trackname found from the file
    TARGET_DIR=""       # Directory where to put the output files
    INFO_FROM_FILE=""   # Split data from file instead of silence
    NAMECOUNT=0         # Number of tracks in the namefile
    trackInfo=()
}

#**************************************************************************************************************
# Print help options
#**************************************************************************************************************
print_help() {
    printf -- "Usage: %s -options\n\n" "${0}"
    printf -- "Options with arguments:\n"
    printf -- "-h    This help window\n"
    printf -- "-i    Input filename or directory (works also without prefix)\n"
    printf -- "-d    Minimum duration in seconds to be calculated as silence (default: 5)\n"
    printf -- "-n    Noise level maximum to be calculated as silence (default: 0.001)\n"
    printf -- "-f    Output filename for list of files with silence (instead of splitting)\n"
    printf -- "-t    Target output format extension (default: input filetype)\n"
    printf -- "-F    Path to filenames in order to put as output tracks (add to D:target path to file for automatic output dir)\n"
    printf -- "-T    Path to output directory\n"
    printf -- "-S    Path to file with splitting information (start-end;trackname)\n\n"
    printf -- "Options without arguments: \n"
    printf -- "-s    Split input file to files without silence\n"
    printf -- "-D    Delete input file after successful splitting\n"

    exit
}

#**************************************************************************************************************
# Parse argument options
# 1 - the input array
#**************************************************************************************************************
parse_arguments () {
    getopt --test > /dev/null || error_code=$?
    if [[ $error_code -ne 4 ]]; then err "$0 getopt --test failed!"; fi

    SHORT="d:n:f:F:t:T:sDhi:S:"
    if ! PARSED=$(getopt --options ${SHORT} --name "${0}" -- "${@}"); then print_help; fi
    eval set -- "${PARSED}"

    while true; do
        case "${1}" in
            -h) print_help ;;
            -i) FILENAME="${2}";      shift 2 ;;
            -d) DURATION="${2}";      shift 2 ;;
            -n) NOISE="${2}";         shift 2 ;;
            -f) FILE="${2}";          shift 2 ;;
            -t) TARGET_EXT="${2}";    shift 2 ;;
            -D) DELETE=true;          shift   ;;
            -s) SPLIT=true;           shift   ;;
            -T) TARGET_DIR="${2}";    shift 2 ;;
            -S|-F)
                if [ "${1}" == "-S" ]; then INFO_FROM_FILE="${2}"; fi
                NAMEPATH="${2}"; NAMECOUNT=$(wc -l < "${NAMEPATH}"); NAMECOUNT=$((NAMECOUNT - 1))
                shift 2 ;;
            --) FILENAME="${2}"; break ;;
            *) err "Unknown option ${1}" ;;
        esac
    done
}

#**************************************************************************************************************
# Find all items with silence and push into string
# 1 - input string
#**************************************************************************************************************
print_info () {
    mapfile -t -d " " array < <(printf "%s" "${1}")

    OUTPUT_DATA=""
    for index in "${!array[@]}"; do
        if [[ "${array[index]}" =~ "silence_" ]]; then
            OUTPUT_DATA+="${array[index]} ${array[index+1]} "
        fi
    done
    OUTPUT_DATA=$(printf "%s" "${OUTPUT_DATA}" | tr '\n' ' ')
}

#**************************************************************************************************************
# Write list of files with silence or print data of found files with silence
# 1 - Found silencedata
#**************************************************************************************************************
write_silencedata () {
    debug
    print_info "${1}"

    if [ -z "$FILE" ]; then err "%s/%s -> %s" "${PWD}/${2} -> ${OUTPUT_DATA}"
    else printf "%s/%s\n    -> %s\n" "${PWD}" "${2}" "${OUTPUT_DATA}" >> "$FILE"; fi
}

#**************************************************************************************************************
# Find target directoryname in trackfiles starting with D:
# 1 - Possible Target ID (for multiple albums)
#**************************************************************************************************************
find_target_in_file () {
    debug
    SEEKER=1

    for item in "${trackInfo[@]}"; do
        if [[ ${item} == "D:"* ]]; then
            TARGET_DIR="${item##*:}"
            [ "${1}" == "${SEEKER}" ] && break
            SEEKER=$((SEEKER + 1))
        fi
    done
}

#**************************************************************************************************************
# Find trackname from given filepath
# 1 - filenumber (aka the row in the file
#**************************************************************************************************************
find_name_in_file () {
    debug
    if [ -n "${INFO_FROM_FILE}" ]; then return
    elif [ "${#trackInfo[@]}" -eq "0" ]; then mapfile -t trackInfo< <(cat "${NAMEPATH}"); fi

    cnt=1; albcnt=0; albcheck="${TARGETID}"

    for line in "${trackInfo[@]}"; do
        if [[ $line =~ "D:" ]]; then
            albcnt=$((albcnt + 1))

            # There is more than one album in the trackfile, update data to new album, reset tracknumber and update NAMECOUNT check value to one smaller
            if [ "$cnt" -gt "1" ] && [ "$albcnt" -gt "$albcheck" ]; then
                TARGETID=$((TARGETID + 1)); TRACKNUMBER=1; NAMECOUNT=$((NAMECOUNT - 1))
                find_target_in_file "${TARGETID}"
            fi
            continue
        fi

        if [ "$cnt" -eq "$1" ]; then
            CURRENT_NAME="$line"
            break
        fi

        cnt=$((cnt + 1))
    done

    if [ -z "${CURRENT_NAME}" ]; then CURRENT_NAME="unknown"; fi
}

#**************************************************************************************************************
# Check if value is bigger than the other value
# 1 - Value to compare
# 2 - Value to compare to
# Return: 1 if true, 0 if false
#**************************************************************************************************************
bigger_than() {
    return "$(echo "${1} > ${2}" |bc -l)"
}

#**************************************************************************************************************
# Check if value is smaller than the other value
# 1 - Value to compare
# 2 - Value to compare to
# Return: 1 if true, 0 if false
#**************************************************************************************************************
smaller_than() {
    return "$(echo "${1} < ${2}" |bc -l)"
}

#**************************************************************************************************************
# Split data from file between silences
# 1 - filename
# 2 - starttime
# 3 - endtime
# 4 - number of the output file
#**************************************************************************************************************
split_to_file () {
    debug
    EXT="${1##*.}"; FNAME="${1%.*}"; OUTPUT="$(printf "%s_%02d.%s" "${FNAME}" "${4}" "${EXT}")"

    if [ "${2}" == "0" ]; then OPTIONS=("-to" "${3}")
    elif [ "${3}" == "0" ]; then OPTIONS=("-ss" "${2}")
    else OPTIONS=("-ss" "${2}" "-to" "${3}"); fi

    error_code=0; pack_error=0

    if [ -n "${TARGET_EXT}" ]; then
        PACK_OUTPUT="$(printf "%s_%02d.%s" "${FNAME}" "${4}" "${TARGET_EXT}")"
    elif [ -n "${NAMEPATH}" ]; then
        find_name_in_file "${4}"
        PACK_OUTPUT="$(printf "%02d %s.%s" "${4}" "${CURRENT_NAME:-${FNAME}}" "${EXT}")"
    fi

    if [ -n "$TARGET_DIR" ]; then
        PACK_OUTPUT="${TARGET_DIR}/${PACK_OUTPUT}"
        [ ! -d "${TARGET_DIR}" ] && mkdir "${TARGET_DIR}"
    fi

    if [ "${EXT}" == "mp3" ]; then
        printf "Extracting mp3 from %s! | Start:%s End:%s\n" "${1}" "$(lib time full "${2}")" "$(lib time full "${3}")"
        ffmpeg -i "$1" "${OPTIONS[@]}" -c copy "${OUTPUT}" -v quiet >/dev/null 2>&1 || error_code=$?
    else
        printf "Extracting %s | Start:%s End:%s\n" "${OUTPUT}" "$(lib time full "${2}")" "$(lib time full "${3}")"
        ffmpeg -i "$1" "${OPTIONS[@]}" "$OUTPUT" -v quiet >/dev/null 2>&1 || error_code=$?

        if [ -n "${TARGET_EXT}" ] && [ "$error_code" -eq "0" ]; then
            if [ "${TARGET_EXT}" == "mp3" ]; then
                printf "  Packing to mp3 with lame '%s' to '%s'\n" "${OUTPUT}" "${PACK_OUTPUT}"
                lame -V 0 -h "${OUTPUT}" "${PACK_OUTPUT}" >/dev/null 2>&1 || error_code=$?
                if [ ${error_code} -eq 0 ]; then
                    rm "${OUTPUT}"
                    pack_error=1
                fi
            else
                printf "  Packing target type %s not supported, yet!\n" "${TARGET_EXT}"
            fi
        fi
    fi

    if [ ${error_code} -ne 0 ]; then
        ERROR="${error_code}"
        if [ "${pack_error}" == "0" ]; then err "ffmpeg failed to extract ${4} audio from ${1}"
        else                              err "lame failed to pack ${OUTPUT} -> ${PACK_OUTPUT}"; fi
    fi
}

#**************************************************************************************************************
# Parse found silencedata and split input file to separate files with audio only
# 1 - Found silencedata
# 2 - Source filename
#**************************************************************************************************************
split_file_by_silence () {
    debug

    mapfile -t silenceList< <(printf "%s" "${1}")
    TOTAL_LENGTH=$(ffprobe -i "$2" -show_entries format=duration -v quiet -of csv="p=0")
    silentItems=()

    for i in "${silenceList[@]}"; do
        if [[ "${i}" == *"silence_start:"* ]]; then
            silentItems+=("start=${i##*: }")
        elif [[ "${i}" == *"silence_end:"* ]]; then
            HANDLER="${i% |*}"
            silentItems+=("stop=${HANDLER##*: }")
        fi
    done

    silentItems+=("dummy"); LAST=0; FILENUMBER=0

    for i in "${silentItems[@]}"; do
        CURRENT="${i##*=}"
        if [[ "${i}" == *"start="* ]]; then
            if [ "${LAST}" == "0" ] && ! bigger_than "${CURRENT}" "0"; then split_to_file "${2}" "0" "${CURRENT}" "${FILENUMBER}"
            elif [ "${LAST}" != "0" ]; then                                 split_to_file "${2}" "${LAST}" "${CURRENT}" "${FILENUMBER}"; fi
        elif [[ "${i}" == *"stop="* ]]; then
            (( FILENUMBER++ ))
        elif [ "${i}" == "dummy" ] && ! smaller_than "${LAST}" "${TOTAL_LENGTH}" && ! bigger_than "$(bc <<< "$TOTAL_LENGTH - $LAST")" "1"; then
            split_to_file "${2}" "${LAST}" "0" "${FILENUMBER}"
        fi
        LAST="${CURRENT}"
    done

    if [ ${ERROR} == "0" ] && ${DELETE}; then
            rm "$2"
            [ -f "${NAMEPATH}" ] && rm "${NAMEPATH}"
    fi
}

#**************************************************************************************************************
# Parse found silencedata and split input file to separate files with audio only
# 1 - Source filename
#**************************************************************************************************************
split_file_by_input_file () {
    debug

    START=0; END=0; TRACKNUMBER=1
    TOTAL_LENGTH=$(ffprobe -i "$1" -show_entries format=duration -v quiet -of csv="p=0")

    mapfile -t inputs < <(cat "${INFO_FROM_FILE}")

    for line in "${inputs[@]}"; do
        if [[ ${line} == "D:"* ]]; then
            TARGET_DIR="${line##*:}"; TRACKNUMBER=1; continue
        fi

        TIMEDATA=${line%;*}; START=${TIMEDATA%-*}; END=${TIMEDATA#*-}; CURRENT_NAME=${line#*;}

        split_to_file "${1}" "${START}" "${END}" "${TRACKNUMBER}"
        START=0; END=0; TRACKNUMBER=$((TRACKNUMBER + 1))
    done

    if [ $ERROR == "0" ] && ${DELETE} && [ "${TRACKNUMBER}" -gt "1" ]; then
        printf "everythings fine, deleting original\n"
        rm -fr "$1"
        [ -f "${NAMEPATH}" ] && rm "${NAMEPATH}"
        [ -f "${INFO_FROM_FILE}" ] && rm "${INFO_FROM_FILE}"
    fi
}

#**************************************************************************************************************
# Check file for silence
# 1 - Sourcefile
#**************************************************************************************************************
check_file () {
    debug

    if [ -n "$(mediainfo '--Inform=Audio;%Duration%' "${1}")" ] && [ -f "${1}" ] ; then
        SILENCEDATA=$(ffmpeg -i "$1" -af "silencedetect=noise=${NOISE}:d=${DURATION}" -f null - 2>&1 >/dev/null |grep "silence")
        if [ -n "${SILENCEDATA}" ]; then
            if ${SPLIT}; then split_file_by_silence "${SILENCEDATA}" "${1}"
            else              write_silencedata "${SILENCEDATA}" "${1}"; fi
        fi
    fi
}

#**********************************************************************************
# Verify necessary external programs
#**********************************************************************************
verify_dependencies() {
    error_code=0
    deplist=()
    hash ffmpeg     || deplist+=("ffmpeg")
    hash ffprobe    || deplist+=("ffprobe")
    hash awk        || deplist+=("awk")
    hash lame       || deplist+=("lame")
    hash mediainfo  || deplist+=("mediainfo")

    if [ "${#deplist}" -gt "0" ]; then err "Missing necessary dependencies: ${deplist[*]}"; fi
}

#**************************************************************************************************************
# The main function
#**************************************************************************************************************
run_main() {
    debug
    if [ -n "$FILE" ] && [ -z "${INFO_FROM_FILE}" ]; then
        if [ -f "${FILE}" ]; then rm -fr "${FILE}"; fi
        printf "Seeking silence with %s secs or more" "${DURATION}" > "${FILE}"
    fi

    fileList=()
    if [ -f "${FILENAME}" ]; then fileList+=("${FILENAME}")
    elif [ -d "${FILENAME}" ]; then mapfile -t fileList< <(find "${FILENAME}" -type f | sort)
    elif [ -z "${FILENAME}" ]; then err "Give a filename, path or extension type!"
    else mapfile -t fileList< <(find . -iname "*.${FILENAME}" -type f | sort); fi

    for file in "${fileList[@]}"; do
        WIDTH=$(($(tput cols) - 2))
        PRINTOUT="$(printf "Checking %s%${WIDTH}s" "${file}" " ")"
        printf "%s\r" "${PRINTOUT:0:${WIDTH}}"
        if [ -z "${INFO_FROM_FILE}" ]; then check_file "${file}"
        else split_file_by_input_file "${file}"; fi
    done
}

#**************************************************************************************************************

verify_dependencies
init
parse_arguments "${@}"
run_main

printf "\n"
