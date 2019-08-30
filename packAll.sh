#!/bin/bash

SYS_INTERRUPT=0
HEVC_CONV=0
SCRUB=0

WORKMODE=4
BEGTIME=0
ENDTIME=0
DURATION_TIME=0
TOTALSAVE=0

FILECOUNT=0
MULTIFILECOUNT=0
MISSING=0
CURRENTFILECOUNTER=0
SUCCESFULFILECNT=0

COPY_ONLY=1
EXT_CURR=""
CONV_TYPE=".mp4"
CONV_CHECK="mp4"
MP3OUT=0

TIMERSTART=0
TIMEREND=0
CALCTIME=0
TIMERTOTAL=0
TIMERVALUE=0
REPACK=0
IGNORE=0
TIMESAVED=0

CHECKRUN=0
CONTINUE_PROCESS=0

WIDTH=0
HEIGHT=0

SKIP=0
SKIPBEG=0
SKIPEND=0
KEEPORG=0
SPLIT_FILE=0

CROP=0

PACKSIZE=""
ORIGINAL_DURATION=0
NEW_DURATION=0
NEW_FILESIZE=0
ORIGINAL_SIZE=0

PRINT_ALL=0
PRINT_INFO=0
SEGMENT_PARSING=""

DEBUG_PRINT=0
MASSIVE_SPLIT=0

MASSIVE_TIME_CHECK=0
MASSIVE_TIME_COMP=0
SPLIT_MAX=0

SUBFILE=""
EXTRASETTINGS=""
WRITEOUT=""
NEWNAME=""

FILES_MISSING=false

#If SYS_INTERRUPTrupted, make sure no external compressions are continued
set_int () {
    SYS_INTERRUPT=1
    echo " Main conversion interrupted!"
}

trap set_int SIGINT SIGTERM

#**************************************************************************************************************
print_help () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "print_help"
    fi
    echo "No input file! first input is always filename (filename, file type or part of filename)"
    echo " "
    echo "To set dimensions NxM (where N is width, M is height, height is automatically calculated to retain aspect ratio)"
    echo " "
    echo "b(eg)=        -    time to remove from beginning (either seconds or X:Y:Z)"
    echo "e(nd)=        -    time to remove from end (calculated from the end) (either seconds or X:Y:Z)"
    echo "d(uration)=    -    Time from the beginning X:Y:Z, to skip the end after that"
    echo "t(arget)=        -    filetype to set destination filetype (mp4 as default)"
    echo " "
    echo "i(gnore)        -    to ignore size"
    echo "r(epack)        -    to repack file with original dimensions"
    echo "k(eep)        -    to keep the original file after succesful conversion"
    echo "m(p3)        -    to extract mp3 from the file"
    echo "a(ll)        -    print all information"
    echo "p(rint)        -    print only file information (if set as 1, will print everything, 2 = lessthan, 3=biggerthan, 4=else )"
    echo "h(evc)        -    convert with ffmpeg instead of avconv"
    echo "s(crub)        -    original on completion"
    echo "crop         -    crop black borders"
    echo " "
    echo "sub=        -    subtitle file to be burned into video"
    echo "w(rite)=        -    Write printing output to file"
    echo "n(ame)=        -    Give file a new target name (without file extension"
    echo " "
    echo "c(ut)=        -    time where to cut|time where to cut next piece|next piece|etc"
    echo "c(ut)=        -    time to begin - time to end|next time to begin-time to end|etc"
    echo "s(kip)=        -    time to skip|duration (in secs) Requires MP4Box installed (and doesn't work really good)"
    echo " "
    echo "example:    packAll.sh "FILENAME" 640x h b=1:33"
    echo "Requires mediainfo installed!"
}

#**************************************************************************************************************
# Crop out black borders
check_and_crop () {
    CROP_DATA=`ffmpeg -i "$FILE" -t 1 -vf cropdetect -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1`
    if [ ! -z $CROP_DATA ]; then
        XC=`mediainfo '--Inform=Video;%Width%' "$FILE"`
        YC=`mediainfo '--Inform=Video;%Height%' "$FILE"`

        if [ ! -z $XC ] && [ ! -z $YC ]; then
            CB=`echo $CROP_DATA | cut -d = -f 2`
            C1=`echo $CB | cut -d : -f 1`
            C2=`echo $CB | cut -d : -f 2`
            C3=`echo $CB | cut -d : -f 3`
            C4=`echo $CB | cut -d : -f 4`
            if [ $C1 -ge "0" ] && [ $C2 -ge "0" ]; then
                if [ $XC -ne $C1 ] || [ $YC -ne $C2 ] || [ $C3 -gt "0" ] || [ $C4 -gt "0" ]; then
                    print_info
                    short_name
                    echo -n -e "$FILEprint Cropping black borders ->($CROP_DATA) \t"
                    ffmpeg -i "$FILE" -vf "$CROP_DATA" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
                    calculate_duration
                    check_file_conversion
                fi
            fi
        fi
    fi
}

#**************************************************************************************************************
# Check WORKMODE for removing time data
check_workmode () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "check_workmode"
    fi
    if [ $BEGTIME != "D" ]; then
        if [ $BEGTIME -gt 0 ] && [ $ENDTIME -gt 0 ]; then
            WORKMODE=3
        elif [ $BEGTIME -gt 0 ] && [ $DURATION_TIME -gt 0 ]; then
            WORKMODE=3
        elif [ $BEGTIME -gt 0 ]; then
            WORKMODE=1
        elif [ $ENDTIME -gt 0 ] || [ $DURATION_TIME -gt 0 ]; then
            WORKMODE=2
        fi
    fi
}

#***************************************************************************************************************
# Check if given value starts with a 0 and remove it
check_zero () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "change_zero"
    fi
    ZERORETVAL="$1"
    ttime="${1:0:1}"
    if [ ! -z $ttime ]; then
        if [ $ttime == "0" ]; then
            ZERORETVAL="${1:1:1}"
        fi
    fi
}

#**************************************************************************************************************
delete_file () {
    if [ -f "$1" ]; then
        if [ $SCRUB == "1" ]; then
            scrub -r "$1" >/dev/null 2>&1
        elif [ $SCRUB == "2" ]; then
            scrub -r "$1"
        else
            rm "$1"
        fi
    fi
}

