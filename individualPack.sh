#!/bin/bash

OPTIONS=""
CNT=0
EXT="mp4"
FILE="do.sh"
TMPFILE="dotmp.sh"
SIZE=0
IGNORE_SIZE=false
FILE_UPDATED=false
FILE_ARRAY=()
NEW_FILES=0
FOUND=false
VLC="playlist.xspf"
[ -f "$VLC" ] && rm "$VLC"
export GLOBAL_FILESAVE=0
export GLOBAL_TIMESAVE=0
export GLOBAL_FILECOUNT=0
TOTAL_FILES=0
INPUTSTR=""
REN_FILES=0
RENLIST=()
KEEP_PLAYLIST=0
KEPT_FILES=0
LIST_OUTSIDE_FILES=0

##########################################################
# Push string to target file
##########################################################
printToFile () {
    if [ -z "$2" ]; then
        echo "$1" >> "$FILE"
    else
        echo "  $1" >> "$FILE"
    fi
}

##########################################################
# End of process output
##########################################################
printSavedData () {
    printToFile "ENDSIZE=\$(df --output=avail \"\$PWD\" | sed '1d;s/[^0-9]//g')" "$1"
    printToFile "TOTALSIZE=\$((ENDSIZE - STARTSIZE))" "$1"
    printToFile "TOTALSIZE=\$((TOTALSIZE / 1000))" "$1"
    printToFile "GLOBAL_FILESAVE=\$((GLOBAL_FILESAVE / 1000))" "$1"
    printToFile "ENDTIMER=\$(date -d@\${GLOBAL_TIMESAVE} -u +%T)" "$1"
    printToFile "SET=\$(date +%s)" "$1"
    printToFile "STT=\$((SET - STT))" "$1"

    printToFile "echo \"Totally saved \$TOTALSIZE Mb (calculated: \$GLOBAL_FILESAVE Mb) and saved time:\$ENDTIMER in \$GLOBAL_FILECOUNT files time:\$(date -d@\${STT} -u +%T)\"" "$1"
    echo "" >> $FILE
}

##########################################################
# When ctrl+c is pressed, use this process
##########################################################
printTerminatorFunction () {
    {
        echo -e "\ncleanup () {"
        echo -e "  printf \"\\nTerminated do.sh, quitting process!\\n\""
        printSavedData "1"
        echo -e "  exit 1"
        echo -e "}\n"
        echo -e "#BEGIN"
    } >> $FILE
}

##########################################################
# Check if given input file exists in old file
# 1 - file path
##########################################################
verifyFileNotInList() {
    for i in "${FILE_ARRAY[@]}"; do
        if [ "$i" == "$1" ]; then
            return 0
        fi
    done
    return 1
}

##########################################################
# VLC playlist start information
##########################################################
printVLCStart() {
    if [ ! -f "$VLC" ]; then
        echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $VLC
        echo -e "<playlist xmlns=\"http://xspf.org/ns/0/\" xmlns:vlc=\"http://www.videolan.org/vlc/playlist/ns/0/\" version=\"1\">" >> $VLC
        echo -e "\t<title>Playlist</title>\n\t<trackList>" >> $VLC
    fi
}

##########################################################
# Change filename to VLC url encoding
# 1 - filepath
##########################################################
VLC_FILENAME=""

rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  #echo "${encoded}"    # You can either set a return variable (FASTER)
  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
  VLC_FILENAME="${encoded}"
}

##########################################################
# Add file to VLC playlist
# 1 - filepath
##########################################################
printVLCFile() {
    rawurlencode "$1"
    RUNID=$((NEW_FILES + KEPT_FILES))
    {
        echo -e "\t\t<track>"
        echo -e "\t\t\t<location>${VLC_FILENAME}</location>"
        #echo -e "\t\t\t<title>$1</title>"
        #echo -e "\t\t\t<duration>5000</duration>"
        echo -e "\t\t\t<extension application=\"http://www.videolan.org/vlc/playlist/0\">"
        echo -e "\t\t\t\t<vlc:id>$RUNID</vlc:id>"
        echo -e "\t\t\t</extension>"
        echo -e "\t\t</track>"
    } >> $VLC
}

