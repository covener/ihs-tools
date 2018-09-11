#!/bin/sh

# pstack workalike

if [ $# -lt 1 ]; then
  echo "$0 pid [gdb args]"
  echo "$0 core executable-path [gdb args]"
  exit 1
fi

PID_OR_CORE=$1
if [ -f $PID_OR_CORE ]; then
  EXE=$2
  shift
else
  if [ ! -d /proc/$PID_OR_CORE ]; then
    echo "First arg $1 does not look like a PID or core";
    exit 3
  fi
  EXE=$(readlink /proc/$PID_OR_CORE/exe)
fi

shift 

sudo gdb $EXE $PID_OR_CORE  \
    --init-eval-command "set auto-load safe-path /"     \
    --eval-command "set height 0"                  \
    --eval-command "info threads"                  \
    --eval-command "info sharedlibrary"            \
    --eval-command "thread apply all bt"           \
    "$@"                                           \
    --eval-command "detach"  --eval-command "quit" 

