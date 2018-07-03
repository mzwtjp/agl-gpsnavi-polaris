#!/bin/bash

#INFILE=../data/uk/PARCEL.txt
#INFILE=../data/uk/PARCEL_100.txt
INFILE=../data/uk/PARCEL_500.txt
DECODE=../tools/parcel-blob-decode.sh

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

checkblob() {
  echo "# check blob $1"
  echo "# $2"
  if [ "$2" != "NULL" ]; then
    $DECODE -k "$1" "$2"
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

