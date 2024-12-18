#!/bin/bash

INPUT="mp3"
OUTPUT="mp3"
TARGET=""
NEXT=""
DELETE=0
KEEP_CUE=0
KEEP=0
IGNORE=0
VERBOSE=0
NOHANDLING=0
ST_TIME=$(date +%s)
F_COUNT=0

###########################################################################################################
# Help
###########################################################################################################
if [ "$1" == "-h" ]; then
    printf "Repack audio files to mp3 vbr\nNOTICE! Without additional flags, will delete original file after successful repack!\n\n"
    printf "Options:\n1 - input extension (mp3 default) or flac.cue -file, which will extract tracks and then turn them to flac before compression\n"
    printf "    delete - will delete files that were not packed because size grew and keep new\n"
    printf "    keep_cue - will keep cue and flac source, and move to old-folder, otherwise will delete sources once successfully done\n"
    printf "    keep - will keep original file and rename it to NAME.old\n"
    printf "    ignore - keep new file, even if it's bigger than original\n"
    printf "    loud - More verbose output\n"
    printf "    target audio-type (separated with space, default mp3)\n"
    printf "    any other given value will print paths of successfully packed audio to given input filename\n"
    exit 1
fi

###########################################################################################################
# Interrupt handler
###########################################################################################################
set_int (){
    shopt -u nocaseglob
    printf "Interrupted, removing temp %s.new.%s\n" "${file}" "${OUTPUT}"
    if [ -f "${file}.new.${OUTPUT}" ]; then rm "${file}.new.${OUTPUT}"; fi
    if [ -f "${TARGETNAME}" ]; then rm "${TARGETNAME}"; fi
    if [ -f "${CUE_TARGET}/${TARGETNAME}" ]; then rm "${CUE_TARGET}/${TARGETNAME}"; fi
    END_TIME=$(date +%s)
    DIFF_TIME=$((END_TIME - ST_TIME))

    printf "Repacked %s files, failed %s, skipped %s nosave:%s. Saved %s in %s\n" "$SUCCESS" "$FAILED" "$SKIPPED" "$DIDNTSAVE" "$(lib size "$TOTALSAVE")" "$(date -d@$DIFF_TIME +%M:%S)"
    exit 1
}

###########################################################################################################
# Read track info from cue-file
# 1 - path to cue-file
###########################################################################################################
read_cue(){
    CUE_BAND=""
    CUE_ALBUM=""
    CUE_TRACK=()
    CUE_INDEX=()
    CUE_FILE=""
    CUE_YEAR=""

    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == *" TITLE"* ]]; then
            CUE_TRACK+=("$(echo "$line" | awk -F '"' '{print $2}')")
        elif [[ "$line" == "TITLE"* ]]; then
            CUE_ALBUM="$(echo "$line" | awk -F '"' '{print $2}')"
        elif [[ "$line" == "PERFORMER"* ]]; then
            CUE_BAND="$(echo "$line" | awk -F '"' '{print $2}')"
        elif [[ "$line" == "FILE"* ]]; then
            CUE_FILE="$(echo "$line" | awk -F '"' '{print $2}')"
        elif [[ "$line" == *"INDEX 01"* ]]; then
            TEMP_ITEM="$(echo "${line%%[[:cntrl:]]}" | sed 's/\(.*\):/\1./')"
            CUE_INDEX+=("$(echo "$TEMP_ITEM" | awk -F ' ' '{print $3}')")
        elif [[ "$line" == "REM DATE"* ]]; then
            TEMP_ITEM="${line%%[[:cntrl:]]}"
            CUE_YEAR="$(echo "$TEMP_ITEM" | awk -F ' ' '{print $3}')"
        fi
    done < "$1"

    [ ! -f "$CUE_FILE" ] && printf "No source audio found:'%s'\n" "$CUE_FILE" && exit
}