#**************************************************************************************************************
# Check that the timelength matches with the destination files from splitting
ERROR_WHILE_SPLITTING=0
massive_filecheck () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "massive_filecheck"
    fi

    if [ $ERROR_WHILE_SPLITTING != "0" ]; then
        Color.sh red
        echo "Something went wrong with splitting $FILE"
        Color.sh
        ERROR_WHILE_SPLITTING=0
        return 0;
    fi

    MASSIVE_TIME_COMP=0
    RUNNING_FILE_NUMBER=0
    MASSIVE_SIZE_COMP=0
    while [ $RUNNING_FILE_NUMBER -lt $SPLIT_MAX ]; do
        RUNNING_FILE_NUMBER=$((RUNNING_FILE_NUMBER + 1))
        make_running_name
        if [ -f "$RUNNING_FILENAME" ]; then
            CFT=`mediainfo '--Inform=Video;%Duration%' "$RUNNING_FILENAME"`
            MASSIVE_TIME_COMP=$((MASSIVE_TIME_COMP + CFT))
            MSC=`du -k "$RUNNING_FILENAME" | cut -f1`
            MASSIVE_SIZE_COMP=$((MASSIVE_SIZE_COMP + MSC))
        else
            break
        fi
    done

    if [ $MASSIVE_TIME_COMP -ge $MASSIVE_TIME_CHECK ]; then
        OSZ=`du -k "$FILE" | cut -f1`
        delete_file "$FILE"
        OSZ=$(((OSZ - MASSIVE_SIZE_COMP) / 1000))
        Color.sh green
        echo "Saved $OSZ Mb with splitting"
        Color.sh

    else
        Color.sh red
        echo "Something wrong with cut-out time ($MASSIVE_TIME_COMP < $MASSIVE_TIME_CHECK)"
        Color.sh
    fi
}

#**************************************************************************************************************
# Split file into chunks given by input parameters, either (start-end|start-end|...) or (point|point|point|...)
massive_split_into () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "massive_split_into"
    fi
#    if [ -f $FILE ]; then
        MASSIVE_TIME_CHECK=0
        SPLIT_FILE=0
        SPLIT_COUNTER=0
        SPLIT_MAX=$(grep -o "|" <<< "$1" | wc -l)
        SPLIT_MAX=$((SPLIT_MAX + 1))

        KEEPORG=1
        FILECOUNT=1
        MASSIVE_SPLIT=1

        EXT_CURR="${FILE##*.}"
        #COPY_ONLY=1
        LEN=`mediainfo '--Inform=Video;%Duration%' "$FILE"`
        XSS=`mediainfo '--Inform=Video;%Width%' "$FILE"`
        LEN=$((LEN / 1000))
        SPLIT_P2P=$(grep -o "-" <<< "$1" | wc -l)
        while [ $SPLIT_COUNTER -lt $SPLIT_MAX ]; do
            SPLIT_COUNTER=$((SPLIT_COUNTER + 1))
            SPLIT_POINT=`echo $1 | cut -d "|" -f $SPLIT_COUNTER`
            if [ $SPLIT_P2P -gt 0 ]; then
                BEGTIME=`echo $SPLIT_POINT | cut -d "-" -f 1`
                if [ $BEGTIME != "D" ]; then
                    calculate_time $BEGTIME
                    BEGTIME=$CALCTIME
                    ENDTIME=`echo $SPLIT_POINT | cut -d "-" -f 2`
                    calculate_time $ENDTIME
                    ENDTIME=$CALCTIME
                    if [ $ENDTIME -le $BEGTIME ] && [ $ENDTIME != "0" ] || [ $WIDTH -ge $XSS ]; then
                        ERROR_WHILE_SPLITTING=1
                        Color.sh red
                        echo "Split error $FILE - Time: $ENDTIME <= $BEGTIME, Size: $WIDTH >= $XSS"
                        Color.sh
                    else
                        if [ $CALCTIME != "0" ]; then
                            ENDTIME=$((LEN - CALCTIME))
                        fi
                        check_workmode
                        pack_file
                        MASSIVE_TIME_CHECK=$((MASSIVE_TIME_CHECK + (ENDTIME - BEGTIME)))
                    fi
                else
                    BEGTIME=0
                    massive_filecheck
                fi
            elif [ $SPLIT_POINT == "D" ]; then
                massive_filecheck
            elif [ ! -z $SPLIT_POINT ]; then
                SPLIT_POINT2=`echo $1 | cut -d "|" -f $((SPLIT_COUNTER + 1))`
                calculate_time $SPLIT_POINT
                SPLIT_POINT=$CALCTIME
                calculate_time $SPLIT_POINT2
                SPLIT_POINT2=$CALCTIME
                if [ $SPLIT_POINT2 -le  $SPLIT_POINT ] || [ $WIDTH -le $XSS ]; then
                    ERROR_WHILE_SPLITTING=1
                    Color.sh red
                    echo "Split error $FILE - Time: $SPLIT_POINT2 <= $SPLIT_POINT, - Size: $WIDTH <= $XSS"
                    Color.sh
                else
                    if [ $SPLIT_COUNTER == 1 ]; then
                        BEGTIME=0
                        ENDTIME=$((LEN - SPLIT_POINT))
                        check_workmode
                        pack_file
                        MASSIVE_TIME_CHECK=$((MASSIVE_TIME_CHECK + (ENDTIME - BEGTIME)))
                        BEGTIME=$SPLIT_POINT
                        if [ $SPLIT_MAX == 1 ]; then
                            ENDTIME=0
                        else
                            ENDTIME=$((LEN - $SPLIT_POINT2E))
                        fi
                    elif [ -z $SPLIT_POINT2 ]; then
                        BEGTIME=$SPLIT_POINT
                        ENDTIME=0
                    else
                        BEGTIME=$SPLIT_POINT
                        ENDTIME=$((LEN - SPLIT_POINT2))
                    fi
                    check_workmode
                    pack_file
                    MASSIVE_TIME_CHECK=$((MASSIVE_TIME_CHECK + (ENDTIME - BEGTIME)))
                    BEGTIME=$SPLIT_POINT
                fi
            fi
        done
        CONTINUE_PROCESS=0
#    else
#        echo "Cannot split multiple files ($FILE)!"
#    fi
}

