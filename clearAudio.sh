#!/bin/bash

STARTSIZE=`df --output=avail "$PWD" | sed '1d;s/[^0-9]//g'`
GLOBAL_FILESAVE=0
GLOBAL_TIMESAVE=0
NO_EXIT_EXTERNAL=1
EXIT_EXT_VAL=0
COUNTED_ITEMS=0
I_COUNTER=0
TOTAL_SAVETIME=""

R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
O='\033[0m'

help () {
    echo "Audio portion removal application"
    echo "Usage inputs:"
    echo "1 - Target filetypes (mp4 etc)"
    echo "2 - Source audio / video clip to remove from target files"
    echo "3 - possible value in seconds to remove from the end of the video, if set as something else than 0"
    echo "4 - if set, will write removal timeframes to a individualPack.sh handler instead of immediate action by packAll.sh"
    exit 1
}

[ -z "$1" ] && echo -e ${R}"No input filetype given!"${O} && help
[ ! -f "$2" ] && echo -e ${R}"audio input file '$2' incorrect!"${O} && help

################################################################
# add mp3s to database
################################################################
LENNY_AUD=$(mediainfo '--Inform=Audio;%Duration%' "$2")
LENNY_AUD=$((LENNY_AUD / 1000))
INPUT=$(python3 ~/dev/audfprint/audfprint.py new --dbase tembase "$2") && echo "Audio comparison database from '$2', len:${LENNY_AUD}s"

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
    ENDTIMER=$(date -d@${GLOBAL_TIMESAVE} -u +%T)

    [ ! -z "$TOTAL_SAVETIME" ] && echo -e "${Y}*** Totally saved $TOTALSIZE Mb and saved time: $(date -d@${TOTAL_SAVETIME} -u +%T) in $I_COUNTER files *** ${O}"

    [ -z "$1" ] && exit 1
    exit 0
}

#############################################################################
# Find audio from given video
#
# 1 - video filename
# 2 - If set, will not remove audio, only print out info to given input
# 3 - Comparison filename
# 4 - Time to cut from the end
##############################################################################
get_info_and_cut () {
    LENNY=$(mediainfo '--Inform=Video;%Duration%' "$1")
    [ -z "$LENNY_AUD" ] && echo -e ${R}"incorrect audio $3 - len:'$LENNY_AUD'"${O} && exit 1

    LENNY=$((LENNY / 1000))
    TNOW=$(date +%T)
    printf "$TNOW : Seeking audio from %-60s %s " "${1:0:60}" "$(date -d@${LENNY} -u +%T)"
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
        echo -e "${Y}-> Skipping not found len:$I_LENGTH start:$I_START complen:$I_COMPLEN ${O}"
        return 0
    fi

    NEWSTART=$(bc <<< "scale=0;($I_START - $I_COMPLEN)")
    NEWSTART="${NEWSTART%.*}"
    if [ "$NEWSTART" == "-" ]; then
        NEWSTART=0
    elif [ "$NEWSTART" -lt "0" ]; then
        NEWSTART=$((LENNY_AUD - 1 + NEWSTART))
    else
        NEWSTART=$((NEWSTART + 1))
        NEWLEN=$((LENNY_AUD - 1))
    fi

    I_LENGTH="${I_LENGTH%.*}"
    I_START="${I_START%.*}"
    CUTSTR=""
    PART_OF_LEN=$((LENNY_AUD / 5))

    # Setup possible end value trimming
    TIMECUT=0
    [ ! -z "$4" ] && TIMECUT=$((LENNY - $4))

    # set date formatting according to max value
    if [ "$NEWSTART" -lt "60" ]; then STARTHANDLE=""
    elif [ "$NEWSTART" -lt "3600" ]; then STARTHANDLE="+%M:%S";
    else STARTHANDLE="+%T"; fi

    # set date formatting according to max value
    ENDSTART=$((NEWSTART + LENNY_AUD))
    if [ "$ENDSTART" -lt "60" ]; then ENDHANDLE=""
    elif [ "$ENDSTART" -lt "3600" ]; then ENDHANDLE="+%M:%S";
    else ENDHANDLE="+%T"; fi

    # format trimming string 
    if [ "$TIMECUT" -lt "60" ]; then ENDHANDLE2="0"
    elif [ "$TIMECUT" -lt "3600" ]; then ENDHANDLE2=$(date -d@${TIMECUT} -u +%M:%S);
    else ENDHANDLE2=$(date -d@${TIMECUT} -u +%T); fi

    # Since no output file is given, remove the found timeframe immediately
    if [ -z "$2" ]; then
        error=0

        # Start is at the beginning, skip too short intro alltogether
        if [ "$NEWSTART" -eq "0" ]; then
            CUTSTR="b=$LENNY_AUD"
            echo -en ${Y}"-> Removing front:${LENNY_AUD}s"${O}
            [ ! -z "$4" ] && CUTSRT+=" e=${4}" && echo -en ${Y}" end:${4}s"${O}
            packAll.sh i "$1" $CUTSTR >/dev/null 2>&1 && I_COUNTER=$((I_COUNTER + 1))
            error=$?

        # Comparison audio in the middle of the video, remove it from there
        else
            printf "${Y}-> removing %s-%s" "$(date -d@${NEWSTART} -u $STARTHANDLE)" "$(date -d@${ENDSTART} -u ${ENDHANDLE})"
            [ "$ENDHANLE2" != "0" ] && printf "${Y} trim to:%s${O}" "${ENDHANDLE2}"
            packAll.sh "${1}" C=0-$(date -d@${NEWSTART} -u $STARTHANDLE),$(date -d@${ENDSTART} -u ${ENDHANDLE})-${ENDHANDLE2},D >/dev/null 2>&1
            error=$?
        fi

        if [ "$error" -eq "0" ]; then
            C_LENGTH="$LENNY_AUD"
            [ ! -z "$4" ] && C_LENGTH=$((C_LENGTH + "$4"))
            echo -e ${G}"-> successfull, saved ${C_LENGTH}s"${O}
            TOTAL_SAVETIME=$((TOTAL_SAVETIME + C_LENGTH))
            I_COUNTER=$((I_COUNTER + 1))
        else
            echo -e ${R}"-> failed!"${O}
        fi

    # Output file has been given, write removal timeframes to given file in the format of individualPack.sh
    else
        echo -e "${G}found start:$(date -d@${NEWSTART} -u $STARTHANDLE) end:$(date -d@${ENDSTART} -u ${ENDHANDLE}) trim:${ENDHANDLE2}${O}"

        if [ "$NEWSTART" -eq "0" ]; then
            CUTSTR="b=$LENNY_AUD"
            [ ! -z "$4" ] && CUTSRT+=" e=${4}"
            echo "PACK \"${1}\" $CUTSTR" >> "$2"

        else
            echo "PACK \"${1}\" C=0-$(date -d@${NEWSTART} -u $STARTHANDLE),$(date -d@${ENDSTART} -u ${ENDHANDLE})-${ENDHANDLE2},D" >> "$2"
        fi
    fi
}

trap set_int SIGINT SIGTERM

shopt -s nocaseglob

FILECNT=$(ls -l *.${1} 2>/dev/null | grep -v ^l | wc -l)
CURRCNT=1
[ -f "$3" ] && rm "$3"

for f in *.${1}; do
    printf "%03d/%03d " "$CURRCNT" "$FILECNT"
    get_info_and_cut "$f" "$4" "$2" "$3"
    CURRCNT=$((CURRCNT + 1))
done

shopt -u nocaseglob

set_int 1
