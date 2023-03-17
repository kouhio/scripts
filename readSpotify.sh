#/bin/bash!

[ -z "$1" ] && echo "no spotify url given!" && exit 1
[ -z "$2" ] && echo "no output file given!" && exit 1

if [[ "$2" =~ ".txt" ]]; then OUTPUT_FILE="$2"
else OUTPUT_FILE="${2}.txt"; fi

LIST=$(wget "$1" -qO -)
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

track=()
for index in "${array[@]}"; do
    if [[ "$index" =~ "aria-label=\"track" ]]; then
        #tracks+=($index)
        tracks+=($(echo "$index" |grep -o -P '(?<=\"track ).*(?=\">)'))
    fi
done

echo "D:$BAND - $YEAR - $ALBUM" > "$OUTPUT_FILE"
for index in "${tracks[@]}"; do
    echo "$index" >> "$OUTPUT_FILE"
done
