#!/bin/bash

#************************************************************************
# Print process duration time
#************************************************************************
print_duration() {
    endtime=$(date +%s)
    total_time=$((endtime - start_time))
    printf "Total time taken:%s\n" "$(date -d@${total_time} -u +%T)"
}

#************************************************************************
# If interrupted, stop all processess
#************************************************************************
set_int () {
    printf "Main conversion interrupted!"
    print_duration
    exit 1
}

trap set_int SIGINT SIGTERM

#************************************************************************
# Initialize variables
#************************************************************************
init() {
    cnt=0
    total_err=0
    total_suc=0
    failed=()
    start_time=$(date +%s)
}

#************************************************************************
# Go through all files in directory and fix possible problems
#************************************************************************
check_files() {
    CNT=0; ERR=0

    TL=$(tput cols)
    for F in *.mp3; do
        if ! mp3val "${F}" -f -t -nb >/dev/null 2>&1; then
            ((ERR++)); failed+=("$(basename "$(pwd)")/${F}")
            #printf "%s/%s failed!\n" "$(basename "$(pwd)")" "${F}"
        else ((CNT++)); fi

        OUTPUT="$(printf "%02d/%02d fixed, failed:%02d in '%s/%s'" "${CNT}" "${cnt}" "${ERR}" "$(basename "$(pwd)")" "${F}")"
        LEN2=$((TL - ${#OUTPUT} - 2))
        printf "\r%s" "${OUTPUT:0:${LEN2}}"
    done

    total_err=$((total_err + ERR))
    total_suc=$((total_suc + CNT))
}

#************************************************************************
# Process directory files and directories
#************************************************************************
process_directory() {
    for D in *; do
        if [ "$D" == "lost+found" ]; then
            continue
        elif [ -d "${D}" ]; then
            cd "$D" || continue

            #echo "Entering directory $D"
            cnt=$(find . -maxdepth 1 -name "*.mp3" |wc -l)
            if [ "$cnt" -gt "0" ]; then
                check_files
            else
                process_directory
            fi

            cd ..
        fi
    done
}

#**********************************************************************************
# Verify necessary external programs
#**********************************************************************************
verify_dependencies() {
    error_code=0
    hash mp3val || error_code=$?

    if [ $error_code -ne 0 ]; then
        echo "Missing one mp3val, please install"
        exit 1
    fi
}

#************************************************************************
# Start process
# 1 - Possible input directory or file
#************************************************************************
main() {
    if [ -z "$1" ]; then
        process_directory
    else
        if [ -d "$1" ]; then
            cd "$1" || echo "Something wrong with $1, can't enter directory!" && exit 1
            process_directory
            cd ..
        else
            FILE="${1##*.}"
            if [ "$FILE" == "mp3" ]; then
                if ! mp3val "${1}" -f -t -nb >/dev/null 2>&1; then printf "%s failed!\n" "${FILE}"
                else printf "%s done!\n" "${1}"; fi
            else
                echo "$1 is not a mp3 file"
                exit 1
            fi
        fi
    fi
}

#************************************************************************
# Main function
#************************************************************************
verify_dependencies
init
main "${@}"

if [ "${#failed[@]}" -gt "0" ]; then printf "Failed items:\n"; fi
for j in "${failed[@]}"; do printf "Failed %s\n" "${j}"; done

printf "Handled succesfully %d and failed %d mp3 files\n" "${total_suc}" "${total_err}"
print_duration
