# Collection of different kind of scripts to manipulate and separate audio, video and code files

Miscellaneous scripts:

Color.sh                - Change terminal output coloring


Audio Manipulation scripts:

extractMp3.sh           - Extract part of audio from given input file (video or audio)

findSilence.sh          - Script to find silence in audio or video files, and to either split them, or just to report them

fixMp3Time.sh           - Fix timing errors found in VBR mp3's recursively in directory and all sub-directories

Rec.sh                  - Record computer audio stream to wav


Video manipulation scripts:

individualPack.sh       - Script using packAll.sh to create a command list to edit modifications for individual video files in one directory

packAll.sh              - Script to re-package, scale and split video files

Moveall.sh              - Move given files from sub-directories and delete rest of the directory


Code manipulation scripts:

OpenVimGrep.sh          - Search for files with a given string and open all files in vim

ReplaceStringTodo.sh    - Replace given string in multiple files to either //TODO: or another given string

emptyCPP.sh             - Create empty header and cpp files with basic setup

grepMultiples.sh        - Grep given string in files against other files to find duplicates and report