#***************************************************************************************************************
#Separate and calculate given time into seconds and set to corresponting placeholder
calculate_time () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "calculate_time"
    fi
    if [ ! -z $1 ]; then
        t1=`echo $1 | cut -d : -f 1`
        t2=`echo $1 | cut -d : -f 2`
        t3=`echo $1 | cut -d : -f 3`

        occ=$(grep -o ":" <<< "$1" | wc -l)

        check_zero $t1
        t1=$ZERORETVAL
        check_zero $t2
        t2=$ZERORETVAL
        check_zero $t3
        t3=$ZERORETVAL

        if [ $occ == "0" ]; then
            calc_time=$1
        elif [ $occ == "1" ]; then
            t1=$((t1 * 60))
            calc_time=$((t1 + t2))
        else
            t1=$((t1 * 3600))
            t2=$((t2 * 60))
            calc_time=$((t1 + t2 + t3))
        fi

        CALCTIME=$calc_time
    else
        CALCTIME=0
    fi
}

#**************************************************************************************************************
# Parse special handlers
parse_handlers () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "parse_handlers"
    fi

    if [ ! -z "$1" ]; then
        if [ $1 == "repack" ] || [ $1 == "r" ]; then
            REPACK=1
            COPY_ONLY=0
        elif [ $1 == "ignore" ] || [ $1 == "i" ]; then
            IGNORE=1
        elif [ $1 == "keep" ] || [ $1 == "k" ]; then
            KEEPORG=1
        elif [ $1 == "mp3" ] || [ $1 == "m" ]; then
            MP3OUT=1
            CONV_TYPE=".mp3"
        elif [ $1 == "all" ] || [ $1 == "a" ]; then
            PRINT_ALL=1
        elif [ $1 == "crop" ] || [ $1 == "s" ]; then
            CROP=1
        elif [ $1 == "scrub" ] || [ $1 == "s" ]; then
            SCRUB=1
        elif [ $1 == "print" ] || [ $1 == "p" ]; then
            PRINT_INFO=1
        elif [ $1 == "hevc" ] || [ $1 == "h" ]; then
            IGNORE=1
            HEVC_CONV=1
        elif [ $1 == "D" ]; then
            DEBUG_PRINT=1
        else
            echo "Unknown handler $1"
        fi
    fi
}

#**************************************************************************************************************
SR=1
parse_segdata () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "parse_segdata"
    fi
    #SEGMENT_PARSING
    SKIPBEG=`echo $1 | cut -d "|" -f 1`
    SKIPEND=`echo $1 | cut -d "|" -f 2`
    occ=$(grep -o "|" <<< "$1" | wc -l)

    if [ $occ -gt 0 ]; then
        calculate_time $SKIPBEG
        SKIPBEG=$CALCTIME
        calculate_time $SKIPEND
        SKIPEND=$CALCTIME
        SKIPEND=$((SKIPEND - SKIPBEG))

        SEGMENT_PARSING+="[0:v]trim=start=$SKIPBEG:end=$SKIPEND,setpts=PTS-STARTPTS[v$SR];"
        SEGMENT_PARSING+="[0:a]atrim=start=$SKIPBEG:end=$SKIPEND,asetpts=PTS-STARTPTS[a$SR];"
        SEGMENT_PARSING+="["
    fi

}

#**************************************************************************************************************
parse_skipdata () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "parse_skipdata"
    fi
    if [ ! -z "$1" ]; then
        SKIPBEG=`echo $1 | cut -d "|" -f 1`
        SKIPEND=`echo $1 | cut -d "|" -f 2`
        occ=$(grep -o "|" <<< "$1" | wc -l)

        calculate_time $SKIPBEG
        SKIPBEG=$CALCTIME
        if [ $occ -gt 0 ] ; then
            calculate_time $SKIPEND
            SKIPEND=$CALCTIME

            if [ $SKIPEND -gt $SKIPBEG ]; then
                SKIPEND=$((SKIPEND - SKIPBEG))
            fi
        else
            SKIPEND=0
        fi

    fi
}

#**************************************************************************************************************
# Parse time values to remove
parse_values () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "parse_values"
    fi
    if [ ! -z "$1" ]; then
        HANDLER=`echo $1 | cut -d = -f 1`
        VALUE=`echo $1 | cut -d = -f 2`
        if [ $HANDLER == "beg" ] || [ $HANDLER == "b" ]; then
            calculate_time $VALUE
            BEGTIME=$CALCTIME
        elif [ $HANDLER == "end" ] || [ $HANDLER == "e" ]; then
            calculate_time $VALUE
            ENDTIME=$CALCTIME
        elif [ $HANDLER == "duration" ] || [ $HANDLER == "d" ]; then
            calculate_time $VALUE
            DURATION_TIME=$CALCTIME
        elif [ $HANDLER == "skip" ] || [ $HANDLER == "s" ]; then
            #parse_segdata "$VALUE"
            parse_skipdata "$VALUE"
            SKIP=1
        elif [ $HANDLER == "target" ] || [ $HANDLER == "t" ]; then
            CONV_TYPE=".$VALUE"
            CONV_CHECK="$VALUE"
        elif [ $HANDLER == "cut" ] || [ $HANDLER == "c" ]; then
            #parse_skipdata "$VALUE"
            #SPLIT_FILE=1
            massive_split_into "$VALUE"
        elif [ $HANDLER == "print" ] || [ $HANDLER == "p" ]; then
            PRINT_INFO=$VALUE
        elif [ $HANDLER == "sub" ]; then
            SUBFILE="$VALUE"
        elif [ $HANDLER == "w" ] || [ $HANDLER == "write" ]; then
            WRITEOUT="$VALUE"
            #echo "Infolist created by packAll.sh" > "$WRITEOUT"
        elif [ $HANDLER == "n" ] || [ $HANDLER == "name" ]; then
            NEWNAME="$VALUE"
        elif [ $1 == "scrub" ] || [ $1 == "s" ]; then
            SCRUB=$VALUE
        else
            echo "Unknown value $1"
        fi
        check_workmode
    fi
    CALCTIME=0
}

#**************************************************************************************************************
# Parse dimension values
parse_dimension () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "parse_dimension $1"
    fi
    if [ ! -z "$1" ]; then
        WIDTH=`echo $1 | cut -d x -f 1`
        HEIGHT=`echo $1 | cut -d x -f 2`
        COPY_ONLY=0
    fi
}

#**************************************************************************************************************
# Parse file information
parse_file () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "parse_file"
    fi
    if [ ! -z "$1" ]; then
        CONTINUE_PROCESS=1
        FILE="$1"
        FileStrLen=${#FILE}
        if [ ! -f "$FILE" ]; then
            if [ $FileStrLen -lt 7 ]; then
                FILECOUNT=`ls -l *"$FILE" 2>/dev/null | grep -v ^l | wc -l`
            else
                MULTIFILECOUNT=`ls -l *"$FILE"* 2>/dev/null | grep -v ^l | wc -l`
            fi
        fi
    fi
}