###########################################################################################################
# Split cue flac file with ffmpeg
###########################################################################################################
split_cue() {
    CUE_TRACKNUM=1
    CUE_START=0
    CUE_TARGET="$CUE_BAND - $CUE_YEAR - $CUE_ALBUM"
    mkdir -p "$CUE_TARGET"

    for track in "${!CUE_TRACK[@]}"; do
        TARGETNAME="$(printf "%02d - %s.flac" "${CUE_TRACKNUM}" "${CUE_TRACK[$track]}")"

        CUE_END="${CUE_INDEX[$CUE_TRACKNUM]}"
        if [ -n "$CUE_END" ]; then END_CMD=("-to" "$CUE_END")
        else END_CMD=(); fi

        printf " - %02d/%02d Extracting '%s'" "$CUE_TRACKNUM" "${#CUE_TRACK[@]}" "${TARGETNAME}"
        [ -f "$TARGETNAME" ] && rm "$TARGETNAME"
        ffmpeg -i "$CUE_FILE" -ss "$CUE_START" "${END_CMD[@]}" -vn "${TARGETNAME}" 2>/dev/null
        error=$?
        [ "$error" != "0" ] && printf "Failed! error:%s\n" "$error" && exit
        mv "$TARGETNAME" "${CUE_TARGET}/"
        printf " DONE!\n"
        CUE_TRACKNUM=$((CUE_TRACKNUM + 1))
        CUE_START="$CUE_END"
    done
}

###########################################################################################################
# Handle cue fils
# 1 - path to cue file
###########################################################################################################
handle_cue (){
    EXT="${1##*.}"
    FILE="${1%.*}"

    if [ "$EXT" == "cue" ]; then
        F_TIME=$(date +%s)
        read_cue "$1"
        error=0
        split_cue
        error=$?
        N_TIME=$(date +%s)
        DIFF_TIME=$((N_TIME - F_TIME))
        if [ "$error" -eq "0" ]; then
            if [ "$KEEP_CUE" == "0" ]; then rm "${1}" && rm "${CUE_FILE}";
            else mkdir -p "old" && mv "${1}" "${CUE_FILE}" "old"; fi
            printf "Split cue in %s\n" "$(date -d@$DIFF_TIME +%M:%S)"
        else
            exit 1
        fi
        INPUT="flac"
    fi
}

###########################################################################################################
# Handle file packing
# 1 - input filename
###########################################################################################################
handle_file (){
    F_TIME=$(date +%s)
    file="${1}"
    INFO=$(mediainfo "${file}")
    FILE="${file%.*}"

    if [[ "$INFO" =~ "Variable" ]]; then
        if [ "$INPUT" == "mp3" ] && [ "$OUTPUT" == "mp3" ]; then
            SKIPPED=$((SKIPPED + 1))
            [ "$VERBOSE" -ne "0" ] && printf "  - Skipping '%s' because already variable bitrate\n" "$file"
            return
        fi
    fi

    fileprint="${file##*/}"

    if [ "$F_COUNT" -gt "1" ]; then printf "  - %02d/%02d Starting to pack %-40s to ${OUTPUT} : " "$F_CURR" "$F_COUNT" "${fileprint:0:40}"
    else printf "  - Starting to pack %-40s to ${OUTPUT} : " "${fileprint:0:40}"; fi

    error=0
    INPUTSIZE=$(du -k "$file" | cut -f1)
    lame -V 0 -h "${file}" "${file}.new.${OUTPUT}" >/dev/null 2>&1
    error=$?
    N_TIME=$(date +%s)
    DIFF_TIME=$((N_TIME - F_TIME))

    if [ "$error" == 0 ]; then
        OUTPUTSIZE=$(du -k "${file}.new.${OUTPUT}" | cut -f1)
        if [ "$OUTPUTSIZE" -gt "$INPUTSIZE" ] && [ "$IGNORE" == "0" ]; then
            printf "new size bigger than original %s > %s\n" "$(lib size "$OUTPUTSIZE")" "$(lib size "$INPUTSIZE")"
            DIDNTSAVE=$((DIDNTSAVE + 1))
            [ "$DELETE" == "0" ] && rm "${file}.new.${OUTPUT}"
            [ "$DELETE" == "1" ] && rm "${file}" && mv "${file}.new.${OUTPUT}" "${file}"
        else
           [ "$KEEP" == "0" ] && rm "${file}"
           [ "$KEEP" == "1" ] && mv "${file}" "${file}.old"
           mv "${file}.new.${OUTPUT}" "${FILE}.${OUTPUT}"

           TOTALSAVE=$((TOTALSAVE + (INPUTSIZE - OUTPUTSIZE)))
           printf "repacked succesfully, saved %-6s total:%s in %s\n" "$(lib size $((INPUTSIZE - OUTPUTSIZE)))" "$(lib size $TOTALSAVE)" "$(date -d@$DIFF_TIME -u +%M:%S)"
           SUCCESS=$((SUCCESS + 1))
           [ -n "$TARGET" ] && printf "%s\n" "${file}" >> "$TARGET"
        fi
    elif [ -f "${file}.new.${OUTPUT}" ]; then
        printf "Failed to repack\n"
        rm "${file}.new.${OUTPUT}"
        FAILED=$((FAILED + 1))
    fi
}

