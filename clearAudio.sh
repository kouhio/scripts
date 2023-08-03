#!/bin/bash

STARTSIZE=`df --output=avail "$PWD" | sed '1d;s/[^0-9]//g'`
GLOBAL_FILESAVE=0
GLOBAL_TIMESAVE=0
NO_EXIT_EXTERNAL=1
EXIT_EXT_VAL=0
COUNTED_ITEMS=0
ERROR=0
I_COUNTER=0

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
    [ -z "$1" ] && echo "interrupted at file $I_COUNTER"

    [ -f "temp_01.mp4" ] && rm "temp_01.mp4"
    [ -f "temp_02.mp4" ] && rm "temp_02.mp4"
    [ -f "combo.txt" ] && rm "combo.txt"

    ENDSIZE=`df --output=avail "$PWD" | sed '1d;s/[^0-9]//g'`
    TOTALSIZE=$((ENDSIZE - STARTSIZE))
    TOTALSIZE=$((TOTALSIZE / 1000))
    GLOBAL_FILESAVE=$((GLOBAL_FILESAVE / 1000))
    ENDTIMER=$(date -d@${GLOBAL_TIMESAVE} -u +%T)

    echo -e "${Y}*** Totally saved $TOTALSIZE Mb and saved time: ${TOTAL_SAVETIME}s in $I_COUNTER files *** ${O}"

    [ -z "$1" ] && exit 1
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
    printf "$TNOW : Seeking audio from %80s %5ds" "$1" "${LENNY}"
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
    I_LENGTH="${data_array[1]%.*}"
    I_START="${data_array[5]%.*}"

    I_START=$((I_START + 1))
    #I_LENGTH=$((I_LENGTH - 1))
    POS=$((I_LENGTH + I_START))
    I_ENDO=$((LENNY - POS))
    CUTSTR=""
    PART_OF_LEN=$((LENNY_AUD / 5))

    if [ ! -z "$I_LENGTH" ]; then
        [ "$I_LENGTH" -le 3 ] && echo -e "${Y} -> Skipping less than 3s: $I_COUNTER :: start:$I_START len:$I_LENGTH len:$LENNY"${O} && return 0
        [ "$I_LENGTH" -lt "$PART_OF_LEN" ] && echo -e ${Y}" -> skipping too short: length short $I_LENGTH/$PART_OF_LEN pos:$I_START"${O} && return 0
    else
        return 0
    fi

    #MPOS=$((POS / 60))
    #SPOS=$((POS % 60))
    #MSTART=$((I_START / 60))
    #SSTART=$((I_START % 60))
    #echo "m:$MPOS s:$SPOS ms:$MSTART ss:$SSTART"

    DOUBLE=0

    # Start is at the beginning, skip too short intro alltogether
    if [ "$I_START" -lt "10" ]; then
        CUTSTR="b=$POS"
        [ -z "$2" ] && echo -en ${Y}" -> Removing front ${POS}s"${O} && packAll.sh "$1" $CUTSTR >/dev/null 2>&1 && I_COUNTER=$((I_COUNTER + 1))

    # No end position, so cut the whole end
    elif [ "$I_ENDO" -lt "10" ]; then
        CUTSTR="e=$POS"
        [ -z "$2" ] && echo -en ${Y}" -> Removing end ${POS}s"${O} && packAll.sh "$1" $CUTSTR >/dev/null 2>&1 && I_COUNTER=$((I_COUNTER + 1))

    # Comparison audio in the middle of the video, remove it from there
    elif [ -z "$2" ]; then
        CALCULATOR=$((LENNY - I_START))
        ENDPOINT=$((I_START + $I_LENGTH))
       #CUTSTR=$((I_START + $I_LENGTH))
       #echo "C=0-$I_START,$CUTSTR-${LENNY}"
       #packAll.sh "$1" C=0-${I_START},${CUTSTR}-0,D
       #error=$?
        printf "${Y} -> Removing from middle %4ss-%4ss${O}" "${I_START}" "${ENDPOINT}"
        CUTSTR="e=$CALCULATOR"
        packAll.sh "$1" k n=temp $CUTSTR >/dev/null 2>&1
        CUTSTR="b=$POS"
        packAll.sh "$1" k n=temp $CUTSTR >/dev/null 2>&1

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
            echo -e ${G}" -> combining successfull, saved ${I_LENGTH}s"${O}
            rm "$1"
            mv "pack_$1" "$1"
            TOTAL_SAVETIME=$((TOTAL_SAVETIME + I_LENGTH))
            I_COUNTER=$((I_COUNTER + 1))
        else
            echo -e ${R}" -> combining failed!"${O}
        fi

        #CUTSTR="C=0-$I_START,$POS-0,D"
    fi

    [ $ERROR -eq 0 ] && ERROR=$?

    [ ! -z "$2" ] && echo "OUT $1 -> start:$I_START len:$I_LENGTH len:$LENNY cut:$CUTSTR"
}

trap set_int SIGINT SIGTERM

shopt -s nocaseglob

for f in *.${1}; do
    get_info_and_cut "$f" "$3" "$2"
done

shopt -u nocaseglob

[ -f "tembase" ] && rm tembase
set_int 1