##########################################################
# Add playlist eof
##########################################################
printVLCEnd() {
    echo -e "\t</trackList>" >> $VLC
    echo -e "\t<extension application=\"http://www.videolan.org/vlc/playlist/0\">" >> $VLC

    for i in $(seq 0 $NEW_FILES); do
        echo -e "\t\t<vlc:item tid=\"$i\"/>" >> $VLC
    done
    echo -e "\t</extension>" >> $VLC
    echo -e "</playlist>" >> $VLC
}

##########################################################
# Add new files to an existing editlist
##########################################################
addNewFiles() {
    echo -e "\n#NEW" >> $TMPFILE
    index=1
    printVLCStart
    shopt -s nocaseglob

    for f in *"${EXT}"* ; do
        if [ -f "$f" ]; then
            EXT_CURR="${f##*.}"
            if [ "$EXT_CURR" == "part" ] || [ -f "${f}.part" ]; then
                continue
            fi

            if verifyFileNotInList "$f" ; then continue; fi
            INTEGRITY=$(ffmpeg -i "$f" 2>&1)
            if [[ "$INTEGRITY" == *"Invalid data found when processing input"* ]]; then
                printf "Something wrong with '%s' (add new)\n" "$f"
                continue
            fi
            X=$(mediainfo '--Inform=Video;%Width%' "$f")
            [ -z "$X" ] && X=0
            [ "$SIZE" == "0" ] && SIZE="10000"

            if [ $X -le $SIZE ] && [ $IGNORE_SIZE == false ]; then
                echo "PACK \"$f\"$OPTIONS" >> "$TMPFILE"
            elif [ $X -le $SIZE ] && [ $IGNORE_SIZE == true ]; then
                continue
            else
                echo "PACK \"$f\" ${SIZE}x$OPTIONS" >> "$TMPFILE"
            fi
            printVLCFile "$f"
            NEW_FILES=$((NEW_FILES + 1))
            TOTAL_FILES=$((TOTAL_FILES + 1))
            index=$((index + 1))
            if [ $index -ge 11 ]; then
                index=1
                echo "" >> $TMPFILE
            fi
        fi
    done

    shopt -u nocaseglob
    printVLCEnd
}

##########################################################
# clear all unknown chars from filename, quite messy
# 1 - filename
##########################################################
renfile() {
    GUNTHER=1
    CLEARNAME=$(echo "$1" | uconv -x "::Latin; ::Latin-ASCII; ([^\x00-\x7F]) > ;")
    #CLEARNAME=$(echo "$1" | tr -dc '[:alnum:]\n\r ' | tr '[:upper:]' '[:lower:]')
    [[ "$1" == *".mp4" ]] && CLEARNAME="${CLEARNAME/.mp4/}"
    [[ "$CLEARNAME" =~ "_1" ]] && CLEARNAME="${CLEARNAME/_1/}"

    if [ "$1" != "$CLEARNAME" ] && [ "$1" != "${CLEARNAME}.mp4" ]; then
        if [ -f "$CLEARNAME" ] || [ -f "${CLEARNAME}.mp4" ]; then
            CLEARNAME="${CLEARNAME}_$GUNTHER"

            while [ -f "$CLEARNAME" ] || [ -f "${CLEARNAME}.mp4" ]; do
                GUNTHER=$((GUNTHER + 1))
                CLEARNAME="${CLEARNAME}_$GUNTHER"
            done
        fi
    fi

    [[ "$1" == *".mp4" ]] && CLEARNAME="${CLEARNAME}.mp4"
    [ "$1" != "$CLEARNAME" ] && mv "$1" "$CLEARNAME"
}