trap set_int SIGINT SIGTERM

###########################################################################################################
# Read commandline input
###########################################################################################################
loop=0
for i in "${@}"; do
    if   [ "$i" == "repack_audio.sh" ]; then continue
    elif [ "$loop" == "0" ];     then mapfile -t -d "," MULTILIST < <(printf "%s" "$i"); INPUT="${MULTILIST[0]}"
    elif [ "$i" == "delete" ];   then DELETE=1
    elif [ "$i" == "keep_cue" ]; then KEEP_CUE=1
    elif [ "$i" == "ignore" ];   then IGNORE=1
    elif [ "$i" == "keep" ];     then KEEP=1
    elif [ "$i" == "target" ];   then NEXT="next"
    elif [ "$i" == "loud" ];     then VERBOSE=1
    elif [ "$NEXT" == "next" ];  then OUTPUT="$i" && NEXT=""
    elif [ "$loop" -gt "0" ];    then TARGET="$i"
    fi
    loop=$((loop + 1))
done

###########################################################################################################
# Specific cue or file handling
###########################################################################################################
if [ -f "$INPUT" ]; then
    if [[ "${INPUT}" == *"cue" ]]; then
        handle_cue "$INPUT"
    else
        handle_file "${INPUT}"
        NOHANDLING=1
    fi
elif [[ "$INPUT" =~ "cue" ]]; then
    for file in *".$INPUT"; do
        handle_cue "$file"
    done
fi

[ -z "$TOTALSAVE" ] && TOTALSAVE=0
SUCCESS=0
FAILED=0
SKIPPED=0
DIDNTSAVE=0

shopt -s nocaseglob

###########################################################################################################
# Loop given filetypes
###########################################################################################################
#for f in *.{mkv,wmv,avi,mpg,mts,mp4}; do
# Also do an external total filehandler setting, also for eachDir
if [ "${NOHANDLING}" -eq "0" ]; then
    for INPUT in "${MULTILIST[@]}"; do
        F_CURR=1; F_COUNT=$(lib f c "$INPUT")
        for file in *."${INPUT}"; do
            [ ! -f "${file}" ] && continue
            handle_file "${file}"
            F_CURR=$((F_CURR + 1))
        done
    done
fi

END_TIME=$(date +%s)
DIFF_TIME=$((END_TIME - ST_TIME))
shopt -u nocaseglob

printf "Repacked %s files, failed %s, skipped %s nosave:%s. Saved %s in %s\n" "$SUCCESS" "$FAILED" "$SKIPPED" "$DIDNTSAVE" "$(lib size "$TOTALSAVE")" "$(date -d@$DIFF_TIME +%M:%S)"

