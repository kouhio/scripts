#!/bin/bash

#Run command and calculate how long it takes

start_time=$(date +%s)

set_int () {
    OUTPUT="\n"
    [ "$1" == "0" ] && OUTPUT+="Finished "
    [ "$1" == "1" ] && OUTPUT+="Cancelled "
    OUTPUT+="'$2"
    [[ "$2" =~ "python" ]] && OUTPUT+=" $3"

    end_time=$(date +%s)
    total_time=$((end_time - start_time))
    print_time=$(date -d@${total_time} -u +%T)

    OUTPUT+="' in $print_time\n"
    echo -en "$OUTPUT"

    exit "$1"
}

trap 'set_int 1 $1 $2' SIGINT SIGTERM

"$@"

set_int "0" "$1" "$2"
