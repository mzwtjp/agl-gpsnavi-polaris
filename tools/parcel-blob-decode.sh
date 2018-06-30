#!/bin/bash

usage_exit() {
  echo "Usage: parcel-blob [-d] [-e] [-k kind] [blob]
Interpret blob data in PARCEL table.

-d	decode
-e	encode
-k	type of blob
blob	blob data in hex string notation
 
Kind ids recognized:

ROAD
SHAPE
GUIDE
BKGD
NAME
ROAD_NAME
BKGD_NAME
CHARSTR
DENSITY
MARK
PARCEL_BASIS
BKGD_AREA_CLS
"
  exit 1
}

BLOB="06000100EEE3010030E50100196001001960010001008801"
KIND="PARCEL_BASIS"
VERBOSE=
ZLIBFLATE="zlib-flate -uncompress"
#ZLIBFLATE="openssl zlib -d"

while getopts k:hv OPT
do
  case $OPT in
    k)
      KIND=$OPTARG
      ;;
    v)
      VERBOSE=1
      ;;
    *)
      usage_exit
      ;;
  esac
done

shift $((OPTIND -1))

if [ ! -z "$1" ]; then
  BLOB="$1"
fi

SE16() {
  echo "${1:2:2}${1:0:2}"
}
SE32() {
  echo "${1:6:2}${1:4:2}${1:2:2}${1:0:2}"
}

strunpack() {
  xxd -r -p <<EOF | tr -d '\000'
$1
EOF
}

unzip_str() {
#  xxd -p -r <<EOF | zlib-flate -uncompress | xxd -p | tr -d '\n'
  xxd -p -r <<EOF | $ZLIBFLATE | xxd -p | tr -d '\n'
$1
EOF
}


decode_PARCEL_BASIS() {
  echo "# PARCEL_BASIS"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  N=$1
  D=$2

  X_TOP="0x`SE32 ${D:8:8}`"  # read 4 bytes offset 4 bytes
  X_BOTTOM="0x`SE32 ${D:16:8}`"  # " offset 8
  Y_LEFT="0x`SE32 ${D:24:8}`"  # " offset 12
  Y_RIGHT="0x`SE32 ${D:32:8}`"  # " offset 16

  printf 'X_TOP: 0x%X\n' $X_TOP
  printf 'X_BOTTOM: 0x%X\n' $X_BOTTOM
  printf 'Y_LEFT: 0x%X\n' $Y_LEFT
  printf 'Y_RIGHT: 0x%X\n' $Y_RIGHT
}

decode_ROAD_SHAPE() {
  echo "# ROAD_SHAPE"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
}
decode_ROAD_NETWORK() {
  echo "# ROAD_NETWORK"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
}
decode_BKGD() {
  echo "# BKGD"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
}
decode_BKGD_AREA_CLS() {
  echo "# BKGD_AREA_CLS"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
}
decode_MARK() {
  echo "# MARK"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
}

#
# ROAD_NAME
#
# See sms-core/SMCoreMP/SMRoadNameAnalize.cpp
#
# UINT16: RDNM_SIZE
# UINT16: RDNM_LANG_CNT
# UINT32: RDNM_ID
#
# UINT16: RLNG_SIZE
# UINT32: RNLG_LANG_KIND
# UINT16: RNLG_GUIDE_VOICE_ID
# CHAR[]: RNLG_ROUTE_NO_STR
# UINT16: RNLG_ROUTE_NAME_SIZE
# UINT8: RNLG_ROUTE_NAME_STR
# UINT16: RNLG_ROUTE_YOMI_SIZE
# UINT8: RNLG_ROUTE_YOMI_STR

