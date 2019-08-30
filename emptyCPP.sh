#!/bin/bash

# Create fast empty header and cpp files with basic info

# $1 - filename
# $2 - extra include header name

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
        echo " * Copyright of INSERT INFO. All rights reserved."
        echo " *"
        echo " * \\author INSER NAME <INSERT EMAIL>"
        echo " *"
        echo " * any other legal text to be defined later"
        echo -e " */\n"
    } > "$1"
}

if [ ! -z "$1" ]; then
    if [ -f "$1.cpp" ] || [ -f "$1.h" ]; then
        echo "File $1 already exists, aborting!"
    else
        header_print "$1.cpp"
        echo -e "#include \"$1.h\"\n\n" >> "$1.cpp"

        header_print "$1.h" "$2"
        UPPER=$(echo "$1" |awk '{print toupper($0)}')
        {
            echo "#ifndef __${UPPER}_H__"
            echo -e "#define __${UPPER}_H__\n"
            [ ! -z "$2" ] && echo -e "#include \"$2\"\n\n"
            echo -n "#endif /* __${UPPER}_H__ */"
        } >> "$1.h"
    fi
else
    echo "No filename given!"
fi

