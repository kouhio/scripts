#!/bin/bash

STARTSIZE=$(df --output=avail "$PWD" | sed '1d;s/[^0-9]//g')
GLOBAL_FILESAVE=0
export NO_EXIT_EXTERNAL=1
export EXIT_EXT_VAL=0
export COUNTED_ITEMS=0
I_COUNTER=0
TOTAL_SAVETIME="0"
export ERROR=0
COUNT=1
#LASTSTART=0

################################################################
# Print out help
################################################################
help () {
    printf "Audio portion removal application\n"
    printf "Usage inputs:\n"
    printf "1 - Target filetypes (mp4 etc)\n"
    printf "<filepath>      - Any file given is used as a search source, other than the first input"
    printf "beg=<seconds>   - Time to remove from the beginning, if the file first comparison file is not from the beginning\n"
    printf "end=<seconds>   - Time to remove from the end, if last given file is note at the end\n"
    printf "individual      - will write setup to do.shi, otherwise will use packAll.sh to strip the audio portion\n"
    exit 1
}

[ -z "$1" ] && lib C r "No input filetype given!\n" && help
[ ! -f "$2" ] && lib C r "audio input file '$2' incorrect!\n" && help
#[ -n "$3" ] && CHECKER=$(lib v n "$3") && [ "$CHECKER" -ne "1" ] && lib C r "Input type '$3' invalid time value\n" && help

################################################################
# add mp3s to database
################################################################
createDatabase() {
    AUDIO_LENGTH=$(mediainfo '--Inform=Audio;%Duration%' "$1")
    AUDIO_LENGTH=$((AUDIO_LENGTH / 1000))
    DATABASES+=("tembase_${LOOPCNT}")
    DATABASELEN+=("${AUDIO_LENGTH}")
    printf "Trying to create database from %s\n" "$1"
    [ -f "tembase_${LOOPCNT}" ] && rm "tembase_${LOOPCNT}"
    python3 ~/dev/audfprint/audfprint.py new --dbase "tembase_${LOOPCNT}" "$1" >/dev/null 2>&1
    printf "Created audio comparison database from '%s', len:%ss\n" "${1}" "${AUDIO_LENGTH}"
}

################################################################
# Rewrite the do.sh file
# 1 - If not set, will write data from beginning, otherwise from the end
################################################################
writeOutput () {
    WRITE="$1"
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [ -z "$WRITE" ]; then
            printf "$line\n" >> tempfile.txt
            [[ $line =~ "#BEGIN" ]]&& return 0
        else
            [[ $line =~ "#END" ]] && WRITE="" && printf "$line\n" >> tempfile.txt
        fi
    done < "do.sh"

    rm "do.sh"
    mv "tempfile.txt" "do.sh"
}

################################################################
# Print out final information
# 1 - If not set, is an interrupt, otherwise just an exit
################################################################
set_int () {
    shopt -u nocaseglob
    for i in "${DATABASES[@]}"; do
        [ -f "${i}" ] && rm "${i}"
    done
    [ -z "$1" ] && printf " Interrupted at file %s\n" "$CURRCNT"

    ENDSIZE=$(df --output=avail "$PWD" | sed '1d;s/[^0-9]//g')
    TOTALSIZE=$((ENDSIZE - STARTSIZE))
    TOTALSIZE=$((TOTALSIZE / 1000))
    GLOBAL_FILESAVE=$((GLOBAL_FILESAVE / 1000))

    lib C y "*** Totally saved $TOTALSIZE / $GLOBAL_FILESAVE Mb and saved time: $(date -d@${TOTAL_SAVETIME} -u +%T) in $I_COUNTER files ***\n"

    [ -z "$1" ] && exit 1
    exit 0
}

#############################################################################
# Print out the time it took to handle one item
#############################################################################
endtime () {
    ENDTIME=$(date +%s)
    TOTALTIME=$((ENDTIME - STARTTIME))
    lib C w " in $(date -d@${TOTALTIME} -u +%T)\n"
}

#############################################################################
# Format time into HH:MM:SS
# 1 - Time in seconds
#############################################################################
calcTime () {
    ADDTIME=""
    ADDTIME="${1##*.}"
    NORMTIME="${1%.*}"
    if [ "$NORMTIME" -lt "60" ]; then TIME="$(date -d@"${NORMTIME}" -u +%S)"
    elif [ "$NORMTIME" -lt "3600" ]; then TIME="$(date -d@"${NORMTIME}" -u +%M:%S)";
    else TIME="$(date -d@"${NORMTIME}" -u +%T)"; fi
    [ "$TIME" == "00" ] && TIME="0"
    [ -n "${ADDTIME}" ] && TIME+=".${ADDTIME}"
}

