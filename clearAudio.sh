#!/bin/bash

STARTSIZE=`df --output=avail "$PWD" | sed '1d;s/[^0-9]//g'`
GLOBAL_FILESAVE=0
NO_EXIT_EXTERNAL=1
EXIT_EXT_VAL=0
COUNTED_ITEMS=0
I_COUNTER=0
TOTAL_SAVETIME="0"
ERROR=0
LASTSTART=0

R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
O='\033[0m'
COUNT=1

################################################################
# Print out help
################################################################
help () {
    echo "Audio portion removal application"
    echo "Usage inputs:"
    echo "1 - Target filetypes (mp4 etc)"
    echo "2 - Source audio / video clip to remove from target files"
    echo "3 - possible value in seconds to remove from the end of the video, if set as something else than 0"
    echo "4 - if set, will write removal timeframes to a individualPack.sh handler instead of immediate action by packAll.sh"
    echo "5 - If set, will erase everything from beginning to the end of the source audio"
    exit 1
}

[ -z "$1" ] && echo -e ${R}"No input filetype given!"${O} && help
[ ! -f "$2" ] && echo -e ${R}"audio input file '$2' incorrect!"${O} && help

################################################################
# add mp3s to database
################################################################
AUDIO_LENGTH=$(mediainfo '--Inform=Audio;%Duration%' "$2")
AUDIO_LENGTH=$((AUDIO_LENGTH / 1000))
AUDIO_TENTH=$((AUDIO_LENGTH / 10))
INPUT=$(python3 ~/dev/audfprint/audfprint.py new --dbase tembase "$2") && echo "Audio comparison database from '$2', len:${AUDIO_LENGTH}s"

################################################################
# Rewrite the do.sh file
# 1 - If not set, will write data from beginning, otherwise from the end
################################################################
writeOutput () {
    WRITE="$1"
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [ -z "$WRITE" ]; then
            echo "$line" >> tempfile.txt
            [[ $line =~ "#BEGIN" ]]&& return 0
        else
            [[ $line =~ "#END" ]] && WRITE="" && echo "$line" >> tempfile.txt
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
    [ -f "tembase" ] && rm tembase
    [ -z "$1" ] && echo " Interrupted at file $CURRCNT"

    ENDSIZE=`df --output=avail "$PWD" | sed '1d;s/[^0-9]//g'`
    TOTALSIZE=$((ENDSIZE - STARTSIZE))
    TOTALSIZE=$((TOTALSIZE / 1000))
    GLOBAL_FILESAVE=$((GLOBAL_FILESAVE / 1000))

    echo -e "${Y}*** Totally saved $TOTALSIZE / $GLOBAL_FILESAVE Mb and saved time: $(date -d@${TOTAL_SAVETIME} -u +%T) in $I_COUNTER files *** ${O}"

    [ -z "$1" ] && exit 1
    exit 0
}

#############################################################################
# Print out the time it took to handle one item
#############################################################################
endtime () {
    ENDTIME=$(date +%s)
    TOTALTIME=$((ENDTIME - STARTTIME))
    echo " in $(date -d@${TOTALTIME} -u +%T)"
}

