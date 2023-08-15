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

[ -z "$1" ] && echo -e ${R}"No input filetype given!"${O} && exit 1
[ ! -f "$2" ] && echo -e ${R}"audio input file '$2' incorrect!"${O} && exit 1

################################################################
# add mp3s to database
################################################################
LENNY_AUD=$(mediainfo '--Inform=Audio;%Duration%' "$2")
LENNY_AUD=$((LENNY_AUD / 1000))
INPUT=$(python3 ~/dev/audfprint/audfprint.py new --dbase tembase "$2") && echo "Database from $2, len:${LENNY_AUD}s"

################################################################
# Print out final information
# 1 - If not set, is an interrupt, otherwise just an exit
################################################################
set_int () {
    shopt -u nocaseglob
    [ -f "tembase" ] && rm tembase
    [ -z "$1" ] && echo " Interrupted at file $CURRCNT"

    [ -f "temp_01.mp4" ] && rm "temp_01.mp4"
    [ -f "temp_02.mp4" ] && rm "temp_02.mp4"
    [ -f "combo.txt" ] && rm "combo.txt"

    ENDSIZE=`df --output=avail "$PWD" | sed '1d;s/[^0-9]//g'`
    TOTALSIZE=$((ENDSIZE - STARTSIZE))
    TOTALSIZE=$((TOTALSIZE / 1000))
    GLOBAL_FILESAVE=$((GLOBAL_FILESAVE / 1000))
    ENDTIMER=$(date -d@${GLOBAL_TIMESAVE} -u +%T)

    [ ! -z "$TOTAL_SAVETIME" ] && echo -e "${Y}*** Totally saved $TOTALSIZE Mb and saved time: $(date -d@${TOTAL_SAVETIME} -u +%T) in $I_COUNTER files *** ${O}"

    [ -z "$1" ] && exit 1
    exit 0
}

################################################################
# Find audio from given video
#
# 1 - video filename
# 2 - If set, will not extract audio, only print out info
# 3 - Comparison filename
################################################################
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
    #POS=$((I_LENGTH + I_START))
    #I_ENDO=$((LENNY - POS))
    CUTSTR=""
    PART_OF_LEN=$((LENNY_AUD / 5))

    #if [ ! -z "$I_LENGTH" ]; then
    #    #[ "$I_LENGTH" -le 3 ] && echo -e "${Y}-> Skipping less than 3s start:$(date -d@${I_START} -u +%T) len:$(date -d@${I_LENGTH} -u +%T) len:$(date -d@${LENNY} -u +%T) cl:$(date -d@${I_COMPLEN} -u +%T) ns:$(date -d@${NEWSTART} -u +%T)"${O} && return 0
    #    [ "$I_LENGTH" -lt "$PART_OF_LEN" ] && echo -e ${Y}"-> skipping too short: length $(date -d@${I_LENGTH} -u +%T)/$(date -d@${PART_OF_LEN} -u +%T) pos:$(date -d@${I_START} -u +%T) cl:$(date -d@${I_COMPLEN} -u +%T) ns:$(date -d@${NEWSTART} -u +%T)"${O} && return 0
    #else
    #    echo -e ${Y}"-> Skipping, not found."${O}
    #    return 0
    #fi

    if [ -z "$2" ]; then
        # Start is at the beginning, skip too short intro alltogether
        if [ "$NEWSTART" -eq "0" ]; then
            CUTSTR="b=$LENNY_AUD"
            [ -z "$2" ] && echo -en ${Y}"-> Removing front ${POS}s"${O} && packAll.sh i "$1" $CUTSTR >/dev/null 2>&1 && I_COUNTER=$((I_COUNTER + 1))

        # No end position, so cut the whole end
        #elif [ "$I_ENDO" -lt "10" ]; then
        #    CUTSTR="e=$POS"
        #    [ -z "$2" ] && echo -en ${Y}"-> Removing end ${POS}s"${O} && packAll.sh i "$1" $CUTSTR >/dev/null 2>&1 && I_COUNTER=$((I_COUNTER + 1))

        # Comparison audio in the middle of the video, remove it from there
        else
            CALCULATOR=$((LENNY - NEWSTART))
            ENDPOINT=$((NEWSTART + NEWLEN))
            printf "${Y}-> Removing from middle %s-%-s (%ds)${O}" "$(date -d@${NEWSTART} -u +%T)" "$(date -d@${ENDPOINT} -u +%T)" "$((ENDPOINT-I_START))"
            CUTSTR="e=$CALCULATOR"
            packAll.sh "$1" k i n=temp $CUTSTR >/dev/null 2>&1
            CUTSTR="b=$ENDPOINT"
            packAll.sh "$1" k i n=temp $CUTSTR >/dev/null 2>&1

            echo "file 'temp_01.mp4'" >> combo.txt
            echo "file 'temp_02.mp4'" >> combo.txt

            error=0

            if [ -f "temp_01.mp4" ] && [ -f "temp_02.mp4" ]; then
                ffmpeg -f concat -i "combo.txt" -c copy "pack_$1" -v quiet >/dev/null 2>&1
                error=$?
            else
                error=1
            fi

            rm combo.txt temp_01.mp4 temp_02.mp4

            if [ "$error" -eq "0" ]; then
                echo -e ${G}"-> combining successfull, saved ${I_LENGTH}s"${O}
                rm "$1"
                mv "pack_$1" "$1"
                TOTAL_SAVETIME=$((TOTAL_SAVETIME + I_LENGTH))
                I_COUNTER=$((I_COUNTER + 1))
            else
                echo -e ${R}"-> combining failed!"${O}
            fi
        fi

    else
        echo "PACK \"${1}\" C=0-$(date -d@${NEWSTART} -u +%T),$(date -d@$((NEWSTART + LENNY_AUD)) -u +%T)-0,D" >> "$2"
        echo -e "${G}found start:$(date -d@${NEWSTART} -u +%T) end:$(date -d@$((NEWSTART + LENNY_AUD)) -u +%T)${O}"
    fi
}

trap set_int SIGINT SIGTERM

shopt -s nocaseglob

FILECNT=$(ls -l *.${1} 2>/dev/null | grep -v ^l | wc -l)
CURRCNT=1
[ -f "$3" ] && rm "$3"

for f in *.${1}; do
    printf "%03d/%03d " "$CURRCNT" "$FILECNT"
    get_info_and_cut "$f" "$3" "$2"
    CURRCNT=$((CURRCNT + 1))
done

shopt -u nocaseglob

set_int 1
