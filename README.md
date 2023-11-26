# Collection of different kind of scripts to manipulate and separate audio, video and code files

Miscellaneous scripts:

Color.sh                - Change terminal output coloring

VimScript.sh            - Open files with vim with special conditions

GIT.sh                  - Alternative git-command handler for bash

HELP.sh                 - Miscellaneous help topics

sound.sh                - An alternative for a beeper

lib                     - Library of several commands made for easy access


Audio Manipulation scripts:

extractMp3.sh           - Extract part of audio from given input file (video or audio)

findSilence.sh          - Script to find silence in audio or video files, and to either split them, or just to report them

fixMp3Time.sh           - Fix timing errors found in VBR mp3's recursively in directory and all sub-directories

Rec.sh                  - Record computer audio stream to wav

repack_audio.sh         - Re-encode any audio to mp3

splitAudio.sh           - autosplit all same type audiofiles with findSilence.sh

readTracksFromURL.sh    - Read album info and tracks from Spotify or Discogs URL


Video manipulation scripts:

individualPack.sh       - Script using packAll.sh to create a command list to edit modifications for individual video files in one directory

packAll.sh              - Script to re-package, scale and split video files

Moveall.sh              - Move given files from sub-directories and delete rest of the directory

clearAudio.sh           - Remove given audio from given videos, uses audfprint


Code manipulation scripts:

OpenVimGrep.sh          - Search for files with a given string and open all files in vim

ReplaceStringTodo.sh    - Replace given string in multiple files to either //TODO: or another given string

emptyCPP.sh             - Create empty header and cpp files with basic setup

grepMultiples.sh        - Grep given string in files against other files to find duplicates and report


Commandline manipulation scripts:

eachDir.sh              - Run given input command & parameters in all subdirectories

AllDirs.sh              - Run given command in each directory and their subdirectories

Repeat.sh               - Repeat given command until break is called

Time.sh                 - Calculate time to run given commandline process
