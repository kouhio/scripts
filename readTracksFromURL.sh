#!/bin/bash

FIX=0

help () {
    echo "Album info fetcher script"
    echo "Options to use:"
    echo "fix           - change original characters from source to ascii (default: no change)"
    echo "any URL       - source of the site to read data from"
    echo "any filename  - First unknown item is read as a filename, if not given, will just print data out"
    exit
}

for i in $@; do
    if [[ "$i" =~ "http" ]]; then SOURCE="$i"
    elif [[ "$i" =~ "fix" ]]; then FIX=1
    elif [[ "$i" =~ "-h" ]]; then help
    elif [ -z "$OUTPUT_FILE" ]; then
        if [[ "$i" =~ ".txt" ]]; then OUTPUT_FILE="$i"
        else OUTPUT_FILE="${i}.txt"; fi
    else
        echo "Unknown setting $i"
        exit 1
    fi
done

[ -z "$SOURCE" ] && echo "No source URL given!" && exit 1
[[ "$SOURCE" =~ "https" ]] && SOURCE="${SOURCE/https/http}"
echo "Reading data from '$SOURCE' Charfix:$FIX Output:$OUTPUT_FILE 'wget url $SOURCE -qO -'"
LIST=$(wget url $SOURCE -qO -)
tracks=()

if [[ "$SOURCE" =~ "spotify" ]]; then
    echo -en "Parsing Spotify"
    LIST+="\n\n<end>\n"

    ALBUM_INFO=$(echo "$LIST" |grep -o -P '(?<=<title>).*(?=</title>)')
    ALBUM="${ALBUM_INFO%%-*}"
    ALBUM=${ALBUM//:/}
    ALBUM=$(echo "$ALBUM" |recode html..ISO-8859-1)
    [ "$FIX" -eq "1" ] && ALBUM=$(echo "$ALBUM" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")
    ALBUM=$(echo "$ALBUM" |xargs)
    BAND="${ALBUM_INFO##*Album by }"
    BAND="${BAND%%|*}"
    BAND=${BAND//:/ }
    BAND=$(echo "$BAND" |recode html..ISO-8859-1)
    [ "$FIX" -eq "1" ] && BAND=$(echo "$BAND" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")
    BAND=$(echo "$BAND" |xargs)
    YEAR=$(echo "$LIST" |grep -o -P '(?<=music:release_date\" content=\").*(?=\"/><meta name=\"music:song")')
    YEAR="${YEAR%%-*}"

    LIST=$(echo "$LIST" |grep "aria-label")
    IFS="<"
    #re='^( *).*'
    read -ra array <<< "$LIST"

    for index in "${array[@]}"; do
        if [[ "$index" =~ "aria-label=" ]]; then
            [[ "$index" =~ "Save to Your Library" ]] && continue
            #tracks+=($(echo "$index" |grep -o -P '(?<=\"track ).*(?=\">)'))
            NEW_ITEM=$(echo "$index" |grep -o -P '(?<=aria-label=\").*(?=\" data-testid=\")')
            NEW_ITEM=$(echo "$NEW_ITEM" |recode html..ISO-8859-1)
            [ -n "$NEW_ITEM" ] && tracks+=("$NEW_ITEM")
        fi
    done
elif [[ "$SOURCE" =~ "discogs" ]]; then
    echo -en "Parsing discogs"
    BAND=$(echo $LIST |grep -o -P '(?<=\"artist\":\").*?(?=\",\"year\")')
    [ "$FIX" -eq "1" ] && BAND=$(echo "$BAND" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")
    YEAR=$(echo $LIST |grep -o -P '(?<=\"year\":).*?(?=,\"ids\")')
    ALBUM=$(echo $LIST |grep -o -P '(?<=\"title\":\").*?(?=\",\"artist\")')
    ALBUM=$(echo "$ALBUM" |head -1)
    [ "$FIX" -eq "1" ] && ALBUM=$(echo "$ALBUM" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")

    LIST=$(echo "$LIST" |grep "\"Track\"")
    IFS="{"
    #re='^( *).*'
    read -ra array <<< "$LIST"

    POSITION=1
    for index in "${array[@]}"; do
        if [[ "$index" =~ ",\"position\":" ]]; then
            if [[ "$index" =~ "\"Track\",\"title\":" ]]; then
                ITEM=$(echo $index |grep -o -P '(?<=\"Track\",\"title\":\").*?(?=\",\"position\":\")')
                POS=$(echo $index |grep -o -P '(?<=\",\"position\":\").*?(?=\",\"durationInSeconds\":)')
                if [[ ! "$POS" =~ [A-Za-z] ]]; then
                    [ "$POS" -ne "$POSITION" ] && echo "Item position mismatch '$ITEM' Read:$POS Current:$POSITION"
                fi
                tracks+=($ITEM)
                POSITION=$((POSITION + 1))
            fi
        fi
    done
else
    echo "No handling (yet) for '${SOURCE}'"
    exit 1
fi

if [ -n "$OUTPUT_FILE" ]; then
    echo " -> Found $BAND - $YEAR - $ALBUM with ${#tracks[@]} tracks"
    echo "D:$BAND - $YEAR - $ALBUM" > "$OUTPUT_FILE"
    for index in "${tracks[@]}"; do
        echo "$index" >> "$OUTPUT_FILE"
    done
else
    echo "$BAND - $YEAR - $ALBUM"
    for index in "${tracks[@]}"; do
        echo "$index"
    done
fi