##########################################################
# If file previously exists, verify existing files,
# remove wanted files and add new files to list
##########################################################
updateExistingFile () {
    STARTSIZE=$(df --output=avail "$PWD" | sed '1d;s/[^0-9]//g')
    REM_COUNT=0
    LOOP_COUNT=0
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [ $FOUND == false ]; then
            echo "$line" >> $TMPFILE
        fi

        if [[ $line =~ "#BEGIN" ]]; then
            FOUND=true
            continue
        fi

        if [[ $line =~ "#END" ]]; then
            if [ "$REN_FILES" -gt "0" ]; then
                echo -e "\n#RENAMED" >> $TMPFILE
                printVLCStart
                for index in "${RENLIST[@]}"; do
                    echo "PACK \"$index\" $OPTIONS" >> "$TMPFILE"
                    printVLCFile "$index"
                    NEW_FILES=$((NEW_FILES + 1))
                    TOTAL_FILES=$((TOTAL_FILES + 1))
                    LOOP_COUNT=$((LOOP_COUNT + 1))
                done
            fi
            FOUND=false
            addNewFiles
            echo "$line" >> $TMPFILE
        fi

        if [ $FOUND == false ]; then continue ; fi

        file=$(echo "$line" | cut -d'"' -f 2)
        if [ -f "$file" ]; then
            FILE_ARRAY+=("$file")
            if [ "${line:0:4}" == "rm \"" ] || [ "${line:5:4}" == "rm \"" ]; then
                #echo "rm \"$file\""  >> "$TMPFILE"
                #echo "removing $file"
                rm "$file"
                REM_COUNT=$((REM_COUNT + 1))
            elif [ "${line:0:4}" == "mv \"" ] || [ "${line:5:4}" == "mv \"" ]; then
                renfile "$file"
                RENLIST+=("$CLEARNAME")
                FILE_ARRAY+=("$CLEARNAME")
                REN_FILES=$((REN_FILES + 1))
            else
                echo "$line" >> "$TMPFILE"

                if [ "$KEEP_PLAYLIST" == "1" ]; then
                    printVLCStart
                    printVLCFile "$file"
                    KEPT_FILES=$((KEPT_FILES + 1))
                fi
                TOTAL_FILES=$((TOTAL_FILES + 1))
                LOOP_COUNT=$((LOOP_COUNT + 1))
                if [ "$LOOP_COUNT" -ge "9" ]; then
                    printf "\n" >> $TMPFILE
                    LOOP_COUNT=0
                fi
            fi
        fi
    done < "$FILE"

    rm "$FILE"
    mv "$TMPFILE" "$FILE"

    if [ $REM_COUNT -gt 0 ]; then
        ENDSIZE=$(df --output=avail "$PWD" | sed '1d;s/[^0-9]//g')
        TOTALSIZE=$((ENDSIZE - STARTSIZE))
        TOTALSIZE=$((TOTALSIZE / 1000))
        echo "Removed $REM_COUNT files worth of $TOTALSIZE Mb"
    fi
}

##########################################################
# Parse individual line settings from input
# 1 - the whole array of data variables
##########################################################
parsePackData() {
    INPUTCOUNT=1
    re='^[0-9X]+$'

    for var in "$@"; do
        CNT=$((CNT + 1))
        if [ "$CNT" == 1 ]; then
            EXT="$var"
        #elif [ $CNT == 2 ]; then
        #    FILE="$var"
        elif [ "$var" == "-i" ]; then
            IGNORE_SIZE=true
        elif [ "$var" == "list" ]; then
            LIST_OUTSIDE_FILES=1
        elif [[ "$var" =~ $re ]]; then
            #xss=$(grep -o "x" <<< "$var" | wc -l)
            SIZE=$(echo "$var" | cut -d x -f 1)
            [ -z "$SIZE" ] && IGNORE_SIZE=true
        else
            INPUTSTR+=" \"\$${INPUTCOUNT}\""
            INPUTCOUNT=$((INPUTCOUNT + 1))
            if [ "$var" == "keep" ]; then
                KEEP_PLAYLIST=1
            else
                OPTIONS+=" $var"
            fi
        fi
    done
}