decode_RNLG() {
  D=$1

  RNLG_SIZE="`SE16 ${D:0:4}`"
  RNLG_LANG_KIND="${D:4:2}"
#  RNLG_GUIDE_VOICE_ID="0x`SE32 ${D:8:8}`"

  printf 'RNLG_SIZE=%d\n' $RNLG_SIZE
  printf 'RNLG_LANG_KIND=%d\n' $RNLG_LANG_KIND
#  printf 'RNLG_GUIDE_VOICE_ID=0x%X\n' $RNLG_GUIDE_VOICE_ID

#  echo "XXX=${D:8}"

  RNLG_ROUTE_NO_SIZE="0x`SE16 ${D:8:4}`"
  RNLG_ROUTE_NO_SIZE=$((($RNLG_ROUTE_NO_SIZE + 1)/2*2))
  RNLG_ROUTE_NO_STR="${D:12:$(($RNLG_ROUTE_NO_SIZE*2))}"

  D="${D:$((12+$RNLG_ROUTE_NO_SIZE*2))}"
  RNLG_ROUTE_NAME_SIZE="0x`SE16 ${D:0:4}`"
  RNLG_ROUTE_NAME_STR="${D:4:$(($RNLG_ROUTE_NAME_SIZE*2))}"

  printf 'RNLG_ROUTE_NO_SIZE=%d\n' $RNLG_ROUTE_NO_SIZE
  printf 'RNLG_ROUTE_NO_STR=%s ("%s")\n' $RNLG_ROUTE_NO_STR "`strunpack $RNLG_ROUTE_NO_STR`"
  printf 'RNLG_ROUTE_NAME_SIZE=%d\n' $RNLG_ROUTE_NAME_SIZE
  printf 'RNLG_ROUTE_NAME_STR=%s ("%s")\n' $RNLG_ROUTE_NAME_STR "`strunpack $RNLG_ROUTE_NAME_STR`"
}

decode_RDNM() {
  D=$1

  RDNM_SIZE="`SE16 ${D:0:4}`"
  RDNM_LANG_CNT="`SE16 ${D:4:4}`"
  RDNM_ID="`SE32 ${D:8:8}`"

  printf 'RDNM_SIZE=%d\n' $RDNM_SIZE
  printf 'RDNM_LANG_CNT=%d\n' $RDNM_LANG_CNT
  printf 'RDNM_ID=0x%X\n' $RDNM_ID

  decode_RNLG ${D:16}
}

decode_ROAD_NAME() {
  echo "# ROAD_NAME"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  N=$1
  D="$2"
  RDNM_CNT="`SE32 ${D:0:8}`" # 4 bytes
  printf 'RDNM_CNT=%d\n' $RDNM_CNT

  decode_RDNM ${D:8}
}

#
# NAME
#
# src/sms/sms-core/SMCoreMP/SMNameAnalyze.cpp
#
# UINT32 NAME_CNT
# NAME ([NAME_SIZE * 4]) * NAME_CNT
#
# UINT16 NAME_SIZE
# UINT16 NAME_LNG_CNT
# UINT32 NAME_KIND
# NMLG * NAME_LNG_CNT
#

decode_NMLG() {
  D=$1

  echo "XXX=$D"

#  NAME_SIZE="0x`SE16 ${D:0:4}`"
  NAME_LNG_CNT="0x`SE16 ${D:4:4}`"
  NAME_NAME_KIND="0x`SE32 ${D:8:8}`"
  NAME_ID="0x`SE32 ${D:16:8}`"

  D=${D:24}

  echo "YYYY=$D"

  NMLG_SIZE="0x`SE16 ${D:0:4}`"
  NMLG_LANG_KIND="0x${D:4:2}"
  NMLG_INFO1="`SE32 ${D:8:8}`"
  NMLG_X="0x`SE16 ${D:16:4}`"
  NMLG_Y="0x`SE16 ${D:20:4}`"
  NMLG_OFS_X="0x${D:24:2}"
  NMLG_OFS_Y="0x${D:26:2}"
  NMLG_STR_SIZE="0x`SE16 ${D:28:4}`"
  NMLG_STR="${D:32:$(($NMLG_STR_SIZE * 2))}"

#  printf 'NAME_SIZE=%d\n' $NAME_SIZE
  printf 'NAME_LNG_CNT=%d\n' $NAME_LNG_CNT
  printf 'NAME_NAME_KIND=0x%X\n' $NAME_NAME_KIND
  printf 'NAME_ID=0x%X\n' $NAME_ID

  printf 'NMLG_SIZE=%d\n' $NMLG_SIZE
  printf 'NMLG_LANG_KIND=%d\n' $NMLG_LANG_KIND
  printf 'NMLG_INFO1=0x%X\n' $NMLG_INFO1
  printf 'NMLG_X=0x%X\n' $NMLG_X
  printf 'NMLG_Y=0x%X\n' $NMLG_Y
  printf 'NMLG_OFS_X=0x%X\n' $NMLG_OFS_X
  printf 'NMLG_OFS_Y=0x%X\n' $NMLG_OFS_Y
  printf 'NMLG_STR_SIZE=%d\n' $NMLG_STR_SIZE
  printf 'NMLG_STR=%s ("%s")\n' $NMLG_STR "`strunpack $NMLG_STR`"
}

