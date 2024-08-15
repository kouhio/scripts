#!/bin/bash

printGrep() {
    STRING="${1:-STRING}"
    STRING2="${2:-STRING2}"
    echo -e "GREP things:\n"
    echo -e "Exclude STRING from search                     -v $STRING\n"
    echo -e "Print information:                             -n rownumber in file"
    echo -e "                                               -c count of found items\n"
    echo -e "Search for multiple patters:                   -e $STRING -e STRING2 -e $STRING..."
    echo -e "                                               -E '$STRING|$STRING2|...'\n"
    echo -e "Ignore string case:                            -i $STRING\n"
    echo -e "Search for tab:                                -P '\\\t' *"
}

printFind() {
    STRING="${1:-FILENAME}"
    echo -e "FIND things:\n"
    echo -e "Find only files                                -type f"
    echo -e "Ignore case search                             -iname \"$STRING\""
    echo -e "Execute command on found items                 -exec $STRING {} \;"
}

printVim () {
    STRING="${1:-STRING}"
    STRING2="${2:-STRING2}"
    echo -e "VIM things:\n"
    echo    "Search for multiple strings at once                    :\\v$STRING|$STRING2"
    echo -e "Search two strings in one row                          :$STRING.*$STRING2"
    echo -e "Search for STRING1 that doesn't continue with STRING2  :$STRING\($STRING2\)\@!"
    echo    "Search for STRING that's not case sensitive            :$STRING\c"
    echo    "Seach for function without comment                     :\n}\n\n\(\/\)\@!"
    echo -e "\nMultiple file handling:\n :ls -> list files | :b(N) -> jump to file (N) | :bn / :bp -> move between files | :bd -> close current file\n"
    echo -e "Replace with autoindent                                :%s/$STRING/$STRING2/ |normal=\`\`"
    echo -e "Do replace on only rows between                        :ROW_START,ROW_ENDs/$STRING/$STRING2/g"
    echo -e "Ignore whitespace in search                            :/${STRING}_s*$STRING2\n"
    echo -e "Remove all trailing whitespace                         :%s/\s\+$//e"
    echo -e "Remove all rows containing string                      :g/$STRING/d"
    echo -e "Remove all rows not having STRING                      :%g!/$STRING/d"
    echo -e "Remove everything after string                         :%s/$STRING.*g"
    echo -e "Remove carriage return ^M                              :%s/\\r//\n"
    echo -e "Special search options                                 :\\+ repeat given string | \$ end of the line\n"
    echo -e "ctrl+v -> paint all rows -> g -> ctrl+a (to increment all values)"
    echo -e "ctrl+v -> paint all rows / test -> c -> write new text to replace painted text -> esc"
    echo -e "ctrl+v -> paint all rows / test -> I -> insert new text to start of painted text -> esc\n"
    echo -e "search for rows longer than LEN                        \\%>LENv.\\+"
    echo -e "search for rows less than LEN                          ^.\\{,LEN}$/"
    echo -e "search for rows not ending in STRING                   ^.*\\($STRING\\)\\@<!$\n"
    echo -e "duplicate each line                                    :g/^/norm yyp"
    echo -e "join each other row                                    :%norm J"
    echo -e "soft all rows alphabetically                           :%!sort"
    echo -e "sort all rows numerically                              :%!sort -n"
    echo -e "sort all visually selected rows                        :!sort"
}