#############################################################################
# Format time into HH:MM:SS
# 1 - Time in seconds
#############################################################################
calcTime () {
    if [ "$1" -lt "60" ]; then TIME="$(date -d@${1} -u +%S)"
    elif [ "$1" -lt "3600" ]; then TIME="$(date -d@${1} -u +%M:%S)";
    else TIME="$(date -d@${1} -u +%T)"; fi
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
    AUDIO_MIDDLE=$((VIDEO_LENGTH / 2))
    [ -z "$AUDIO_LENGTH" ] && echo -e ${R}"incorrect audio $3 - len:'$AUDIO_LENGTH'"${O} && exit 1
    OUTPUTFILE="$2"
    [ "$2" == "do.sh" ] && OUTPUTFILE="tempfile.txt"

    VIDEO_LENGTH=$((VIDEO_LENGTH / 1000))
    printf "$(date +%T): Seeking audio from %-50s %8s " "${1:0:50}" "$(date -d@${VIDEO_LENGTH} -u +%T)"
    I_OUTPUT=$(python3 ~/dev/audfprint/audfprint.py match --dbase tembase "$1" --find-time-range)

    NEW_LINE=$'\x0A';
    export IFS="${NEW_LINE}";
    data_array=(${I_OUTPUT///$IFS})

    for index in "${!data_array[@]}"; do
        if [[ "${data_array[index]}" =~ "Matched" ]]; then
            ITEM="${data_array[index]}"
            break
        fi
    done

    data_array=(${ITEM// /$IFS})
    I_LENGTH=""
    I_START=""
    I_COMPLEN=""

    for i in "${!data_array[@]}"; do
        if [ "${data_array[i]}" == "Matched" ]; then
            I_LENGTH="${data_array[i + 1]}"
        elif [ "${data_array[i]}" == "starting" ] && [ "${data_array[i + 1]}" == "at" ]; then
            I_START="${data_array[i + 2]}"
        elif [ "${data_array[i]}" == "to" ] && [ "${data_array[i + 1]}" == "time" ]; then
            I_COMPLEN="${data_array[i + 2]}"
        fi

        i=$((i + 1))
    done

    if [ -z "$I_LENGTH" ] || [ -z "$I_START" ] || [ -z "$I_COMPLEN" ]; then
        echo -en "${Y}-> Skipping not found len:$I_LENGTH start:$I_START complen:$I_COMPLEN ${O}"
        endtime
        return 0
    fi

    I_LENGTH="${I_LENGTH%.*}"
    if [ "$I_LENGTH" -lt "$AUDIO_TENTH" ]; then
        echo -en "${Y}-> Skipping too short len:${I_LENGTH}/${AUDIO_TENTH} start:$I_START complen:$I_COMPLEN ${O}"
        endtime
        return 0
    fi

    TIME_CORRECTION=0
    NEWSTART=$(bc <<< "scale=0;($I_START - $I_COMPLEN)")
    ORIGSTART="${NEWSTART##.*}"
    NEWSTART="${NEWSTART%.*}"
    if [ "$NEWSTART" == "-" ]; then
        NEWSTART=0
    elif [ "$NEWSTART" -lt "10" ]; then
        TIME_CORRECTION=$NEWSTART
        NEWSTART=0
    elif [ "$NEWSTART" -lt "0" ]; then
        #NEWSTART=$((AUDIO_LENGTH - 1 + NEWSTART))
        NEWSTART=$((AUDIO_LENGTH + NEWSTART))
    else
        NEWSTART=$((NEWSTART + 1))
        #NEWLEN=$((AUDIO_LENGTH - 1))
    fi

    if [ "$NEWSTART" -ge "$AUDIO_MIDDLE" ]; then
        echo -en "${Y}-> Skipping too far in the video $NEWSTART / $AUDIO_MIDDLE ${O}\n"
        endtime
        return 0
    fi

    I_START="${I_START%.*}"
    CUTSTR=""

    # Setup possible end value trimming
    TIMECUT=0
    [ ! -z "$4" ] && [ "$4" != "0" ] && TIMECUT=$((VIDEO_LENGTH - $4))

    # reformat time values for later use
    calcTime "$NEWSTART"
    STARTHANDLE="$TIME"
    LASTSTART="$NEWSTART"

    ENDSTART=$((NEWSTART + AUDIO_LENGTH))
    calcTime "$ENDSTART"
    ENDHANDLE="$TIME"

    calcTime "$TIMECUT"
    ENDHANDLE2="$TIME"

    # Since no output file is given, remove the found timeframe immediately
    if [ -z "$2" ]; then
        error=0

        # Start is at the beginning, skip too short intro alltogether
        if [ "$NEWSTART" -eq "0" ]; then
            echo -en ${Y}"-> Removing front:$((AUDIO_LENGTH + TIME_CORRECTION))s"${O}
            [ ! -z "$4" ] && [ "$4" != "0" ] && echo -en ${Y}" end:${4}s"${O}
            packAll.sh "$1" "quit" "c=$((AUDIO_LENGTH + TIME_CORRECTION))-${TIMECUT},D" >/dev/null 2>&1
            error=$?

        # Comparison audio in the middle of the video, remove it from there
        else
            printf "${Y}-> removing %8s-%-8s" "${STARTHANDLE}" "${ENDHANDLE}"
            [ "$ENDHANDLE2" != "0" ] && printf "${Y} trim to:%-8s${O}" "${ENDHANDLE2}"
            packAll.sh "${1}" "quit" C=0-${STARTHANDLE},${ENDHANDLE}-${ENDHANDLE2},D >/dev/null 2>&1
            error=$?
        fi

        if [ "$error" -eq "0" ]; then
            C_LENGTH="$AUDIO_LENGTH"
            [ ! -z "$4" ] && [ "$4" != "0" ] && C_LENGTH=$((C_LENGTH + "$4"))
            echo -en ${G}"-> successful, saved ${C_LENGTH}s"${O}
            TOTAL_SAVETIME=$((TOTAL_SAVETIME + C_LENGTH))
            I_COUNTER=$((I_COUNTER + 1))
        else
            echo -en ${R}"-> failed!"${O}
        fi

    # Output file has been given, write removal timeframes to given file in the format of individualPack.sh
    else
        echo -en "${G}found start:$STARTHANDLE end:${ENDHANDLE} " && [ ! -z "$4" ] && [ "$4" != "0" ] && echo -en "trim:${ENDHANDLE2}${O} "

        if [ ! -z "$5" ]; then
            CUTSTR="b=$ENDHANDLE"
            [ ! -z "$4" ] && [ "$4" != "0" ] && CUTSTR+=" e=${4}"
            echo "PACK \"${1}\" $CUTSTR" >> "$OUTPUTFILE"

        elif [ "$NEWSTART" -eq "0" ]; then
            CUTSTR="b=$AUDIO_LENGTH"
            [ ! -z "$4" ] && [ "$4" != "0" ] && CUTSTR+=" e=${4}"
            echo "PACK \"${1}\" $CUTSTR" >> "$OUTPUTFILE"

        else
            echo "PACK \"${1}\" C=0-$STARTHANDLE,${ENDHANDLE}-${ENDHANDLE2},D" >> "$OUTPUTFILE"
        fi
        [ "$COUNT" -ge "10" ] && COUNT=0 && echo -en "\n" >> "$OUTPUTFILE"
        COUNT=$((COUNT + 1))
    fi

    endtime
}

trap set_int SIGINT SIGTERM

shopt -s nocaseglob

FILECNT=$(ls -l *.${1} 2>/dev/null | grep -v ^l | wc -l)
CURRCNT=1
[ -f "$3" ] && rm "$3"
[ ! -f "$4" ] && [ "$4" == "do.sh" ] && individualPack.sh "$1"
[ -f "tempfile.txt" ] && rm "tempfile.txt"

[ "$4" == "do.sh" ] && writeOutput

for f in *.${1}; do
    printf "%03d/%03d " "$CURRCNT" "$FILECNT"
    get_info_and_cut "$f" "$4" "$2" "$3" "$5"
    CURRCNT=$((CURRCNT + 1))
done

[ "$4" == "do.sh" ] && writeOutput "1"

shopt -u nocaseglob

rename "s/_01//" *${1}

set_int 1
