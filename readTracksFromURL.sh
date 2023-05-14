#/bin/bash!

FIX=1

help () {
    echo "Album info fetcher script"
    echo "Options to use:"
    echo "nofix         - keep original characters from source (default: change chars)"
    echo "any URL       - source of the site to read data from"
    echo "any filename  - First unknown item is read as a filename, if not given, will just print data out"
    exit
}

for i in $@; do
    if [[ "$i" =~ "http" ]]; then SOURCE="$i"
    elif [[ "$i" =~ "nofix" ]]; then FIX=0
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
echo "Reading data from '$SOURCE' Charfix:$FIX Output:$OUTPUT"
LIST=$(wget "$SOURCE" -qO -)
tracks=()

if [[ "$SOURCE" =~ "spotify" ]]; then
    LIST+="\n\n<end>\n"

    ALBUM_INFO=$(echo "$LIST" |grep -o -P '(?<=<title>).*(?=</title>)')
    ALBUM="${ALBUM_INFO%%-*}"
    ALBUM=${ALBUM//:/ }
    [ "$FIX" -eq "1" ] && ALBUM=$(echo "$ALBUM" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")
    BAND="${ALBUM_INFO##*Album by }"
    BAND="${BAND%%|*}"
    BAND=${BAND//:/ }
    [ "$FIX" -eq "1" ] && BAND=$(echo "$BAND" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")
    YEAR=$(echo "$LIST" |grep -o -P '(?<=music:release_date\" content=\").*(?=\"/><meta name=\"music:song")')
    YEAR="${YEAR%%-*}"

    LIST=$(echo "$LIST" |grep "aria-label")
    IFS="<"
    re='^( *).*'
    read -ra array <<< "$LIST"

    for index in "${array[@]}"; do
        if [[ "$index" =~ "aria-label=\"track" ]]; then
            tracks+=($(echo "$index" |grep -o -P '(?<=\"track ).*(?=\">)'))
        fi
    done
elif [[ "$SOURCE" =~ "discogs" ]]; then
    BAND=$(echo $LIST |grep -o -P '(?<=\"artist\":\").*?(?=\",\"year\")')
    [ "$FIX" -eq "1" ] && BAND=$(echo "$BAND" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")
    YEAR=$(echo $LIST |grep -o -P '(?<=\"year\":).*?(?=,\"ids\")')
    ALBUM=$(echo $LIST |grep -o -P '(?<=\"title\":\").*?(?=\",\"artist\")')
    ALBUM=$(echo "$ALBUM" |head -1)
    [ "$FIX" -eq "1" ] && ALBUM=$(echo "$ALBUM" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")

    LIST=$(echo "$LIST" |grep "\"Track\"")
    IFS="{"
    re='^( *).*'
    read -ra array <<< "$LIST"

    POSITION=1
    for index in "${array[@]}"; do
        if [[ "$index" =~ ",\"position\":" ]]; then
            if [[ "$index" =~ "\"Track\",\"title\":" ]]; then
                ITEM=($(echo $index |grep -o -P '(?<=\"Track\",\"title\":\").*?(?=\",\"position\":\")'))
                POS=($(echo $index |grep -o -P '(?<=\",\"position\":\").*?(?=\",\"durationInSeconds\":)'))
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

if [ ! -z "$OUTPUT_FILE" ]; then
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