printGit () {
    echo -e "GIT things:\n"
    echo -e "Local merging:\n git branch tmp\n git checkout master\n git pull\n git merge tmp\n git branch -d tmp\n"
    echo -e "Resets:\n --soft -> remove only commit, keep changes\n --hard -> remove everything that isn't merged\n"
    echo -e "Stashing:\n git stash\n git stash list\n git stash pop\n"
    echo -e "Revert file to original state:         git checkout -- FILENAME\n"
    echo -e "Create new branch from current:        git checkout -b BRANCHNAME"
    echo -e "Delete remote branch:                  git push origin --delete BRANCHNAME"
    echo -e "Create new empty repo on server:       git init --bare --shared REPONAME.git\n"
    echo -e "Update single submodule:               git submodule update --init SUBMODULE_PATH"
    echo -e "Add new submodule:                     git submodule add GIT-PATH LOCAL_PATH"
    echo -e "Update submodule links                 git submodule sync\n"
    echo -e "Find commit by hash:                   git show HASHCODE"
    echo -e "Add commit message in commandline:     git commit -m \"COMMIT\""
    echo -e "Find creator of code lines:            git blame FILENAME -L ROW,+SHOW_ROWS"
    echo -e "Merge latest file from branch:         git checkout --patch BRANCH FILENAME"
    echo -e "Get remote URL of repo:                git config --get remote.origin.url"
    echo -e "Do in all dirs, ignore errors          git submodule foreach 'COMMAND || true'"
    echo -e "Find string in logs                    git log --grep=word"
    echo -e "Update remote branches                 git remote update origin --prune"
    echo -e "See old code                           git show REVISION:path/to/file"
}

printYocto () {
    echo -e "YOCTO things:\n"
    echo -e "automatic revision                     SRCREV = \"\${AUTOREV}\""
    echo -e "let yocto search whole system          OECMAKE_FIND_ROOT_PATH_MODE_PROGRAM = \"BOTH\""
    echo -e "include packages                       inherit pkgconfig cmake"
    echo -e "Set source path                        S=\"\${WORKDIR}/git\""
    echo -e "Set cmake variables to go into Cmake   EXTRA_OECMAKE += \"-DYOKI_PATH=\${STAGING_DIR_TARGET}\""
    echo -e "package types                          PACKAGES = \"\${PN} \${PN}-dev \${PN}-dbg\""
    echo -e "clean package                          bitbake -c cleanall PROJECT\n"
    echo -e "scroll in screen-mode:                 ctrl+a -> esc"
    echo -e "print from recipe:                     bbwarn \"blah blah\""
}

printCmake () {
    echo -e "CMAKE things:\n"
    echo -e "Add all files from directory           file(GLOB_RECURSE PKG_FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/*.*\")"
    echo -e "Make options                           set(CMAKE_CXX_FLAGS_DEBUG \"\${CMAKE_CXX_FLAGS_DEBUG} -Wall -O0 -g3 -ggdb\")"
    echo -e "build options                          option(HOST_BUILD \"Application is built on host\" OFF)"
    echo -e "project options                        set (PKG_NAME \"ala\"), project(\${PKG_NAME})"
    echo -e "cmake flags                            set(CMAKE_CXX_FLAGS \"\${CMAKE_CXX_FLAGS} -D_NO_PLATFORM_\")"
    echo -e "include extra cmake files              include(\${YOKI_PATH}/usr/include/cmake/all.cmake)"
    echo -e "include source directories             include_directories(\${CMAKE_CURRENT_SOURCE_DIR}/inc)"
    echo -e "include lib directories                link_directories(\${CMAKE_CURRENT_SOURCE_DIR}/../lib)"
    echo -e "add directory with it's own cmake      add_subdirectory(protobuf)"
    echo -e "create binary from files               add_executable(\${PKG_NAME} \${PKG_SOURCES})"
    echo -e "include libraries to build             TARGET_LINK_LIBRARIES(\${PKG_NAME} pthread libipc.so)"
    echo -e "create library frm files               add_library(\${PKG_NAME} SHARED "
    echo -e "install headers                        install(DIRECTORY \${CMAKE_CURRENT_SOURCE_DIR}/../include/"
    echo -e "                                           DESTINATION /usr/local/include/\${PKG_NAME} FILES_MATCHING PATTERN *.h)"
    echo -e "install files                          install(TARGETS \${PKG_NAME} DESTINATION /usr/local/lib)"
    echo -e "find packages                          find_package(Git)"
    echo -e "use git in cmake                       if (GIT_FOUND)"
    echo -e "                                       execute_process(COMMAND \${GIT_EXECUTABLE} rev-parse --verify HEAD"
    echo -e "                                           WORKING_DIRECTORY \${CMAKE_CURRENT_SOURCE_DIR} OUTPUT_VARIABLE _APP_COMMIT_)"
    echo -e "                                       add_definitions(\"-D_APP_COMMIT_=\${_APP_COMMIT_}\")"
    echo -e "Print out message                      message(WARNING \"git is not found on the system, cannot update _APP_COMMIT_\")"
}