decode_NAME() {
  echo "# NAME"
  [ -n "$VERBOSE" ] && echo "# $1 $2"

  N=$1
  D="$2"
  NAME_CNT="0x`SE32 ${D:0:8}`" # 4 bytes
  printf 'NAME_CNT=%d\n' $NAME_CNT
  D=${D:8}

  for ((i=0;i<$NAME_CNT;i++)); do
    printf 'i=%d\n' $i

    NAME_SIZE="0x`SE16 ${D:0:4}`"
D2=$D
    decode_NMLG ${D}
D=$D2
    D=${D:$(($NAME_SIZE * 2 * 4))}
  done
}

decode_GUIDE() {
  echo "# GUIDE"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
}
decode_ROAD_DENSITY() {
  echo "# ROAD_DENSITY"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
}

#[ -n "$VERBOSE" ] && echo "KIND=$KIND"
#[ -n "$VERBOSE" ] && echo "BLOB=$BLOB"

DHC_VOLUM_INFO="0x`SE32 ${BLOB:0:8}`" # 4 bytes

echo "DHC_VOLUM_INFO: $DHC_VOLUM_INFO"
SIZE="$(())"
COMP="$((($DHC_VOLUM_INFO & 0xE0000000) >> 29))"
SIZE="$((($DHC_VOLUM_INFO & ~0xE0000000)))"

printf 'COMP=0x%X\n' $COMP
printf 'SIZE=0x%X\n' $SIZE

DATA=${BLOB:8}
echo "DATA=$DATA"
if [ "$COMP" == "1" ]; then
  DATA=`unzip_str $DATA`
  echo "DATA2=$DATA"
fi
SIZE2=$((${#DATA} / 8))
printf 'SIZE2=0x%X (0x%X)\n' $SIZE2 ${#DATA}

case $KIND in
  "PARCEL_BASIS")
    #decode_PARCEL_BASIS $SIZE $DATA
    decode_PARCEL_BASIS $SIZE2 $DATA
    ;;
  "ROAD_SHAPE")
    decode_ROAD_SHAPE $SIZE $DATA
    ;;
  "ROAD_NETWORK")
    decode_ROAD_NETWORK $SIZE $DATA
    ;;
  "BKGD")
    decode_BKGD $SIZE $DATA
    ;;
  "BKGD_AREA_CLS")
    decode_BKGD_AREA_CLS $SIZE $DATA
    ;;
  "MARK")
    decode_MARK $SIZE $DATA
    ;;
  "ROAD_NAME")
    decode_ROAD_NAME $SIZE $DATA
    ;;
  "NAME")
    decode_NAME $SIZE $DATA
    ;;
  "GUIDE")
    decode_GUIDE $SIZE $DATA
    ;;
  "ROAD_DENSITY")
    decode_DENSITY $SIZE $DATA
    ;;
  *)
    ;;
esac
