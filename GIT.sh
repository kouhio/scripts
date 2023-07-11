#!/bin/bash

if [ -z "$1" ]; then
    ${GIT} --help
    echo -en "\nAdditional:\n"
    echo "   delete 'branchname'    delete remote and local branches"
    echo "   push                   automatically push to remote branch"
    echo "   pull                   automatically pull to remote branch"
    echo "   debug 'message'        commit all and push to remote branch, last commit if no message set"
    echo "   grep 'string'          grep logs for wanted string"
    echo "   remote                 update remote repositories"
    echo "   reset 'soft'           reset branch to remote hard or soft if second command"
    echo "   force 'force'          push to origin/branch, if other input is set, uses --force"
    exit
fi

GIT="/usr/bin/git"
REMOTE=$(${GIT} config --get remote.origin.url)
BRANCH=$(${GIT} branch |grep "\*")
BRANCH="${BRANCH##*\* }"

if [[ "$REMOTE" =~ "gerrit" ]]; then REMOTE=1;
else REMOTE=0; fi

##############################################################################################
if [ "$1" == "delete" ]; then
    [ -z "$2" ] && echo "No branch given!" && exit
    [[ "$2" =~ "master" ]] && echo "Do not delete master ($2) branch!" && exit

    BRANCH=$(${GIT} branch -a)
    if [ "$REMOTE" -eq "0" ]; then
        if [[ "$BRANCH" =~ "/$2" ]]; then ${GIT} push origin --delete "$2"
        else echo "No branch '$2' found! Cannot remote delete!"; fi

    else echo "Cannot delete remote from gerrit!"; fi

    if [[ "$BRANCH" =~ "$2" ]]; then ${GIT} branch -D "$2"
    else echo "No branch '$2' found! Cannot locally delete!"; fi

##############################################################################################
elif [ "$1" == "push" ] && [ -z "$2" ] || [ "$2" == "ignore" ]; then
    [[ "$BRANCH" =~ "HEAD detached" ]] && echo "Cannot push detached head!" && exit 1

    if [ "$REMOTE" -eq "1" ]; then
        LOG=$(${GIT} log -1 | grep Change-Id -c)
        [ "$2" == "ignore" ] && LOG=1

        if [ "$LOG" -eq "1" ]; then ${GIT} push
        else echo "Too many Change-Id's! Won't push with '$LOG' items! Fix commit!"; fi

    else ${GIT} push origin $BRANCH ; fi

##############################################################################################
elif [ "$1" == "pull" ]; then
    [[ "$BRANCH" =~ "HEAD detached" ]] && echo "Cannot pull detached head!" && exit 1

    #FETCH=$(${GIT} fetch)
    #[ -z "$FETCH" ] && [ -z "$2" ] && echo "Nothing to pull!" && exit 1

    STATUS=$(${GIT} status)
    [[ "$STATUS" =~ "Changes not staged for commit" ]] && [ -z "$2" ] && echo "Not all is committed! Not pulling!" && exit 1

    ${GIT} pull
    ${GIT} pull origin $BRANCH

##############################################################################################
elif [ "$1" == "debug" ]; then
    if [ "$BRANCH" != "master" ]; then
        COMMIT=$(${GIT} log -1 --pretty=%B | head -n 1)
        if [ -z "$2" ]; then ${GIT} commit -a -m "$COMMIT"
        else  ${GIT} commit -a -m "$2"; fi

        if [ "$REMOTE" -eq "1" ]; then ${GIT} push
        else ${GIT} push origin $BRANCH; fi

    else echo "Cannot debug with master branch!"; fi

##############################################################################################
elif [ "$1" == "grep" ] && [ ! -z "$2" ]; then
    ${GIT} log --grep="$2"

##############################################################################################
elif [ "$1" == "remote" ]; then
    ${GIT} remote update origin --prune

##############################################################################################
elif [ "$1" == "reset" ]; then
    if [ -z "$2" ]; then ${GIT} reset --hard origin/${BRANCH}
    else ${GIT} reset --soft origin/${BRANCH}; fi

##############################################################################################
elif [ "$1" == "force" ]; then
    if [ -z "$2" ]; then ${GIT} push origin $BRANCH
    else ${GIT} push --force origin $BRANCH; fi

    ${GIT} pull
    ${GIT} pull origin $BRANCH

else
    ${GIT} $@
fi
