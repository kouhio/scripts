#!/bin/bash

########################################################################
# Initialize global variables
########################################################################
init() {
    SOURCE=""
    TARGET=""
    FIND=""
    PRINT=0
    PAUSE=0
    REMOVECOUNT=0
}

########################################################################
# Verify if found data has more than one declaration
# Array is used as such:
# 0 - The found string
# 1 - The first part to be found
# 2 - The seconds part to verify the same data (if null, skipped)
########################################################################
verify() {
    array=(${1// / })

    if [ -z "${array[2]}" ]; then
        [ ! -z "$TARGET" ] && echo "$1" >> "$TARGET"
        return 0
    fi

    INPUT=$(grep -r "${array[1]}")
    INPUT2=$(grep "${array[2]}" <<< "$INPUT")
    COUNT=$(grep -c "${array[2]}" <<< "$INPUT")
    PRESERVED=0

    if [ "$COUNT" -ge "2" ]; then
        if [ "$COUNT" -gt "2" ] && [ "$COUNT" -lt "10" ]; then
            echo "Found ${array[1]} ${array[2]} '$COUNT'"
            echo -e '\033[0;31m'"$INPUT2"'\033[0m'
            echo -n "Multiple found! Preserve (y/n)?"
            read -rsn1 input < /dev/tty
            if [ "$input" == "y" ]; then
                if [ ! -z "$TARGET" ]; then
                    PRESERVED=1
                    echo "$1" >> "$TARGET"
                fi
            fi
            echo " "
        elif [ "$COUNT" -ge 10 ]; then
            echo "${array[1]} -> ${array[2]} -> Found too many times ($COUNT)"
            [ ! -z "$TARGET" ] && echo "$1" >> "$TARGET"
            PRESERVED=1
        elif [ ! -z "$PRINT" ]; then
            echo "$INPUT2"
            echo " "
            if [ $PAUSE -ne 0 ]; then
                echo "Keep this match (y/n)?"
                read -rsn1 input < /dev/tty
                if [ "$input" == "y" ]; then
                    if [ ! -z "$TARGET" ]; then
                        PRESERVED=1
                        echo "$1" >> "$TARGET"
                    fi
                fi
            fi
        fi

        [ $PRESERVED -eq 0 ] && ((REMOVECOUNT++))

    elif [ ! -z "$TARGET" ]; then
        echo "$1" >> "$TARGET"
    fi
}

########################################################################
# Read input file and for each line FIND is found, verify it
# exists in multiple files
########################################################################
readFile() {
    if [ ! -f "$1" ]; then
        echo "$1 is not a file!"
        exit 1
    fi

    if [ ! -z "$TARGET" ]; then
        [ -f "$TARGET" ] && rm "$TARGET"
        touch "$TARGET"
    fi

    while IFS= read -r p || [[ -n "$p" ]]; do
        if [[ "$p" =~ $FIND ]]; then
            if [[ "$p" =~ "\\" ]]; then
                [ ! -z "$TARGET" ] && echo "$p" >> "$TARGET"
            else
                verify "$p"
            fi
        elif [ ! -z "$TARGET" ]; then
            echo "$p" >> "$TARGET"
        fi
    done < "$1"
}

#**************************************************************************************************************
# Print help
#**************************************************************************************************************
print_help() {
    echo "Find one argument and grep it against all"
    echo -e "\nIf output file is given, will remove matches is 2 found, otherwise, will ask permission\n"
    echo "Usage: $0 -options"
    echo "-i \"Input file\""
    echo "-o \"Output file\""
    echo "-a \"Argument to find\""
    echo "-p print all match information"
    echo "-P Pause and verify removal after each match (and print is also enabled)"
}

#**************************************************************************************************************
# Parse argument options
# 1 - the input array
#**************************************************************************************************************
parse_arguments () {
    getopt --test > /dev/null || error_code=$?
    if [[ $error_code -ne 4 ]]; then
        echo "$0 getopt --test failed!"
        exit 1
    fi

    if [ $# -le 0 ]; then
        print_help
        exit 1
    fi

    SHORT="i:o:pPa:"

    error_code=0
    PARSED=$(getopt --options $SHORT --name "$0" -- "$@") || error_code=$?
    if [[ "$error_code" -ne 0 ]]; then
        print_help
        exit 1
    fi

    eval set -- "$PARSED"

    while true; do
        case "$1" in
            -h)
                print_help
                exit
                ;;
            -i)
                SOURCE="$2"
                shift 2
                ;;
            -o)
                TARGET="$2"
                shift 2
                ;;
            -p)
                PRINT=1
                shift 1
                ;;
            -P)
                PAUSE=1
                PRINT=1
                shift 1
                ;;
            -a)
                FIND="$2"
                shift 2
                ;;
            --)
                shift 1
                break
                ;;
            *)
                exit 1
                ;;
        esac
    done
}

#**************************************************************************************************************
# Print end results
#**************************************************************************************************************
printOutput() {
    if [ -f "$TARGET" ]; then
        echo "Removed $REMOVECOUNT rows from $1"
    else
        echo "Found $REMOVECOUNT rows that are declared elsewhere"
    fi
    echo "$SOURCE -> $TARGET"
}

init
parse_arguments "$@"
readFile "$SOURCE"
printOutput "$SOURCE"
