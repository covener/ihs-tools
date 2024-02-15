#!/bin/bash 

if [ $# -ne 1 ]; then
  echo "$0 /path/to/key.kdb"
  exit 1
fi

KDB=$1
KDB_DIR=$(dirname $1)
KDB_NOEXT=${KDB%.kdb}
KDB_FNAME_NOEXT=$(basename $KDB .kdb)
KDB_FNAME=$(basename $KDB)

rm -f temp.*

if test -f $KDB_NOEXT-orig.kdb; then
  echo "Backup $KDB_NOEXT-orig.kdb already exists, remove or make a copy of $1 to proceed"
  exit 1
fi

if test -f ${KDB_NOEXT}.kdb; then
  echo "Final KDB ${KDB_NOEXT}.kdb already exists in working directory, move it aside or change directory"
  exit 1
fi

if ! which gskcapicmd >/dev/null; then
    echo "Need to put gskcapicmd  in PATH"
    exit 1
fi

gskcapicmd -keydb -create -db temp.kdb -stash -pqc false -prompt
gskcapicmd -cert -export -db $KDB -stashed -target temp.kdb

if rename --help 2>&1 | grep perlexpr >/dev/null; then
  rename -e "s/$KDB_FNAME_NOEXT(?=\.[a-z]{3})/$KDB_FNAME_NOEXT-orig/"  $KDB_NOEXT.*
  rename "s/temp/$KDB_FNAME_NOEXT/" temp.*
else
  rename $KDB_FNAME_NOEXT. $KDB_FNAME-orig. $KDB_NOEXT.*
  rename temp $KDB_NOEXT temp.*
fi

echo "The converted KDB is $PWD/${KDB_NOEXT}.kdb" 
