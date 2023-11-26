#!/bin/bash

#Play annoying sound for $1 seconds

TIME=".5"
[ -n "$1" ] && TIME="$1"
speaker-test -t sine -f 1000 -l 1 >/dev/null 2>&1 & sleep "$TIME" && kill -9 $!