#***************************************************************************************************************
# Parse data from given inputs
parse_data () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "parse_data"
    fi
    if [ ! -z "$1" ]; then
        if [ $CHECKRUN == 0 ]; then
            parse_file "$1"
        else
            xss=$(grep -o "x" <<< "$1" | wc -l)
            #size=${#myvar}
            DATA2=`echo $1 | cut -d x -f 2`
            #ISNUM=${DATA2//[0-9]}
            if [ $xss == "0" ] || [ ! -z "$DATA2" ]; then
                xss=$(grep -o "=" <<< "$1" | wc -l)
                if [ $xss == "0" ]; then
                    parse_handlers "$1"
                else
                    parse_values "$1"
                fi
            else
                parse_dimension "$1"
            fi
        fi
    fi
}

#***************************************************************************************************************
print_file_info () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "print_file_info"
    fi

    if [ -f "$FILE" ]; then
        X=`mediainfo '--Inform=Video;%Width%' "$FILE"`
        if [ ! -z $X ]; then
            if [ "$PRINT_INFO" == "2" ] && [ "$WIDTH" -le "$X" ]; then
                return 0
            elif [ "$PRINT_INFO" == "3" ] && [ "$WIDTH" -ge "$X" ]; then
                return 0
            elif [ "$PRINT_INFO" == "4" ] && [ "$WIDTH" == "$X" ]; then
                echo "$PACKSIZE -- $X"
                return 0
            fi

            Y=`mediainfo '--Inform=Video;%Height%' "$FILE"`
            LEN=`mediainfo '--Inform=Video;%Duration%' "$FILE"`
            LEN=$((LEN / 1000))
            calculate_time_taken $LEN
            TIMESAVED=$((TIMESAVED + LEN))
            SIZE=`du -k "$FILE" | cut -f1`
            TOTALSAVE=$((TOTALSAVE + SIZE))
            SIZE=$((SIZE / 1000))
            if [ $MULTIFILECOUNT -gt 1 ]; then
                FILECOUNT=$MULTIFILECOUNT
            fi
            if [ $FILECOUNT -gt 1 ]; then
                if [ "$CURRENTFILECOUNTER" -lt "10" ]; then
                    FILECOUNTPRINTER="0$CURRENTFILECOUNTER of $FILECOUNT :: "
                else
                    FILECOUNTPRINTER="$CURRENTFILECOUNTER of $FILECOUNT :: "
                fi
            fi
            short_name
            echo "$FILECOUNTPRINTER$FILEprint X:$X Y:$Y Size:$SIZE Mb Lenght:$TIMER_TOTAL_PRINT"
            if [ ! -z "$WRITEOUT" ]; then
                echo "packAll.sh \"$FILE\" " >> "$WRITEOUT"
            fi
        else
            echo "$FILE is corrupted"
        fi
    fi
}

#***************************************************************************************************************
# Print multiple file handling information
print_info () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "print_info"
    fi
    TIMERR=`date +%T`
    #TIMERR=${TIMERR:11:8}
    calculate_time $TIMERR
    TIMERSTART=$CALCTIME
    if [ $FILECOUNT -gt 1 ]; then
        echo -n "$CURRENTFILECOUNTER of $FILECOUNT " #($TIMERR): "
    elif [ $MULTIFILECOUNT -gt 1 ]; then
        echo -n "$CURRENTFILECOUNTER of $MULTIFILECOUNT " # ($TIMERR): "
    fi
}

#***************************************************************************************************************
# Calculate time from current time data
calculate_duration () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "calculate_duration"
    fi
    TIMERR=`date +%T`
    #TIMERR=${TIMERR:11:8}
    calculate_time $TIMERR
    TIMEREND=$CALCTIME
    if [ $TIMEREND -gt $TIMERSTART ]; then
        TIMERVALUE=$((TIMEREND - TIMERSTART))
    else
        TIMERVALUE=$(((86400 - TIMERSTART) + TIMEREND))
    fi
    TIMERTOTAL=$((TIMERTOTAL + TIMERVALUE))
}

#***************************************************************************************************************
# Cut filename shorter if it's too long
short_name () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "short_name"
    fi
    if [ -z $1 ]; then
        NAMELIMITER=40
    else
        NAMELIMITER=$1
    fi
    nameLen=${#FILE}
    extLen=${#EXT_CURR}
    if [ $nameLen -gt $NAMELIMITER ]; then
        FILEprint="${FILE:0:$NAMELIMITER}...$EXT_CURR"
    elif [ $nameLen -le $NAMELIMITER ]; then
        PADDER=$(((NAMELIMITER - nameLen) + 3 + $extLen))
        PAD="                             "
        PADDING="${PAD:0:$PADDER}"
        FILEprint=$FILE$PADDING
    #else
    #    FILEprint=$FILE
    fi
}

#***************************************************************************************************************
# Extract mp3 by given parameters
extract_mp3 () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "extract_mp3"
    fi
    short_name
    echo -n "$FILEprint extracting mp3 "

    if [ $DURATION_TIME -gt 0 ]; then
        ENDTIME=$((ORIGINAL_DURATION - DURATION_TIME))
    fi

    if [ $WORKMODE == "1" ]; then
        avconv -ss $BEGTIME -i "$FILE" -acodec libmp3lame "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ $WORKMODE == "2" ]; then
        ENDO=$((DUR - ENDTIME))
        avconv -i "$FILE" -t $ENDO -acodec libmp3lame "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ $WORKMODE == "3" ]; then
        ENDO=$((DUR - ENDTIME - BEGTIME))
        avconv -ss $BEGTIME -i "$FILE" -t $ENDO -acodec libmp3lame "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ $WORKMODE == "4" ]; then
        avconv -i "$FILE" -acodec libmp3lame "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    fi
    if [ -f "$FILE$CONV_TYPE" ]; then
        rename "s/.$EXT_CURR//" "$FILE$CONV_TYPE"
        echo "Successfully extracted mp3"
    else
        Color.sh red
        echo "Failed!"
        Color.sh
    fi
}

