#"!/bin/bash

INPUT="mp3"
OUTPUT="mp3"
TARGET=""
OPTION=""

if [ "$1" == "-h" ]; then
    printf "Repack audio files to mp3 vbr\nNOTICE! Without additional flags, will delete original file after successful repack!\n\n"
    printf "Options:\n1 - input extension (mp3 default)\n"
    printf "2 - if set, will print paths of successfully packed audio to given file\n"
    printf "3 - delete/keep/ignore\n    delete - will delete files that were not packed because size grew\n"
    printf "    keep - will keep original file and rename it to NAME.old\n"
    printf "    ignore - keep new file, even if it's bigger than original"

    exit 1
fi

#TODO: capture signal, delete middlefile

[ ! -z "$1" ] && INPUT="$1"
[ ! -z "$2" ] && TARGET="$2"
[ ! -z "$3" ] && OPTION="$3"

TOTALSAVE=0
SUCCESS=0
FAILED=0
SKIPPED=0
DIDNTSAVE=0

find . -type f -iname "*.${INPUT}" | while read file
do
    INFO=$(mediainfo "${file}")
    if [[ "$INFO" =~ "Variable" ]]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    printf "Starting to pack '${file##*/}' to $OUTPUT : "
    error=0
    INPUTSIZE=$(du -k "$file" | cut -f1)
    lame -V 0 -h "${file}" "${file}.new.${OUTPUT}" >/dev/null 2>&1
    error=$?
    if [ "$error" == 0 ]; then
        OUTPUTSIZE=$(du -k "${file}.new.${OUTPUT}" | cut -f1)
        if [ "$OUTPUTSIZE" -gt "$INPUTSIZE" ] && [ "$OPTION" != "ignore" ]; then
            printf "new size bigger than original $OUTPUTSIZE > $INPUTSIZE\n"
            DIDNTSAVE=$((DIDNTSAVE + 1))
            rm "${file}.new.${OUTPUT}"
            [ "$OPTION" == "delete" ] && rm "${file}"
        else
           [ "$OPTION" != "keep" ] && rm "${file}"
           [ "$OPTION" == "keep" ] && mv "${file}" "${file}.old"
           mv "${file}.new.${OUTPUT}" "${file}"

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

TOTALSAVE=$((TOTALSAVE / 1000))
printf "Repacked $SUCCESS files, failed $FAILED, skipped $SKIPPED nosave:$DIDNTSAVE. Saved $TOTALSAVE Mb\n"