printAwk () {
    echo -e "Print all logged users     who | awk '{cmd=\"echo \"\$1}; system(cmd)'"
    echo -e "Logout all logged users    who | awk '\$1 !~ /root/{ cmd=\"/sbin/pkill -KILL -u \" \$1; system(cmd)}'"
}

printBash () {
    STRING="${1:-STRING}"
    ARRAY="${2:-ARRAY}"
    ITEM="${2:-ITEM}"
    echo -en "Get size of array                         \${#$STRING[@]}\n"
    echo -en "Get length of string                      \${#$STRING}\n"
    echo -en "Remove string beginning                   \${$STRING:POS}\n"
    echo -en "Get substring                             \${$STRING:POS:EPOS}\n"
    echo -en "Split string, get start                   \${$STRING%.*}\n"
    echo -en "Split string, get end                     \${$STRING##*.}\n"
    echo -en "Split string at length                    \$($STRING:START_POSITION:STR_LENGTH)\n"
    echo -en "Remove string from end                    \$($STRING%REM_STR)\n"
    echo -en "Lowercase string                          \${$STRING,,}\n"
    echo -en "Uppercase string                          \${$STRING^^}\n"
    echo -en "Replace all substrings                    \${$STRING//SUBS/REPLACEMENT}\n\n"
    echo -en "Loop array                                for $ITEM in \"\${$STRING[@]}\"; do -> done\n"
    echo -en "Loop array with value                     for $ITEM in \"\${!$STRING[@]}\"; do -> done\n"
    echo -en "Get array item with value                 \${$ARRAY[index]}\n\n"
    echo -en "Split string into array                   $ARRAY=(\${$STRING//,/\$IFS})\n"
    echo -en "Split string into array                   mapfile -t $ARRAY < <(printf \"%s\" \"$STRING\")\n"
    echo -en "Split input into array                    mapfile -t $ARRAY <<<\$($STRING)\n"
    echo -en "Split string into array with delimiter    mapfile -t -d ' ' $ARRAY < <(printf \"%s\" \"$STRING\")\n"
    echo -en "Set IFS for enter                         NEW_LINE=$'\\\x0A'; export IFS=\"\${NEW_LINE}\";\n\n"
    echo -en "Find all file extensions                  find . -type f -name '*.*' | sed 's|.*\.||' | sort -u\n"
}

printRename () {
    STRING="${1:-STRING}"
    echo -en "Remove all after char                 rename \"s/${STRING}.*//\" *\n"
    echo -en "Insert string to beginning of file    rename \"s/^/$STRING/\" *\n"
}

printScreen () {
    echo -en "Scroll within screen:             ctrl+a -> ESC\n"
}

printRPM () {
    echo -en "List files in an RPM:             rpm -ql\n"
}

option="$1"
shift
if [ "$option" == "grep" ]; then
    printGrep "$@"
elif [ "$option" == "vi" ] || [ "$option" == "vim" ]; then
    printVim "$@"
elif [ "$option" == "git" ]; then
    printGit "$@"
elif [ "$option" == "yocto" ] || [ "$option" == "yoki" ] || [ "$option" == "cgx" ]; then
    printYocto "$@"
elif [ "$option" == "cmake" ]; then
    printCmake "$@"
elif [ "$option" == "awk" ]; then
    printAwk "$@"
elif [ "$option" == "bash" ]; then
    printBash "$@"
elif [ "$option" == "find" ]; then
    printFind "$@"
elif [ "$option" == "rename" ]; then
    printRename "$@"
elif [ "$option" == "screen" ]; then
    printScreen "$@"
elif [ "$option" == "rpm" ]; then
    printRPM "$@"
else
    echo -e "Choose: grep / vi / git / yocto / cmake / awk / bash / find / rename / screen / rpm"
    help2.sh "$1"
fi