#***************************************************************************************************************
copy_hevc () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "copy_hevc"
    fi
    short_name
    echo -n "$FILEprint HEVC copy ("$X"x"$Y") "
    if [ $MASSIVE_SPLIT == 1 ]; then
        echo -n "splitting file $CUTTING_TIME sec (mode: $WORKMODE) "
    elif [ $CUTTING_TIME -gt 0 ]; then
        echo -n "shortened by $CUTTING_TIME sec (mode: $WORKMODE) "
    fi

    if [ $WORKMODE == "1" ]; then
        #pack with skipping the beginning
        ffmpeg -ss $BEGTIME -i "$FILE" -c:v:1 copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ $WORKMODE == "2" ]; then
        #pack with skipping the ending
        ENDO=$((DUR - ENDTIME))
        ffmpeg -i "$FILE" -t $ENDO -c:v:1 copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ $WORKMODE == "3" ]; then
        #pack with skipping from the beginning and the end
        ENDO=$((DUR - ENDTIME - BEGTIME))
        ffmpeg -ss $BEGTIME -i "$FILE" -t $ENDO -c:v:1 copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    else
        #no time removal, so just pack it
        ffmpeg -i "$FILE" -c:v:1 copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    fi
}

#***************************************************************************************************************
convert_hevc () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "conver_hevc"
    fi
    short_name
    echo -n "$FILEprint FFMPEG packing ("$X"x"$Y")->($PACKSIZE) "
    if [ $CUTTING_TIME -gt 0 ]; then
        echo -n "cut $CUTTING_TIME sec (mode:$WORKMODE) "
    fi

    #ffmpeg -i "$FILE" -bsf:v h264_mp4toannexb -vf scale=$PACKSIZE -sn -map 0:0 -map 0:1 -vcodec libx264 "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    if [ $WORKMODE == "1" ]; then
        #pack with skipping the beginning
        ffmpeg -ss $BEGTIME -i "$FILE" -bsf:v h264_mp4toannexb -vf scale=$PACKSIZE -sn -map 0:0 -map 0:1 -vcodec libx264 "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ $WORKMODE == "2" ]; then
        #pack with skipping the ending
        ENDO=$((DUR - ENDTIME))
        ffmpeg -i "$FILE" -t $ENDO -bsf:v h264_mp4toannexb -vf scale=$PACKSIZE -sn -map 0:0 -map 0:1 -vcodec libx264 "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ $WORKMODE == "3" ]; then
        #pack with skipping from the beginning and the end
        ENDO=$((DUR - ENDTIME - BEGTIME))
        ffmpeg -ss $BEGTIME -i "$FILE" -t $ENDO -bsf:v h264_mp4toannexb -vf scale=$PACKSIZE -sn -map 0:0 -map 0:1 -vcodec libx264 "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    else
        #no time removal, so just pack it
        ffmpeg -i "$FILE" -bsf:v h264_mp4toannexb -vf scale=$PACKSIZE -sn -map 0:0 -map 0:1 -vcodec libx264 "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    fi
}

#***************************************************************************************************************
# Burn subtitle file to a given video file
burn_subs () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "burn_subs"
    fi

    if [ -f "$FILE" ]; then
        if [ -f "$SUBFILE" ]; then
            short_name
            echo -n "$FILEprint FFMPEG burning subs "
            ffmpeg -i "$FILE" -vf subtitles="$SUBFILE" "Subbed_$FILE" -v quiet
            echo "Done"
        else
            Color.sh red
            echo "Subfile $SUBFILE not found!"
            Color.sh
        fi
    else
        Color.sh red
        echo "File $FILE not found!"
        Color.sh
    fi
}

#***************************************************************************************************************
# Pack video file with given data
pack_it () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "pack_it"
    fi
    short_name
    echo -n "$FILEprint packing ("$X"x"$Y")->$PACKSIZE "
    if [ $CUTTING_TIME -gt 0 ]; then
        echo -n "cut $CUTTING_TIME sec (mode:$WORKMODE) "
    fi

    if [ $DURATION_TIME -gt 0 ]; then
        ENDTIME=$((ORIGINAL_DURATION - DURATION_TIME))
    fi

    if [ $WORKMODE == "1" ]; then
        #pack with skipping the beginning
        avconv -ss $BEGTIME -i "$FILE" -map 0 -map_metadata 0:s:0 -strict experimental -s "$PACKSIZE" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ $WORKMODE == "2" ]; then
        #pack with skipping the ending
        ENDO=$((DUR - ENDTIME))
        avconv -i "$FILE" -t $ENDO -map 0 -map_metadata 0:s:0-strict experimental -s "$PACKSIZE" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ $WORKMODE == "3" ]; then
        #pack with skipping from the beginning and the end
        ENDO=$((DUR - ENDTIME - BEGTIME))
        avconv -ss $BEGTIME -i "$FILE" -t $ENDO -map 0 -map_metadata 0:s:0 -strict experimental -s "$PACKSIZE" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    else
        #no time removal, so just pack it
        #avconv -i "$FILE" -map 0 -map_metadata 0:s:0 -strict experimental -s "$PACKSIZE" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
        avconv -i "$FILE" -s "$PACKSIZE" "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    fi
}

#***************************************************************************************************************
# COPY_ONLY video to different format
copy_it () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "copy_it"
    fi
    short_name
    echo -n "$FILEprint "
    if [ $EXT_CURR != $CONV_CHECK ]; then
        echo -n "being transformed "
    fi
    if [ $MASSIVE_SPLIT == 1 ]; then
        echo -n "splitting file $CUTTING_TIME sec (mode: $WORKMODE) "
    elif [ $CUTTING_TIME -gt 0 ]; then
        echo -n "shortened by $CUTTING_TIME sec (mode: $WORKMODE) "
    fi

    if [ $WORKMODE == "1" ]; then
        #pack with skipping the beginning
        avconv -ss $BEGTIME -i "$FILE" -map 0 -map_metadata 0:s:0 -c copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ $WORKMODE == "2" ]; then
        #pack with skipping the ending
        ENDO=$((DUR - ENDTIME))
        avconv -i "$FILE" -t $ENDO -map 0 -map_metadata 0:s:0 -c copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    elif [ $WORKMODE == "3" ]; then
        #pack with skipping from the beginning and the end
        ENDO=$((DUR - ENDTIME - BEGTIME))
        avconv -ss $BEGTIME -i "$FILE" -t $ENDO -map 0 -map_metadata 0:s:0 -c copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
    else
        #no time removal, so just pack it
        if [ $EXT_CURR != "$CONV_CHECK" ]; then
            #avconv -i "$FILE" -map 0 -map_metadata 0:s:0 -c copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
            avconv -i "$FILE" -c:a copy -c:v copy "$FILE$CONV_TYPE" -v quiet >/dev/null 2>&1
        fi
    fi
}

