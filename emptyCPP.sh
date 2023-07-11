#!/bin/bash

EXT="cpp"
USER=""
SOURCES=""
FILENAME=""
OWNER=$(whoami)
DATE_NOW=$(date +%F)
SKIP_FILE=0

print_help() {
    echo "Create empty $EXT/h -files with basic information"
    echo "-h - for this"
    echo "-f - filename (works also without prefix)"
    echo "-e - source file extension (default $EXT)"
    echo "-H - extra include header (can be repeated)"
    echo "-a - add author to header"
    echo "-o - owner of the files"
    echo "-O - create only header file"
    echo "-S - create only source file"
    exit
}

##################################################
# Print file header info to file
##################################################
header_print() {
    if [ -z "$1" ]; then
        echo "No output file given! Aborting!"
        exit 1
    fi
    {
        echo "/*!"
        echo " * \\file"
        echo " * \\brief $1 foo"
        echo " *"
        echo " * Copyright of $OWNER All rights reserved."
        echo " *"
        if [ ! -z "$USER" ]; then
            echo " * \\author $USER"
            echo " *"
        fi
        echo " * any other legal text to be defined later"
        echo " *"
        echo " * \\created $DATE_NOW"
        echo -e " */\n"
    } > "$1"
}

##################################################
# Parse Commandline arguments
##################################################
parse_arguments () {
    getopt --test > /dev/null || error_code=$?
    if [[ $error_code -ne 4 ]]; then
        echo "$0 getopt --test failed!"
        exit 1
    fi

    SHORT="hf:e:H:a:o:OS"

    PARSED=$(getopt --options $SHORT --name "$0" -- "$@")
    if [[ $? -ne 0 ]]; then
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
            -f)
                FILENAME="$2"
                shift 2
                ;;
            -e)
                EXT="$2"
                shift 2
                ;;
            -H)
                SOURCES+="$2 "
                shift 2
                ;;
            -a)
                USER="$2"
                shift 2
                ;;
            -o)
                OWNER="$2"
                shift 2
                ;;
            -O)
                SKIP_FILE=1
                shift
                ;;
            -S)
                SKIP_FILE=2
                shift
                ;;
            --)
                [ -z "$FILENAME" ] && [ ! -z "$2" ] && FILENAME="$2"
                break
                ;;
            *)
                exit 1
                ;;
        esac
    done
}

parse_arguments "$@"

##################################################
# Main (create files with wantd information)
##################################################
if [ ! -z "$FILENAME" ]; then
    if [ -f "$FILENAME.$EXT" ] || [ -f "$1.h" ]; then
        echo "File $FILENAME already exists, aborting!"
    else
        if [ "$SKIP_FILE" -ne 1 ]; then
            header_print "$FILENAME.$EXT"
            [ "$SKIP_FILE" -ne 2 ] && echo -e "#include \"$FILENAME.h\"\n\n" >> "$FILENAME.$EXT"
        fi

        if [ "$SKIP_FILE" -ne 2 ]; then
            header_print "$FILENAME.h"
            UPPER=$(echo "$FILENAME" |awk '{print toupper($0)}')
            {
                echo "#ifndef __${UPPER}_H__"
                echo -e "#define __${UPPER}_H__\n"
                if [ ! -z "$SOURCES" ]; then
                    IFS=" "
                    array=(${SOURCES//,/$IFS})
                    for index in "${!array[@]}"
                    do
                        echo -e "#include \"${array[index]}\""
                    done
                    echo -e "\n"
                fi
                echo -n "#endif /* __${UPPER}_H__ */"
            } >> "$FILENAME.h"
        fi
    fi
else
    echo "No filename given!"
fi