#############################################################################
# Seek comparison audio from file
# 1 - filename
# 2 - database name
#############################################################################
seekAudio() {
    printf "$(date +%T): Seeking audio from %-50s %8s\n" "${1:0:50}" "$(date -d@${VIDEO_LENGTH} -u +%T)"
    I_OUTPUT=""
    I_OUTPUT=$(python3 ~/dev/audfprint/audfprint.py match --dbase "${2}" "$1" --find-time-range)
    AUDIO_LENGTH="${DATABASELEN[DBASE_POS]}"
    ITEM=""

    mapfile -t data_array < <(printf "%s" "$I_OUTPUT")

    for index in "${!data_array[@]}"; do
        if [[ "${data_array[index]}" =~ "Matched" ]]; then
            ITEM="${data_array[index]}"
            break
        fi
    done

    [ -z "${ITEM}" ] && printf "Nothing found!\n%s\n" "${I_OUTPUT}" && return

    mapfile -t -d " " data_array < <(printf "%s" "$ITEM")
    item_array=()
    for g in "${data_array[@]}"; do
        [ -z "${g}" ] && continue
        item_array+=("${g}")
    done

    I_LENGTH=""; I_START=""; I_COMPLEN=""

    for i in "${!item_array[@]}"; do
        if [ "${item_array[i]}" == "Matched" ]; then I_LENGTH="${item_array[i + 1]}"
        elif [ "${item_array[i]}" == "starting" ] && [ "${item_array[i + 1]}" == "at" ]; then I_START="${item_array[i + 2]}"
        elif [ "${item_array[i]}" == "to" ] && [ "${item_array[i + 1]}" == "time" ]; then I_COMPLEN="${item_array[i + 2]}"; fi

        ((i++))
    done

    if [ -z "$I_LENGTH" ] || [ -z "$I_START" ] || [ -z "$I_COMPLEN" ]; then
        lib C y "-> Skipping not found len:$I_LENGTH start:$I_START complen:$I_COMPLEN "
        endtime
        return
    fi

    TIME_CORRECTION=0
    NEWSTART=$(bc <<< "scale=2;($I_START - $I_COMPLEN)")
    if [ "${NEWSTART%.*}" == "-" ]; then NEWSTART=0
    elif [ "${NEWSTART%.*}" -le "0" ]; then NEWSTART=$(bc <<< "scale=2;($AUDIO_LENGTH + $NEWSTART)"); fi

    # Setup possible end value trimming
    TIMECUT=0
    [ -n "$ENDCLEAN" ] && [ "$ENDCLEAN" != "0" ] && TIMECUT=$((VIDEO_LENGTH - ENDCLEAN))

    # reformat time values for later use
    calcTime "$NEWSTART"
    STARTHANDLE="$TIME"
    #LASTSTART="$NEWSTART"

    ENDSTART=$(bc <<< "scale=2;($NEWSTART + $AUDIO_LENGTH)")
    calcTime "$ENDSTART"
    ENDHANDLE="$TIME"

    #calcTime "$TIMECUT"
    #ENDHANDLE2="$TIME"
    ENDPOS=$(bc <<< "scale=2;($VIDEO_LENGTH - $ENDSTART)")

    if [ "${BEGCLEAN}" -ge "${STARTHANDLE%.*}" ] && [ "${DBASE_POS}" -eq "0" ]; then CUTARRAY+=("${ENDSTART}")
    elif [ "$((DBASE_POS - 1))" -eq "${#DATABASELEN[@]}" ] && [ "${ENDCLEAN}" -gt "${ENDPOS%.*}" ]; then CUTARRAY+=("${ENDSTART}")
    elif [ "$((DBASE_POS - 1))" -eq "${#DATABASELEN[@]}" ]; then CUTARRAY+=("${ENDSTART}" "0")
    elif [ "${DBASE_POS}" -eq "0" ]; then CUTARRAY+=("0" "${STARTHANDLE}" "${ENDSTART}")
    else CUTARRAY+=("${STARTHANDLE}" "${ENDSTART}");  fi
}