#***************************************************************************************************************
# Remove a segment from the middle of the video file
remove_segment () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "remove_segment"
    fi
    short_name
    if [ $SKIP == 1 ]; then
        echo -n "$FILEprint segment being removed (not really working good!)"
    else
        echo -n "$FILEprint being split into two files"
    fi
    BEGTIME=0

    avconv -i "$FILE" -t $SKIPBEG -map 0 -map_metadata 0:s:0 -c copy "$FILE"_1"$CONV_TYPE" -v quiet >/dev/null 2>&1
    SKIPBEG=$((SKIPBEG + SKIPEND))
    ENDO=$((DUR - SKIPBEG))
    ENDTIME=$((SKIPEND - SKIPBEG))
    if [ $ENDTIME -lt 0 ]; then
        ENDTIME=$((ENDTIME * -1))
    fi
    avconv -ss $SKIPBEG -i "$FILE" -t $ENDO -map 0 -map_metadata 0:s:0 -c copy "$FILE"_2"$CONV_TYPE" -v quiet >/dev/null 2>&1

    if [ $SKIP == 1 ]; then
        MP4Box "temp_1$CONV_TYPE" -cat "temp_2$CONV_TYPE" -out "$FILE$CONV_TYPE" >/dev/null 2>&1
        delete_file "$FILE"_1"$CONV_TYPE"
        delete_file "$FILE"_2"$CONV_TYPE"
    fi
}

#***************************************************************************************************************
RUNNING_FILENAME=""
make_running_name () {
    ExtLen=${#EXT_CURR}
    NameLen=${#FILE}
    LEN_NO_EXT=$((NameLen - ExtLen))
    if [ -z $NEWNAME ]; then
        RUNNING_FILENAME=${FILE:0:$LEN_NO_EXT}
    else
        RUNNING_FILENAME=$NEWNAME
    fi
    if [ $RUNNING_FILE_NUMBER -lt 10 ]; then
        RUNNING_FILENAME+="_0$RUNNING_FILE_NUMBER$CONV_TYPE"
    else
        RUNNING_FILENAME+="_$RUNNING_FILE_NUMBER$CONV_TYPE"
    fi
}

#***************************************************************************************************************
# When keeping an original file, make the extracted piece it's own unique number, so many parts can be extracted
move_to_a_running_file () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "move_to_a_running_file"
    fi
    RUNNING_FILE_NUMBER=1
    make_running_name
    if [ -f "$RUNNING_FILENAME" ]; then
        while true; do
            RUNNING_FILE_NUMBER=$((RUNNING_FILE_NUMBER + 1))
            make_running_name
            if [ ! -f "$RUNNING_FILENAME" ]; then
                break;
            fi
        done
    fi

    mv "$FILE$CONV_TYPE" "$RUNNING_FILENAME"
}

#***************************************************************************************************************
# Rename output file to correct format or move unsuccesful file to other directory
handle_file_rename () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "handle_file_rename"
    fi
    if [ $1 -gt 0 ]; then
        if [ $KEEPORG == "0" ]; then
            delete_file "$FILE"
        fi

        if [ $SPLIT_FILE == 0 ]; then
            if [ $KEEPORG == "0" ]; then
                if [ $EXT_CURR == $CONV_CHECK ]; then
                    if [ -z $NEWNAME ]; then
                        mv "$FILE$CONV_TYPE" "$FILE"
                    else
                        mv "$FILE$CONV_TYPE" "$NEWNAME$CONV_TYPE"
                    fi
                else
                    rename "s/.$EXT_CURR//" "$FILE$CONV_TYPE"
                fi
            else
                move_to_a_running_file
            fi
        fi
    else
        if [ $SPLIT_FILE == 1 ]; then
            delete_file "$FILE"_1"$CONV_TYPE"
            delete_file "$FILE"_2"$CONV_TYPE"
        else
            delete_file "$FILE$CONV_TYPE"
            if [ $EXT_CURR == $CONV_CHECK ] && [ $COPY_ONLY == 0 ]; then
                if [ ! -d "./Failed" ]; then
                    mkdir "Failed"
                fi
                mv "$FILE" "./Failed"
            fi
        fi
    fi
}

#***************************************************************************************************************
#Calculate dimension ratio change
calculate_packsize () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "calculate_packsize"
    fi
    # Get original video dimensions
    XC=`mediainfo '--Inform=Video;%Width%' "$FILE"`
    YC=`mediainfo '--Inform=Video;%Height%' "$FILE"`
    # Calculate dimension scale
    SCALE=$(bc <<< "scale=25;($WIDTH/($XC/$YC))")
    # Change scale to int
    SCALE=$(bc <<< "scale=0;$SCALE/1")
    # Check division of 8
    SCALECORR=$(bc <<< "$SCALE%8")
    # Correct to a multiplier of 8
    SCALE=$((SCALE - SCALECORR))

    PACKSIZE="$WIDTH"x"$SCALE"
}

#***************************************************************************************************************
# Move corrupted file to a Error directory
handle_error_file () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "handle_error_file"
    fi
    if [ ! -d "./Error" ]; then
        mkdir "Error"
    fi
    mv "$FILE" "./Error"
    Color.sh red
    echo "Something corrupted with $FILE"
    Color.sh
}

