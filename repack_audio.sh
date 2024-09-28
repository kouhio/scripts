#!/bin/bash

INPUT="mp3"
OUTPUT="mp3"
TARGET=""
NEXT=""
DELETE=0
KEEP=0
IGNORE=0
VERBOSE=0
NOHANDLING=0

###########################################################################################################
# Help
###########################################################################################################
if [ "$1" == "-h" ]; then
    printf "Repack audio files to mp3 vbr\nNOTICE! Without additional flags, will delete original file after successful repack!\n\n"
    printf "Options:\n1 - input extension (mp3 default) or flac.cue -file, which will extract tracks and then turn them to flac before compression\n"
    printf "    delete - will delete files that were not packed because size grew and keep new, or in case of cue, will delete cue and flac source\n"
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
set_int () {
    shopt -u nocaseglob
    echo "Interrupted, removing temp ${file}.new.${OUTPUT}"
    if [ -f "${file}.new.${OUTPUT}" ]; then
        rm "${file}.new.${OUTPUT}"
    fi
    GLOBAL_FILESAVE=$((GLOBAL_FILESAVE + TOTALSAVE))
    echo "Repacked $SUCCESS files, failed $FAILED, skipped $SKIPPED nosave:$DIDNTSAVE. Saved $(lib size "$TOTALSAVE")"
    exit 1
}

###########################################################################################################
# Handle cue fils
# 1 - path to cue file
###########################################################################################################
handle_cue () {
    EXT="${1##*.}"
    FILE="${1%.*}"

    if [ "$EXT" == "cue" ]; then
        error=0
        SOURCE="${FILE}.flac"
        echo "shnsplit -f ${1} -t %n-%t -o flac ${SOURCE}"
#ffmpeg -i input.flac -f segment -segment_time <duration> -c copy output%d.flac
        shnsplit -f "${1}" -t %n-%t -o flac "${SOURCE}"
        error=$?
        if [ "$error" -eq "0" ]; then
            if [ "$DELETE" == "1" ]; then rm "${1}" && rm "${SOURCE}";
            else mkdir "old" && mv "${1}" "${SOURCE}" "old"; fi
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
handle_file () {
    file="${1}"
    INFO=$(mediainfo "${file}")
    FILE="${file%.*}"

    if [[ "$INFO" =~ "Variable" ]]; then
        if [ "$INPUT" == "mp3" ] && [ "$OUTPUT" == "mp3" ]; then
            SKIPPED=$((SKIPPED + 1))
            [ "$VERBOSE" -ne "0" ] && echo "  - Skipping $file because already variable bitrate"
            return
        fi
    fi

    fileprint="${file##*/}"
    printf "  - Starting to pack %-40s to ${OUTPUT} : " "${fileprint:0:40}"
    error=0
    INPUTSIZE=$(du -k "$file" | cut -f1)
    lame -V 0 -h "${file}" "${file}.new.${OUTPUT}" >/dev/null 2>&1
    error=$?

    if [ "$error" == 0 ]; then
        OUTPUTSIZE=$(du -k "${file}.new.${OUTPUT}" | cut -f1)
        if [ "$OUTPUTSIZE" -gt "$INPUTSIZE" ] && [ "$IGNORE" == "0" ]; then
            echo "new size bigger than original $(lib size "$OUTPUTSIZE") > $(lib size "$INPUTSIZE")"
            DIDNTSAVE=$((DIDNTSAVE + 1))
            [ "$DELETE" == "0" ] && rm "${file}.new.${OUTPUT}"
            [ "$DELETE" == "1" ] && rm "${file}" && mv "${file}.new.${OUTPUT}" "${file}"
        else
           [ "$KEEP" == "0" ] && rm "${file}"
           [ "$KEEP" == "1" ] && mv "${file}" "${file}.old"
           mv "${file}.new.${OUTPUT}" "${FILE}.${OUTPUT}"

           TOTALSAVE=$((TOTALSAVE + (INPUTSIZE - OUTPUTSIZE)))
           printf "repacked succesfully, saved %-6s total:%s\n" "$(lib size $((INPUTSIZE - OUTPUTSIZE)))" "$(lib size $TOTALSAVE)"
           SUCCESS=$((SUCCESS + 1))
           [ -n "$TARGET" ] && echo "$file" >> "$TARGET"
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
    elif [ "$loop" == "0" ];    then INPUT="$i"
    elif [ "$i" == "delete" ];  then DELETE=1
    elif [ "$i" == "ignore" ];  then IGNORE=1
    elif [ "$i" == "keep" ];    then KEEP=1
    elif [ "$i" == "target" ];  then NEXT="next"
    elif [ "$i" == "loud" ];    then VERBOSE=1
    elif [ "$NEXT" == "next" ]; then OUTPUT="$i" && NEXT=""
    elif [ "$loop" -gt "0" ];   then TARGET="$i"
    fi
    loop=$((loop + 1))
done

#TODO: if input is *cue, then also handle it correctly, also once handled .cue remove original cue and flac before packing

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

TOTALSAVE=0
SUCCESS=0
FAILED=0
SKIPPED=0
DIDNTSAVE=0

shopt -s nocaseglob

###########################################################################################################
# Loop given filetypes
###########################################################################################################
if [ "${NOHANDLING}" -eq "0" ]; then
    for file in *".$INPUT"; do
        [ ! -f "${file}" ] && continue
        handle_file "${file}"
    done
fi

shopt -u nocaseglob
GLOBAL_FILESAVE=$((GLOBAL_FILESAVE + TOTALSAVE))
echo "Repacked $SUCCESS files, failed $FAILED, skipped $SKIPPED nosave:$DIDNTSAVE. Saved $(lib size $TOTALSAVE)"