#############################################################################
# Find audio from given video
#
# 1 - video filename
# 2 - If set, will not remove audio, only print out info to given outputfile
# 3 - Comparison filename
# 4 - Time to cut from the end
##############################################################################
get_info_and_cut () {
    STARTTIME=$(date +%s)
    VIDEO_LENGTH=$(mediainfo '--Inform=Video;%Duration%' "$1")
    [ -z "$VIDEO_LENGTH" ] && lib C r "incorrect video $1 - len:'$VIDEO_LENGTH'\n" && return
    [ "${INDIVIDUAL}" -gt "0" ] && OUTPUTFILE="tempfile.txt"

    VIDEO_LENGTH=$((VIDEO_LENGTH / 1000)); CUTARRAY=(); DBASE_POS=0

    for j in "${DATABASES[@]}"; do
        seekAudio "${1}" "${j}"
        ((DBASE_POS++))
    done

    echo "DEBUG TODO: create cutter string here from ${CUTARRAY[*]}" && exit
    # Since no output file is given, remove the found timeframe immediately
    if [ "${INDIVIDUAL}" -eq "0" ]; then
        error=0

        # Start is at the beginning, skip too short intro alltogether
        if [ "${NEWSTART%.*}" -eq "0" ]; then
            lib C y "-> Removing front:$((AUDIO_LENGTH + TIME_CORRECTION))s"
            [ -n "$4" ] && [ "$4" != "0" ] && lib C y " end:${4}s"
            echo "packAll.sh \"$1\" \"quit\" \"c=$((AUDIO_LENGTH + TIME_CORRECTION))-${TIMECUT},D\" >/dev/null 2>&1"
            error=$?

        # Comparison audio in the middle of the video, remove it from there
        else
            printf -- "-> removing %8s-%-8s" "${STARTHANDLE}" "${ENDHANDLE}"
            [ "$ENDHANDLE2" != "0" ] && lib C y " trim to:%-8s$" "${ENDHANDLE2}"
            echo "packAll.sh \"${1}\" \"quit\" C=0-${STARTHANDLE},${ENDHANDLE}-${ENDHANDLE2},D >/dev/null 2>&1"
            error=$?
        fi

        if [ "$error" -eq "0" ]; then
            C_LENGTH="$AUDIO_LENGTH"
            [ -n "$4" ] && [ "$4" != "0" ] && C_LENGTH=$((C_LENGTH + "$4"))
            lib C g "-> successful, saved ${C_LENGTH}s"
            TOTAL_SAVETIME=$((TOTAL_SAVETIME + C_LENGTH))
            I_COUNTER=$((I_COUNTER + 1))
        else
            lib C r "-> failed!"
        fi

    # Output file has been given, write removal timeframes to given file in the format of individualPack.sh
    else
        lib C g "found start:$STARTHANDLE end:${ENDHANDLE} " && [ -n "$4" ] && [ "$4" != "0" ] && printf "trim:${ENDHANDLE2} "

        if [ -n "$5" ]; then
            CUTSTR="b=$ENDHANDLE"
            [ -n "$4" ] && [ "$4" != "0" ] && CUTSTR+=" e=${4}"
            printf "PACK \"${1}\" $CUTSTR\n" >> "$OUTPUTFILE"

        elif [ "$NEWSTART" -eq "0" ]; then
            CUTSTR="b=$AUDIO_LENGTH"
            [ -n "$4" ] && [ "$4" != "0" ] && CUTSTR+=" e=${4}"
            printf "PACK \"${1}\" $CUTSTR\n" >> "$OUTPUTFILE"

        else
            printf "PACK \"${1}\" C=0-$STARTHANDLE,${ENDHANDLE}-${ENDHANDLE2},D\n" >> "$OUTPUTFILE"
        fi
        [ "$COUNT" -ge "10" ] && COUNT=0 && printf "\n" >> "$OUTPUTFILE"
        COUNT=$((COUNT + 1))
    fi

    endtime
}

trap set_int SIGINT SIGTERM

shopt -s nocaseglob

CURRCNT=1
LOOPCNT=0
ENDCLEAN=""
BEGCLEAN="0"
INDIVIDUAL=0
DATABASES=()
DATABASELEN=()
FILENAME="${1}"
FILECNT=$(find . -maxdepth 1 -name "*${1}" |wc -l)
shift

for i in "${@}"; do
    if [ -f "${i}" ]; then createDatabase "${i}"
    elif [[ "${i}" == "end="* ]]; then ENDCLEAN="${i##*=}"
    elif [[ "${i}" == "beg="* ]]; then BEGCLEAN="${i##*=}"
    elif [[ "${i}" == "individual" ]]; then INDIVIDUAL=1 && individualPack.sh "${FILENAME}"; fi

    ((LOOPCNT++))
done

[ -f "tempfile.txt" ] && rm "tempfile.txt"

for f in *".${FILENAME}"; do
    printf "%03d/%03d " "$CURRCNT" "$FILECNT"
    get_info_and_cut "$f"
    CURRCNT=$((CURRCNT + 1))
done

shopt -u nocaseglob
set_int 1