#***************************************************************************************************************
# Check if file was a filetype conversion, and accept the bigger filesize in that case
check_alternative_conversion () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "check_alternative_conversion"
    fi
    xNEW_DURATION=$((NEW_DURATION / 1000))
    xORIGINAL_DURATION=$((ORIGINAL_DURATION / 1000))
    xNEW_FILESIZE=$((NEW_FILESIZE / 1000))
    xORIGINAL_SIZE=$((ORIGINAL_SIZE / 1000))
    if [ $EXT_CURR == $CONV_CHECK ]; then
        handle_file_rename 0
        Color.sh red
        echo " FAILED! time:$xNEW_DURATION<$xORIGINAL_DURATION size:$xNEW_FILESIZE>$xORIGINAL_SIZE"
        Color.sh
    elif [ $COPY_ONLY != 0 ]; then
        DURATION_CHECK=$((DURATION_CHECK - 2000))
        if [ $NEW_DURATION -gt $DURATION_CHECK ]; then
            handle_file_rename 1
            echo "| Converted. $((ORIGINAL_DURATION - NEW_DURATION))sec and $(((ORIGINAL_SIZE - NEW_FILESIZE) / 1000))Mb in $TIMERVALUE sec"
            SUCCESFULFILECNT=$((SUCCESFULFILECNT + 1))
            TIMESAVED=$((TIMESAVED + DURATION_CUT))
        else
            Color.sh red
            echo "| FAILED CONVERSION! time:$xNEW_DURATION<$xORIGINAL_DURATION file:$xNEW_FILESIZE>$xORIGINAL_SIZE"
            Color.sh
            handle_file_rename 0
        fi
    else
        handle_file_rename 0
        Color.sh red
        echo " FAILED! time:$xNEW_DURATION<$xORIGINAL_DURATION size:$xNEW_FILESIZE>$xORIGINAL_SIZE"
        Color.sh
    fi
}

#***************************************************************************************************************
check_if_files_exist () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "check_if_file_exists"
    fi
    FILE_EXISTS=0
    if [ $MASSIVE_SPLIT == 1 ]; then
        FILE_EXISTS=1
    elif [ $SPLIT_FILE == 1 ]; then
        if [ -f "$FILE"_1"$CONV_TYPE" ] && [ -f "$FILE"_2"$CONV_TYPE" ]; then
            FILE_EXISTS=1
        fi
    elif [ -f "$FILE$CONV_TYPE" ]; then
        FILE_EXISTS=1
    fi
}

#***************************************************************************************************************
remove_interrupted_files () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "remove_interrupted_files"
    fi
    if [ -f "$FILE$CONV_TYPE" ]; then
        delete_file "$FILE$CONV_TYPE"
    fi
    if [ -f "$FILE"_1"$CONV_TYPE" ]; then
        delete_file "$FILE"_1"$CONV_TYPE"
    fi
    if [ -f "$FILE"_2"$CONV_TYPE" ]; then
        delete_file "$FILE"_2"$CONV_TYPE"
    fi
}

#***************************************************************************************************************
# Check file handling, if size is smaller and destination file length is the same (with 2sec error marginal)
check_file_conversion () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "check_file_conversion"
    fi
    #if destination file exists
    check_if_files_exist
    if [ $FILE_EXISTS == 1 ] && [ $SYS_INTERRUPT == 0 ]; then
        if [ $SPLIT_FILE == 1 ]; then
            DURATION_P1=`mediainfo '--Inform=Video;%Duration%' "$FILE"_1"$CONV_TYPE"`
            DURATION_P2=`mediainfo '--Inform=Video;%Duration%' "$FILE"_2"$CONV_TYPE"`
            NEW_DURATION=$((DURATION_P1 + DURATION_P2))
            NEW_FILESIZE=12
        else
            NEW_DURATION=`mediainfo '--Inform=Video;%Duration%' "$FILE$CONV_TYPE"`
            NEW_FILESIZE=`du -k "$FILE$CONV_TYPE" | cut -f1`
        fi
        DURATION_CUT=$(((BEGTIME + ENDTIME) * 1000))
        DURATION_CHECK=$((ORIGINAL_DURATION - DURATION_CUT - 2000))
        ORIGINAL_SIZE=`du -k "$FILE" | cut -f1`
        ORIGINAL_HOLDER=$ORIGINAL_SIZE
        if [ -z $NEW_DURATION ]; then
            NEW_DURATION=0
        fi

        if [ $IGNORE == "1" ] || [ $SPLIT_FILE == "1" ]; then
            ORIGINAL_SIZE=$(($NEW_FILESIZE + 10000))
        fi

        #if video length matches (with one second error tolerance) and destination file is smaller than original, then
        if [ $NEW_DURATION -gt $DURATION_CHECK ] && [ $ORIGINAL_SIZE -gt $NEW_FILESIZE ]; then
            ORIGINAL_SIZE=$ORIGINAL_HOLDER
            ENDSIZE=$((ORIGINAL_SIZE - NEW_FILESIZE))
            TOTALSAVE=$((TOTALSAVE + $ENDSIZE))
            SUCCESFULFILECNT=$((SUCCESFULFILECNT + 1))
            ENDSIZE=$((ENDSIZE / 1000))
            TIMESAVED=$((TIMESAVED + DURATION_CUT))
            Color.sh green
            if [ $MASSIVE_SPLIT == 1 ]; then
                echo " Success in $TIMERVALUE sec"
            elif [ $SPLIT_FILE == 0 ]; then
                echo " Success! Saved $ENDSIZE Mb in $TIMERVALUE sec"
            else
                echo " Done!"
            fi
            Color.sh
            handle_file_rename 1
        else
            check_alternative_conversion
        fi
    else
        if [ $SYS_INTERRUPT == 0 ]; then
            Color.sh red
            echo " No destination file!"
            Color.sh
            if [ ! -d "./Nodest" ]; then
                mkdir "Nodest"
            fi
            mv "$FILE" "./Nodest"
        fi
        remove_interrupted_files
    fi
}

#***************************************************************************************************************
# Check what kind of file handling will be accessed
handle_file_packing () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "handle_file_packing"
    fi
    Y=`mediainfo '--Inform=Video;%Height%' "$FILE"`
    CUTTING_TIME=$((BEGTIME + ENDTIME + DURATION_TIME))
    ORIGINAL_DURATION=`mediainfo '--Inform=Video;%Duration%' "$FILE"`
    if [[ $ORIGINAL_DURATION = *"."* ]]; then
        ORIGINAL_DURATION=$(grep -o "." <<< "$1" | wc -l)
    fi
    DUR=$((ORIGINAL_DURATION / 1000))

    if [ $CROP == 0 ]; then
        print_info
    fi

    #if not SYS_INTERRUPTrupted
    if [ $SYS_INTERRUPT == 0 ]; then
        if [ $REPACK == 1 ]; then
            XP=`mediainfo '--Inform=Video;%Width%' "$FILE"`
            if [ $HEVC_CONV == 1 ]; then
                PACKSIZE="$XP":"$Y"
            else
                PACKSIZE="$XP"x"$Y"
            fi
            COPY_ONLY=0
        else
            calculate_packsize
        fi

        if [ $MP3OUT == 1 ]; then
            extract_mp3
        elif [ $CROP == 1 ]; then
            check_and_crop
        else
            if [ $HEVC_CONV == 1 ]; then
                if [ $COPY_ONLY == 0 ]; then
                    convert_hevc
                else
                    copy_hevc
                fi
            elif [ $SKIP == 1 ] || [ $SPLIT_FILE == 1 ]; then
                remove_segment
            elif [ $COPY_ONLY == 0 ]; then
                pack_it
            else
                copy_it
            fi
            calculate_duration
            check_file_conversion
        fi
    else
        delete_file "$FILE$CONV_TYPE"
    fi
}

