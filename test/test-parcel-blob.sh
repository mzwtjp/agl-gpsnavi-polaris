#!/bin/bash

usage_exit() {
  echo "Usage: test-parcel-blob.sh [-r] [-d cmd] [-e cmd] [parcel.txt]

-r		Round-trip.  Compare original blob with decoded and again encoded output.
-d		Specify decode script.  Default $DECODE.
-e		Specify encode script.  Default $ENCODE.
parcel.txt	.dump output of PARCEL table.
" 1>&2
  exit 1
}

#INFILE=../data/uk/PARCEL.txt
#INFILE=../data/uk/PARCEL_100.txt
INFILE=../data/uk/PARCEL_500.txt
#INFILE=../data/jp/PARCEL_500.txt
DECODE=../tools/parcel-blob-decode.sh
ENCODE=../tools/parcel-blob-encode.sh

TMP_ENC=./tmp-enc.txt
TMP_DEC=./tmp-dec.txt
FLG_RT=

while getopts d:e:hr OPT
do
  case $OPT in
    r)
      FLG_RT=1
      ;;
    h)
      usage_exit
      ;;
  esac
done
shift $((OPTIND - 1))

if [  -n "$1" ]; then
  INFILE=$1
fi

#  PARCEL_ID INTEGER NOT NULL,
#  PARCEL_BASIS BLOB NOT NULL,
#  ROAD_SHAPE BLOB,
#  ROAD_NETWORK BLOB,
#  BKGD BLOB,
#  BKGD_AREA_CLS BLOB,
#  MARK BLOB,
#  ROAD_NAME BLOB,
#  NAME BLOB,
#  GUIDE BLOB,
#  ROAD_DENSITY BLOB,
#  ROAD_BASE_VERSION INTEGER,
#  BKGD_BASE_VERSION INTEGER,
#

checkblob() {
  echo "# check blob $1"
  echo "# $2"
  if [ "$2" == "NULL" ]; then
    return
  fi

  local TYPE=$1
  local BLOB_IN=$2
  local BLOB_OUT

  if [ "$FLG_RT" != "" ]; then
    rm -f $TMPFILE
    $DECODE -k "$TYPE" "$BLOB_IN" | tee $TMP_DEC
    cat $TMP_DEC | $ENCODE -k "$TYPE" | tee $TMP_ENC
    BLOB_OUT="X'"
    BLOB_OUT+="`grep '^BLOB_OUT' $TMP_ENC | sed 's/^BLOB_OUT=//'`"
    BLOB_OUT+="'"
    
    echo "# BLOB_IN=$BLOB_IN"
    echo "# BLOB_OUT=$BLOB_OUT"
    printf '# VERIFY: '
    if [ "$BLOB_IN" == "$BLOB_OUT" ]; then
        printf 'OK\n'
    else
        printf 'NG\n'
    fi
  else
    $DECODE -k "$TYPE" "$BLOB_IN"
  fi
}

process() {
  L="$1"
  L="`echo $L | sed 's/^INSERT .*(\(.*\));/\1/'`"
  IFS=',' read -r -a array <<< "$L"

echo "L=$L"

  echo "PARCEL_ID=${array[0]}"
  checkblob "PARCEL_BASIS" "${array[1]}"
  checkblob "ROAD_SHAPE" "${array[2]}"
  checkblob "ROAD_NETWORK" "${array[3]}"
  checkblob "BKGD" "${array[4]}"
  checkblob "BKGD_AREA_CLS" "${array[5]}"
  checkblob "MARK" "${array[6]}"
  checkblob "ROAD_NAME" "${array[7]}"
  checkblob "NAME" "${array[8]}"
  checkblob "GUIDE" "${array[9]}"
  checkblob "ROAD_DENSITY" "${array[10]}"
  echo "ROAD_BASE_VERSION=${array[11]}"
  echo "BKGD_BASE_VERSION=${array[12]}"
}

# note: check your sqlite3 output data so that the pattern string
# below matches with yours

#PAT='^INSERT INTO PARCEL VALUES('
PAT='^INSERT INTO "PARCEL" VALUES('

CNT=0
grep "$PAT" $INFILE | \
    while read -r line ; do
  echo "Processing $line"
  process "$line"
  CNT=$(($CNT+1))
  echo "$CNT records."
done

echo "Done."