##########################################################
# Verify if file exists
##########################################################
verifyOldFile() {
    if [ -f "$FILE" ]; then
        updateExistingFile
        FILE_UPDATED=true
    fi
}

##########################################################
# Print bash script base data
##########################################################
printBaseData() {
    echo "#!/bin/bash" > $FILE

    printToFile "STARTSIZE=\$(df --output=avail \"\$PWD\" | sed '1d;s/[^0-9]//g')"
    printToFile "export GLOBAL_FILESAVE=0"
    printToFile "export GLOBAL_TIMESAVE=0"
    printToFile "export NO_EXIT_EXTERNAL=1"
    printToFile "export EXIT_EXT_VAL=0"
    printToFile "export EXTERNAL_CALL=1"
    printToFile "export ERROR=0"
    printToFile "export PROCESS_INTERRUPTED=0"
    printToFile "export COUNTED_ITEMS=0"
    printToFile "ERROR_CNT=0"
    printToFile "STT=\$(date +%s)"

    printToFile ""
    printToFile "PACK () {"
    printToFile "  PLEN=\"\${#MAX_ITEMS}\""
    printToFile "  INPUTFILE=\"\$1\""
    printToFile "  shift 1"
    printToFile "  FILENAME=\${INPUTFILE%.*}"
    printToFile "  [ -f \"\${FILENAME}.mp4\" ] && INPUTFILE=\"\${FILENAME}.mp4\""
    printToFile "  COUNTED_ITEMS=\$((COUNTED_ITEMS + 1))"
    printToFile "  if [ \"\$INPUTFILE\" == \"rm\" ]; then"
    printToFile "    [ ! -f \"\$1\" ] && return 0"
    printToFile "    printf \"\\n%0\${PLEN}d/%0\${PLEN}d \$(date +%T): Removing %s\\n\" \"\${COUNTED_ITEMS}\" \"\${MAX_ITEMS}\" \"\$1\""
    printToFile "    REMFSAVE=\$(du -k \"\$1\" | cut -f1)"
    printToFile "    export GLOBAL_FILESAVE=\$((GLOBAL_FILESAVE + REMFSAVE))"
    printToFile "    rm \"\$1\""
    printToFile "  elif [ \"\$INPUTFILE\" == \"mv\" ]; then"
    printToFile "    [ ! -f \"\$1\" ] && return 0"
    printToFile "    CLEARNAME=\$(echo \"\$1\" | tr -dc '[:alnum:]\n\r' | tr '[:upper:]' '[:lower:]')"
    printToFile "    printf \"\\n%0\${PLEN}d/%0\${PLEN}d \$(date +%T): Renaming '%s' to '\$CLEARNAME'\\n\" \"\${COUNTED_ITEMS}\" \"\${MAX_ITEMS}\" \"\$1\""
    printToFile "    mv \"\$1\" \"\${CLEARNAME}.mp4\""
    printToFile "  elif [ -f \"\$INPUTFILE\" ]; then"
    printToFile "    . packAll.sh \"\$INPUTFILE\" \"\$@\""
    printToFile "    if [ \$ERROR -ne 0 ]; then ERROR_CNT=\$((ERROR_CNT + 1)); fi"
    printToFile "    ERROR=0"
    printToFile "  fi"
    printToFile "  [ \"\$PROCESS_INTERRUPTED\" -ne \"0\" ] && cleanup"
    printToFile "}"

    printTerminatorFunction
}