#***************************************************************************************************************
# Main file handling function
pack_file () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "pack_file"
    fi
    # if not SYS_INTERRUPTrupted and WORKMODE is for an existing dimensions
    X=`mediainfo '--Inform=Video;%Width%' "$FILE"`

    if [ $PRINT_INFO -gt 0 ]; then
        print_file_info
    else
        if [ ! -f "$FILE" ]; then
            MISSING=$((MISSING + 1))
            if [ $PRINT_ALL == 1 ]; then
                print_info
                echo "$FILE is not found!"
            fi
        elif [ -z "$X" ]; then
            handle_error_file
        elif [ $SYS_INTERRUPT == 0 ] && [ $WORKMODE -gt 0 ] && [ $X -gt $WIDTH ]; then
            handle_file_packing
        elif [ $PRINT_ALL == 1 ]; then
            print_info
            echo "$FILE width:$X skipping"
        elif [ $X -le $WIDTH ] && [ $FILECOUNT == 1 ]; then
            Color.sh yellow
            echo "$FILE cannot be packed $X <= $WIDTH"
            Color.sh
        fi
    fi
}

#***************************************************************************************************************
# Calculate time taken to process data
TIMERMINS=0
TIMERHOURS=0
TIMERSECS=0
TIMEPRINTOUT=0

calculate_time_taken () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "calculate_time_taken"
    fi
    if [ -z "$1" ]; then
        TIMERSECS=$TIMERTOTAL
    else
        TIMERSECS="$1"
    fi
    TIMEPRINTOUT=0
    if [ $TIMERSECS -gt 60 ]; then
        TIMERMINS=$((TIMERSECS / 60))
        TIMERSECS=$((TIMERSECS - (TIMERMINS * 60)))
        TIMEPRINTOUT=1
    fi

    if [ $TIMERMINS -gt 60 ]; then
        TIMERHOURS=$((TIMERMINS / 60))
        TIMERMINS=$((TIMERMINS - (TIMERHOURS * 60)))
        TIMEPRINTOUT=2
    fi

    if [ $TIMEPRINTOUT == 1 ]; then
        TIMER_TOTAL_PRINT="$TIMERMINS min $TIMERSECS sec"
    elif [ $TIMEPRINTOUT == 2 ]; then
        TIMER_TOTAL_PRINT="$TIMERHOURS hrs $TIMERMINS min $TIMERSECS sec"
    else
        TIMER_TOTAL_PRINT="$TIMERSECS sec"
    fi
}

#***************************************************************************************************************
# Print total handled data information
print_total () {
    if [ $DEBUG_PRINT == 1 ]; then
        echo "print_total"
    fi
    TOTALSAVE=$((TOTALSAVE / 1000))
    if [ $PRINT_INFO == 1 ]; then
        calculate_time_taken $TIMESAVED
        echo "Total in $CURRENTFILECOUNTER files, Size:$TOTALSAVE Length:$TIMER_TOTAL_PRINT"
    else
        if [ $TIMESAVED -gt "0" ]; then
            TIMESAVED=$((TIMESAVED  / 1000))
            calculate_time_taken $TIMESAVED
            TIMESAVEPRINT=$TIMER_TOTAL_PRINT
        fi
        calculate_time_taken

        if [ $COPY_ONLY == 0 ] || [ $TIMESAVED -gt "0" ]; then
            echo  "Totally saved $TOTALSAVE Mb $TIMESAVEPRINT on $SUCCESFULFILECNT files in $TIMER_TOTAL_PRINT"
        else
            echo "Handled $SUCCESFULFILECNT files to $CONV_CHECK (size change: $TOTALSAVE Mb) in $TIMER_TOTAL_PRINT"
        fi
        if [ $MISSING -gt "0" ]; then
            echo "Number of files disappeared during process: $MISSING"
        fi
    fi
}

#***************************************************************************************************************
verify_necessary_programs() {
    error_code=0
    hash ffmpeg || error_code=$?
    hash avconv || error_code=$?
    hash mediainfo || error_code=$?
    if [ $error_code -ne 0 ]; then
        echo "Missing necessary programs: ffmpeg, avconv or mediainfo"
        exit 1
    fi
}

#***************************************************************************************************************
verify_commandline_input() {
    if [ $# -le 0 ]; then
        print_help
        exit 1
    fi
}

#***************************************************************************************************************
# The MAIN VOID function

verify_necessary_programs
verify_commandline_input "$@"

for var in "$@"
do
    parse_data "$var"
    CHECKRUN=$((CHECKRUN + 1))
done

if [ $CHECKRUN == "0" ]; then
        print_help
elif [ $CONTINUE_PROCESS == 1 ]; then
#    if [ -f "$FILE" ]; then
#        FILECOUNT=1
#        MULTIFILECOUNT=1
#        EXT_CURR="${FILE##*.}"
#        pack_file
#    el
    if [ ! -z "$SUBFILE" ]; then
        burn_subs
    elif [ "$FILECOUNT" -gt 1 ] || [ $FileStrLen -lt 5 ]; then
        EXT_CURR="$FILE"
        for    f in *.$EXT_CURR
            do
                if [ $SYS_INTERRUPT == 0 ]; then
                    FILE="$f"
                    CURRENTFILECOUNTER=$((CURRENTFILECOUNTER + 1))
                    pack_file
                fi
            done
    elif [ $MULTIFILECOUNT -gt 1 ]; then
        EXT_CURRF=*"$FILE"*
        for f in $EXT_CURRF
            do
                if [ $SYS_INTERRUPT == 0 ] && [ -f $f ]; then
                    FILE="$f"
                    EXT_CURR="${FILE##*.}"
                    CURRENTFILECOUNTER=$((CURRENTFILECOUNTER + 1))
                    pack_file
                fi
            done
    else
        FILECOUNT=1
        EXT_CURR="${FILE##*.}"
        pack_file
    fi
    if [ $CURRENTFILECOUNTER -gt "1" ]; then
        print_total
    fi
fi

