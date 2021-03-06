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
GLOBAL_FILESAVE=0
GLOBAL_TIMESAVE=0
GLOBAL_FILECOUNT=0
TOTAL_FILES=0

##########################################################
# Push string to target file
##########################################################
printShit () {
    echo "$@" >> "$FILE"
}

##########################################################
# End of process output
##########################################################
printSavedData () {
    printShit "ENDSIZE=\`df --output=avail \"\$PWD\" | sed '1d;s/[^0-9]//g'\`"
    printShit "TOTALSIZE=\$((ENDSIZE - STARTSIZE))"
    printShit "TOTALSIZE=\$((TOTALSIZE / 1000))"
    printShit "GLOBAL_FILESAVE=\$((GLOBAL_FILESAVE / 1000))"
    printShit "ENDTIMER=\$(date -d@\${GLOBAL_TIMESAVE} -u +%T)"
    printShit "echo \"Totally saved \$TOTALSIZE Mb (calculated: \$GLOBAL_FILESAVE Mb) and saved time: \$ENDTIMER\" in \$GLOBAL_FILECOUNT files"
    echo " " >> $FILE
}

##########################################################
# When ctrl+c is pressed, use this process
##########################################################
printTerminatorFunction () {
    echo -e "\ncleanup () {" >> "$FILE"
    echo -e "  echo \"Terminated, quitting process!\"" >> "$FILE"
    printSavedData
    echo -e "  exit 1" >> "$FILE" >> "$FILE"
    echo -e "}\n" >> "$FILE"
    echo -e "trap cleanup INT TERM\n" >> "$FILE"
    echo -e "#BEGIN" >> "$FILE"
}

##########################################################
# Check if given input file exists in old file
# 1 - file path
##########################################################
verifyFileNotInList() {
    for i in "${FILE_ARRAY[@]}"
    do
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
    echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $VLC
    echo -e "<playlist xmlns=\"http://xspf.org/ns/0/\" xmlns:vlc=\"http://www.videolan.org/vlc/playlist/ns/0/\" version=\"1\">" >> $VLC
    echo -e "\t<title>Playlist</title>\n\t<trackList>" >> $VLC
}

##########################################################
# Change filename to VLC url encoding
# 1 - filepath
##########################################################
VLC_FILENANE=""

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
    echo -e "\t\t<track>" >> $VLC
    echo -e "\t\t\t<location>${VLC_FILENAME}</location>" >> $VLC
    #echo -e "\t\t\t<title>$1</title>" >> $VLC
    #echo -e "\t\t\t<duration>5000</duration>" >> $VLC
    echo -e "\t\t\t<extension application=\"http://www.videolan.org/vlc/playlist/0\">" >> $VLC
    echo -e "\t\t\t\t<vlc:id>$NEW_FILES</vlc:id>" >> $VLC
    echo -e "\t\t\t</extension>" >> $VLC
    echo -e "\t\t</track>" >> $VLC
}

##########################################################
# Add playlist eof
##########################################################
printVLCEnd() {
    echo -e "\t</trackList>" >> $VLC
    echo -e "\t<extension application=\"http://www.videolan.org/vlc/playlist/0\">" >> $VLC

    for i in `seq 0 $NEW_FILES`
    do
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

    for f in *${EXT}*
    do
        if [ -f "$f" ]; then
            EXT_CURR="${f##*.}"
            if [ "$EXT_CURR" == "part" ] || [ -f "${f}.part" ]; then
                continue
            fi

            if verifyFileNotInList "$f" ; then
                continue
            fi
            X=`mediainfo '--Inform=Video;%Width%' "$f"`
            if [ -z $X ]; then
                X=0
            fi
            if [ $X -le $SIZE ] && [ $IGNORE_SIZE == false ]; then
                echo "PACK \"$f\" $OPTIONS" >> "$TMPFILE"
            elif [ $X -le $SIZE ] && [ $IGNORE_SIZE == true ]; then
                continue
            else
                echo "PACK \"$f\" ${SIZE}x $OPTIONS" >> "$TMPFILE"
            fi
            printVLCFile "$f"
            NEW_FILES=$((NEW_FILES + 1))
            TOTAL_FILES=$((TOTAL_FILES + 1))
            index=$((index + 1))
            if [ $index -ge 11 ]; then
                index=1
                echo " " >> $TMPFILE
            fi
        fi
    done

    shopt -u nocaseglob
    printVLCEnd
}

