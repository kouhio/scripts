#!/bin/bash

savedir="handled_inputs"            # directory where already handled items are pushed to, if they're not deleted

help () {
    echo -en "Split all given input filetypes to mp3\n  If same file with .txt ending exists, will use that as source for splitting info\n\n"
    echo -en "1 - filetype extension\n\n"
    echo -en "any additional input will be given as findSilence.sh additional parameters, overwriting the defaults\n\n"
    echo -en "default parameters:\n  -d 5 (minimun duration for silence)\n  -t mp3 (target filetype)\n  -m 10 (minimum duration for output)\n  -s (split into files without silence)\n\n"
    echo -en "adding -D will delete source files if extraction is successful\n"
    exit 0
}

set_int () {
    echo "$0 has been interrupted while handling '$filename'!"
    exit 1
}

[ -z "$1" ] && help
input="$1"

trap set_int SIGINT SIGTERM
shift 1
mkdir -p "$savedir"

cnt=0
for f in *.$input; do
    [ ! -f "$f" ] && continue
    echo "handling '$f'"
    filename="${f%.*}"
    ext="${f##*.}"
    settings="-T $filename"
    err_cod=0
    [ -f "${filename}.txt" ] && settings="-F ${filename}.txt"
    findSilence.sh "$f" -d 5 -t mp3 -m 10 $settings -s "$@"
    err_cod=$?
    cnt=$((cnt + 1))
    [ "$err_cod" -eq "0" ] && [ -f "$f" ] && mv "${filename}."* "$savedir/"
done


echo "Handled $cnt number of $input items"
