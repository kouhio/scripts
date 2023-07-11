#!/bin/bash

printGrep() {
    echo -e "GREP things:\n"
    echo -e "Exclude STRING from search                     -v STRING\n"
    echo -e "Print information:   -n rownumber in file      -c count of found items\n"
    echo -e "Search for multiple patters:                   -e STRING1 -e STRING2 -e STRING...\n"
    echo -e "Ignore string care:                            -i STRING\n"
    echo -e "Search for tab:                                -P '\t' *"
}

printVim () {
    echo -e "VIM things:\n"
    echo    "Search for multiple strings at once                    :\vSTRING|STRING"
    echo -e "Search two different string in one row                 :STRING1.*STRING2"
    echo -e "Search for STRING1 that doesn't continue with STRING2  :STRING1\(STRING2\)\@!"
    echo    "Search for STRING that's not case sensitive            :STRING\c"
    echo    "Seach for function without comment                     :\n}\n\n\(\/\)\@!"
    echo -e "\nMultiple file handling:\n :ls -> list files | :b(N) -> jump to file (N) | :bn / :bp -> move between files | :bd -> close current file\n"
    echo -e "Replace with autoindent                                :%s/STRING/REPLACEMENT_STRING/ |normal=\`\`"
    echo -e "Do replace on only rows between                        :ROW_START,ROW_ENDs/STRING1/STRING2/g"
    echo -e "Ignore whitespace in search                            :/STRING1_s*STRING2\n"
    echo -e "Remove all trailing whitespace                         :%s/\s\+$//e"
    echo -e "Remove all rows containing string                      :g/STRING/d"
    echo -e "Remove all rows not having STRING                      :%g!/STRING/d"
    echo -e "Remove everything after string                         :%s/STRING.*g"
    echo    "Remove carriage return ^M                              :%s/\\r//\n"
    echo -e "Special search options                                 :\\+ repeat given string | \$ end of the line\n"
    echo -e "ctrl+v -> paint all rows -> g -> ctrl+a (to increment all values)"
    echo -e "ctrl+v -> paint all rows / test -> c -> write new text to replace painted text -> esc\n"
    echo -e "search for rows longer than LEN                        \\%>LENv.\\+"
    echo -e "search for rows less than LEN                          ^.\\{,LEN}$/"
    echo -e "search for rows not ending in STRING                   ^.*\\(STRING\\)\\@<!$"
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

pritCerts () {
    echo -e "openssl pkcs12 -in TB4Alpha.slclab.int.p12 -nokeys -clcerts -out cert.pem -passin pass:TB4Alpha.slclab.int"
    echo -e "openssl x509 -in cert.pem -text\n"
    echo -e "cp /mnt/mtd7/trs-1/pkcs11.conf /var/lib/lxc/trs-1/rootfs/etc/strongswan.d/charon/pkcs11.conf"
    echo -e "cp /mnt/mtd7/trs-1/pkcs11.conf /usr/share/strongswan/templates/config/plugins/pkcs11.conf"
    echo -e "cp /etc/softhsm2.conf /var/lib/lxc/trs-1/rootfs/etc/softhsm2.conf"
    echo -e "systemctl start strongswan-swanctl"
    echo -e "swanctl --reload-settings          'this should happen by config agent'"
}

printSHM () {
    echo -e "softhsm2-util --show-slots;"
    echo -e "pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --login --pin VwYTbAH7dYk4F --list-objects"
    echo -e "cat /mnt/crypted-disk/softhsm.secrets\n"
    echo -e "delete everything in /mnt/crypted-disk/ and then run       config-syscreds --pki import"
}

printAwk () {
    echo -e "Print all logged users     who | awk '{cmd=\"echo \"\$1}; system(cmd)'"
    echo -e "Logout all logged users    who | awk '\$1 !~ /root/{ cmd=\"/sbin/pkill -KILL -u \" \$1; system(cmd)}'"
}

printBash () {
    echo -en "Get size of array             \${#ARRAY[@]}\n"
    echo -en "Get length of string          \${#STRING}\n"
    echo -en "Remove string beginning       \${STRING:POS}\n"
    echo -en "Get substring                 \${STRING:POS:EPOS}\n"
    echo -en "Split string, get start       \${STRING%.*}\n"
    echo -en "Split string, get end         \${STRING##*.}\n"
    echo -en "Replace all substrings        \${STRING//SUBS/REPLACEMENT}\n\n"
    echo -en "Loop array                    for ITEM_STRING in \"\${ARRAY[@]}\"; do -> done\n"
    echo -en "Loop array with value         for ITEM_VALUE in \"\${!ARRAY[@]}\"; do -> done\n"
    echo -en "Get array item with value     \${ARRAY[index]}\n\n"
    echo -en "Split string into array       ARRAY=(\${STRING//,/\$IFS})\n"
    echo -en "Set IFS for enter             NEW_LINE=$'\\\x0A'; export IFS="\${NEW_LINE}";\n\n"
    echo -en "Find all file extensions      find . -type f -name '*.*' | sed 's|.*\.||' | sort -u\n"
}

if [ "$1" == "grep" ]; then
    printGrep
elif [ "$1" == "vi" ] || [ "$1" == "vim" ]; then
    printVim
elif [ "$1" == "git" ]; then
    printGit
elif [ "$1" == "yocto" ] || [ "$1" == "yoki" ] || [ "$1" == "cgx" ]; then
    printYocto
elif [ "$1" == "cmake" ]; then
    printCmake
elif [ "$1" == "certs" ]; then
    pritCerts
elif [ "$1" == "ipsec" ]; then
    printSHM
elif [ "$1" == "awk" ]; then
    printAwk
elif [ "$1" == "bash" ]; then
    printBash
else
    echo -e "Choose: grep / vi / git / yocto / cmake / debug / tulips / dxt / tb3 / certs / ipsec / vgem / jira / awk / bash / reg / test"
fi
