#"!/bin/bash

INPUT="mp3"
OUTPUT="mp3"
TARGET=""
NEXT=""
DELETE=0
KEEP=0
IGNORE=0

if [ "$1" == "-h" ]; then
    printf "Repack audio files to mp3 vbr\nNOTICE! Without additional flags, will delete original file after successful repack!\n\n"
    printf "Options:\n1 - input extension (mp3 default) or flac.cue -file, which will extract tracks and then turn them to flac before compression\n"
    printf "    delete - will delete files that were not packed because size grew and keep new, or in case of cue, will delete cue and flac source\n"
    printf "    keep - will keep original file and rename it to NAME.old\n"
    printf "    ignore - keep new file, even if it's bigger than original\n"
    printf "    target audio-type (separated with space, default mp3)\n"
    printf "    any other given value will print paths of successfully packed audio to given input filename\n"
    exit 1
fi

set_int () {
    echo "Interrupted, removing temp ${file}.new.${OUTPUT}"
    if [ -f "${file}.new.${OUTPUT}" ]; then
        rm "${file}.new.${OUTPUT}"
    fi
    exit 1
}

trap set_int SIGINT SIGTERM

loop=0
for i in "${@}"; do
    if   [ "$loop" == "0" ];    then INPUT="$i"
    elif [ "$i" == "delete" ];  then DELETE=1
    elif [ "$i" == "ignore" ];  then IGNORE=1
    elif [ "$i" == "keep" ];    then KEEP=1
    elif [ "$i" == "target" ];  then NEXT="next"
    elif [ "$NEXT" == "next" ]; then OUTPUT="$i" && NEXT=""
    elif [ "$loop" -gt "0" ];   then TARGET="$i"
    fi
    loop=$((loop + 1))
done

if [ -f "$INPUT" ]; then
    EXT="${INPUT##*.}"
    FILE="${INPUT%.*}"

    if [ "$EXT" == "cue" ]; then
        error=0
        SOURCE="${FILE}.flac"
        echo "shnsplit -f ${INPUT} -t %n-%t -o flac ${SOURCE}"
        shnsplit -f "${INPUT}" -t %n-%t -o flac "${SOURCE}"
        error=$?
        if [ "$error" -eq "0" ]; then
            [ "$DELETE" == "1" ] && rm "${INPUT}" && rm "${SOURCE}"
        else
            exit 1
        fi
        INPUT="flac"
    fi
fi

TOTALSAVE=0
SUCCESS=0
FAILED=0
SKIPPED=0
DIDNTSAVE=0

shopt -s nocaseglob

for file in *.$INPUT; do
    INFO=$(mediainfo "${file}")
    FILE="${file%.*}"
    if [[ "$INFO" =~ "Variable" ]]; then
        if [ "$INPUT" == "mp3" ] && [ "$OUTPUT" == "mp3" ]; then
            SKIPPED=$((SKIPPED + 1))
            echo "Skipping $file because already variable bitrate"
            continue
        fi
    fi
    printf "Starting to pack '${file##*/}' to $OUTPUT : "
    error=0
    INPUTSIZE=$(du -k "$file" | cut -f1)
    lame -V 0 -h "${file}" "${file}.new.${OUTPUT}" >/dev/null 2>&1
    error=$?
    if [ "$error" == 0 ]; then
        OUTPUTSIZE=$(du -k "${file}.new.${OUTPUT}" | cut -f1)
        if [ "$OUTPUTSIZE" -gt "$INPUTSIZE" ] && [ "$IGNORE" == "0" ]; then
            printf "new size bigger than original $OUTPUTSIZE > $INPUTSIZE\n"
            DIDNTSAVE=$((DIDNTSAVE + 1))
            [ "$DELETE" == "0" ] && rm "${file}.new.${OUTPUT}"
            [ "$DELETE" == "1" ] && rm "${file}" && mv "${file}.new.${OUTPUT}" "${file}"
        else
           [ "$KEEP" == "0" ] && rm "${file}"
           [ "$KEEP" == "1" ] && mv "${file}" "${file}.old"
           mv "${file}.new.${OUTPUT}" "${FILE}.${OUTPUT}"

           printf "repacked succesfully, saved $((INPUTSIZE - OUTPUTSIZE)) total:$TOTALSAVE\n"
           TOTALSAVE=$((TOTALSAVE + (INPUTSIZE - OUTPUTSIZE)))
           SUCCESS=$((SUCCESS + 1))
           [ ! -z "$TARGET" ] && echo "$file" >> $TARGET
        fi
    elif [ -f "${file}.new.${OUTPUT}" ]; then
        printf "Failed to repack\n"
        rm "${file}.new.${OUTPUT}"
        FAILED=$((FAILED + 1))
    fi
done

shopt -u nocaseglob
TOTALSAVE=$((TOTALSAVE / 1000))
printf "Repacked $SUCCESS files, failed $FAILED, skipped $SKIPPED nosave:$DIDNTSAVE. Saved $TOTALSAVE Mb\n"