##########################################################
# Remane all video files to mp4
##########################################################
renameLocalFiles() {
    rename 's/webm/mp4/' ./*
    rename 's/flv/mp4/' ./*
    rename 's/mkv/mp4/' ./*
    rename 's/m4v/mp4/' ./*
    rename 's/wmv/mp4/' ./*
}

##########################################################
# Go through all the files in the current directory
##########################################################
goThroughAllFiles() {
    printVLCStart
    index=1
    shopt -s nocaseglob

    for f in *"${EXT}"*; do
        if [ -f "$f" ]; then
            EXT_CURR="${f##*.}"
            if [ "$EXT_CURR" == "part" ] || [ -f "${f}.part" ]; then
                continue
            fi

            renfile "$f"

            INTEGRITY=$(ffmpeg -i "$f" 2>&1)
            if [[ "$INTEGRITY" == *"Invalid data found when processing input"* ]]; then
                printf "Something wrong with '%s' (go through all)\n" "$f"
                continue
            fi
            X=$(mediainfo '--Inform=Video;%Width%' "$f")
            X=$(mediainfo '--Inform=Video;%Width%' "$CLEARNAME")
            [ -z "$X" ] && X=0
            [ "$SIZE" == "0" ] && SIZE="10000"

            if [ $X -le $SIZE ] && [ $IGNORE_SIZE == false ]; then
                echo "PACK \"$CLEARNAME\"$OPTIONS" >> "$FILE"
            elif [ $X -le $SIZE ] && [ $IGNORE_SIZE == true ]; then
                continue
            elif [ $SIZE == 0 ]; then
                echo "PACK \"$CLEARNAME\" $OPTIONS" >> "$FILE"
            else
                echo "PACK \"$CLEARNAME\" ${SIZE}x$OPTIONS" >> "$FILE"
            fi

            printVLCFile "$CLEARNAME"
            NEW_FILES=$((NEW_FILES + 1))
            TOTAL_FILES=$((TOTAL_FILES + 1))
            index=$((index + 1))
            if [ $index -ge 11 ]; then
                index=1
                echo "" >> $FILE
            fi
        fi
    done

    shopt -u nocaseglob
    printVLCEnd
}

##########################################################
# Print bash eof data
##########################################################
printEndData() {
    echo "#END" >> $FILE
    echo "" >> $FILE
    printToFile "if [ \"\$EXIT_EXT_VAL\" -eq \"0\" ] && [ \"\$ERROR_CNT\" -eq \"0\" ]; then"
    printToFile "  rm $FILE"
    printToFile "  rm $VLC"
    printToFile "fi"
}

##########################################################
# Rename characters that arent't supported by playlist
##########################################################
renameBadChars() {
    for f in *"${EXT}"* ; do
        [ -d "$f" ] && continue
        rename "s/'//g" "./$f"
        rename "s/’//g" "./$f"
        rename "s/%//g" "./$f"
        rename "s/@//g" "./$f"
        rename "s/–//g" "./$f"
        rename "s/-//g" "./$f"
    done
}

##########################################################
# Update max filecount to the script
##########################################################
updateFileCount() {
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [[ $line =~ "MAX_ITEMS=" ]]; then
            continue
        fi

        if [[ $line =~ "#BEGIN" ]]; then
            echo "export MAX_ITEMS=$TOTAL_FILES" >> $TMPFILE
        fi

        echo "$line" >> $TMPFILE
    done < "$FILE"

    rm "$FILE"
    mv "$TMPFILE" "$FILE"
}

##########################################################
# Main functionality
##########################################################
parsePackData "$@"
if [ "$LIST_OUTSIDE_FILES" == "1" ]; then
    for f in *"${EXT}"*; do
        CHECK=$(grep "$f" "$FILE")
        [ -z "$CHECK" ] && printf "%s\n" "$f"
    done

    exit 0
fi

verifyOldFile
if [ $FILE_UPDATED == false ]; then
    renameBadChars
    printBaseData
    #renameLocalFiles
    goThroughAllFiles
    printEndData
    printSavedData
    echo "Added $NEW_FILES files to $FILE, renamed $REN_FILES, kept $KEPT_FILES"
else
    echo "Added $NEW_FILES new files to $FILE, renamed $REN_FILES, kept $KEPT_FILES"
fi

updateFileCount

chmod 777 $FILE