##########################################################
# If file previously exists, verify existing files,
# remove wanted files and add new files to list
##########################################################
updateExistingFile () {
    STARTSIZE=`df --output=avail "$PWD" | sed '1d;s/[^0-9]//g'`
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
            FOUND=false
            addNewFiles
            echo "$line" >> $TMPFILE
        fi

        if [ $FOUND == false ]; then continue ; fi

        file=`echo "$line" | cut -d'"' -f 2`
        if [ -f "$file" ]; then
            FILE_ARRAY+=("$file")
            if [ "${line:0:4}" == "rm \"" ] || [ "${line:5:4}" == "rm \"" ]; then
                #echo "rm \"$file\""  >> "$TMPFILE"
                #echo "removing $file"
                rm "$file"
                REM_COUNT=$((REM_COUNT + 1))
            else
                echo "$line" >> "$TMPFILE"
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
        ENDSIZE=`df --output=avail "$PWD" | sed '1d;s/[^0-9]//g'`
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
    for var in "$@"
    do
        CNT=$((CNT + 1))
        if [ $CNT == 1 ]; then
            EXT="$var"
        #elif [ $CNT == 2 ]; then
        #    FILE="$var"
        elif [ $var == "-i" ]; then
            IGNORE_SIZE=true
        else
            xss=$(grep -o "x" <<< "$var" | wc -l)
            if [ $xss == "0" ]; then
                OPTIONS+="$var "
            else
                SIZE=`echo $var | cut -d x -f 1`
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

    printShit "STARTSIZE=\`df --output=avail \"\$PWD\" | sed '1d;s/[^0-9]//g'\`"
    printShit "GLOBAL_FILESAVE=0"
    printShit "GLOBAL_TIMESAVE=0"
    printShit "NO_EXIT_EXTERNAL=1"
    printShit "EXIT_EXT_VAL=0"
    printShit "COUNTED_ITEMS=0"
    printShit "ERROR=0"

    printShit ""
    printShit "PACK () {"
    printShit "  INPUTFILE=\"\$1\""
    printShit "  shift 1"
    printShit "  COUNTED_ITEMS=\$((COUNTED_ITEMS + 1))"
    printShit "  if [ \"\$INPUTFILE\" == \"rm\" ]; then"
    printShit "    echo \"\${COUNTED_ITEMS}/\${MAX_ITEMS} :: Removing \$1\""
    printShit "    rm \"\$1\""
    printShit "  elif [ -f \"\$INPUTFILE\" ]; then"
    printShit "    echo -en \"\${COUNTED_ITEMS}/\${MAX_ITEMS} :: \""
    printShit "    . packAll.sh \"\$INPUTFILE\" \$@"
    printShit "    [ \$ERROR -eq 0 ] && ERROR=\$?"
    printShit "  fi"
    printShit "}"

    printTerminatorFunction
}

##########################################################
# Remane all video files to mp4
##########################################################
renameLocalFiles() {
    rename 's/webm/mp4/' *
    rename 's/flv/mp4/' *
    rename 's/mkv/mp4/' *
    rename 's/m4v/mp4/' *
    rename 's/wmv/mp4/' *
}

##########################################################
# Go through all the files in the current directory
##########################################################
goThroughAllFiles() {
    printVLCStart
    index=1
    shopt -s nocaseglob

    for f in *${EXT}*
    do
        if [ -f "$f" ]; then
            EXT_CURR="${f##*.}"
            if [ "$EXT_CURR" == "part" ] || [ -f "${f}.part" ]; then
                continue
            fi

            X=`mediainfo '--Inform=Video;%Width%' "$f"`
            if [ -z $X ]; then
                X=0
            fi
            if [ $X -le $SIZE ] && [ $IGNORE_SIZE == false ]; then
                echo "PACK \"$f\" $OPTIONS" >> "$FILE"
            elif [ $X -le $SIZE ] && [ $IGNORE_SIZE == true ]; then
                continue
            else
                echo "PACK \"$f\" ${SIZE}x $OPTIONS" >> "$FILE"
            fi

            printVLCFile "$f"
            NEW_FILES=$((NEW_FILES + 1))
            TOTAL_FILES=$((TOTAL_FILES + 1))
            index=$((index + 1))
            if [ $index -ge 11 ]; then
                index=1
                echo " " >> $FILE
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
    echo " " >> $FILE
    printShit "if [ \"\$EXIT_EXT_VAL\" -eq \"0\" ] && [ \"\$ERROR\" -eq \"0\" ]; then"
    printShit "  rm $FILE"
    printShit "  rm $VLC"
    printShit "fi"
}

##########################################################
# Rename characters that arent't supported by playlist
##########################################################
renameBadChars() {
    rename "s/™//g" *
    rename "s/'//g" *
    rename "s/’//g" *
    rename "s/%//g" *
    rename "s/@//g" *
    rename "s/–//g" *
    rename "s/🎩//g" *
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
            echo "MAX_ITEMS=$TOTAL_FILES" >> $TMPFILE
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
verifyOldFile
if [ $FILE_UPDATED == false ]; then
    renameBadChars
    printBaseData
    renameLocalFiles
    goThroughAllFiles
    printEndData
    printSavedData
    echo "Added $NEW_FILES files to $FILE"
else
    echo "Added $NEW_FILES new files to $FILE"
fi

updateFileCount

chmod 777 $FILE
