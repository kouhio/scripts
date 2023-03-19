#/bin/bash!

[ -z "$1" ] && echo "no URL given!" && exit 1
#[ -z "$2" ] && echo "no output file given!" && exit 1

if [ ! -z "$2" ]; then
    if [[ "$2" =~ ".txt" ]]; then OUTPUT_FILE="$2"
    else OUTPUT_FILE="${2}.txt"; fi
fi

LIST=$(wget "$1" -qO -)
tracks=()

if [[ "$1" =~ "spotify" ]]; then
    LIST+="\n\n<end>\n"

    ALBUM_INFO=$(echo "$LIST" |grep -o -P '(?<=<title>).*(?=</title>)')
    ALBUM="${ALBUM_INFO%%-*}"
    ALBUM=${ALBUM//:/ }
    ALBUM=$(echo "$ALBUM" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")
    BAND="${ALBUM_INFO##*Album by }"
    BAND="${BAND%%|*}"
    BAND=${BAND//:/ }
    BAND=$(echo "$BAND" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")
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
elif [[ "$1" =~ "discogs" ]]; then
    BAND=$(echo $LIST |grep -o -P '(?<=\"artist\":\").*?(?=\",\"year\")')
    YEAR=$(echo $LIST |grep -o -P '(?<=\"year\":).*?(?=,\"ids\")')
    ALBUM=$(echo $LIST |grep -o -P '(?<=\"title\":\").*?(?=\",\"artist\")')
    ALBUM=$(echo "$ALBUM" |head -1)

#    "Track","title":"Steamroller","position":"1",

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
                [ "$POS" -ne "$POSITION" ] && echo "Item position mismatch '$ITEM' Read:$POS Current:$POSITION"
                tracks+=($ITEM)
                POSITION=$((POSITION + 1))
            fi
        fi
    done
else
    echo "No handling (yet) for '${1}'"
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
