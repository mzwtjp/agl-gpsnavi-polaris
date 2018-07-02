#!/bin/bash

usage_exit() {
  echo "Usage: parcel-blob-decode [-k kind] [blob]
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

INV32="0xffffffff"

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

stripx() {
  T="$1"
  if [ "X'" == "${T:0:2}" ]; then
    T="${T:2}"
    T="${T:0:$((${#T}-1))}"
  fi
  echo "$T"
}

notReady() {
  echo "# NOT IMPLEMENTED!!"
}


#
# PARCEL_BASIS
#
# See SMRoadShapeAnalyze.cpp
#

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

#
# ROAD_SHAPE
#
# UINT16 ALL_SHAPE_CNT
#
# xxx OFS
#

decode_ROAD_SHAPE_DATA() {
  SD=$D # save
  D="$1"
echo "SHAPE_DATA=$D"

  SHAPE_DATA_SIZE="0x`SE32 ${D:0:8}`"
  SHAPE_DATA_SIZE="$(($SHAPE_DATA_SIZE * 4))"
  SHAPE_DATA_CNT="0x`SE32 ${D:8:8}`"

  printf 'SHAPE_DATA_SIZE=%d\n' $SHAPE_DATA_SIZE
  printf 'SHAPE_DATA_CNT=%d\n' $SHAPE_DATA_CNT

  RDSP="${D:16}" # 8 x 2
echo "RDSP=$RDSP"
#  for ((i=0; i < $SHAPE_DATA_CNT;i++));do
#    T="0x`SE16 ${RDSP:0:4}`"
#    T=$(($T * 4))
#    echo "RDSP[$i]=${RDSP:0:$(($T * 2))}"
#    RDSP="${RDSP:$(($T * 2))}"
#  done

  D=$SD # restore
}

decode_ROAD_SHAPE() {
  echo "!! ROAD_SHAPE"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  SD="$D" # save

  D="$2"
echo "SHAPE=$D"

  OFS="0x`SE32 ${D:$(((4 + 64) * 2)):8}`"
echo "OFS=$OFS"
  LINK_INDEX="${D:$((($OFS * 4) * 2))}"
echo "LINK_INDEX=$LINK_INDEX"
  LINKCNT="0x`SE32 ${LINK_INDEX:$((4 * 2)):8}`"

echo "LNKCNT=$LINKCNT"

  SHAPEINDEX="0x`SE32 ${LINK_INDEX:$((8 * 2)):8}`"

echo "D=$D"

  ALL_SHAPE_CNT="0x`SE32 ${D:0:4}`"

  printf 'ALL_SHAPE_CNT=%d\n' $ALL_SHAPE_CNT
  printf 'LINKCNT=%d\n' $LINKCNT

# ROAD_KIND_CNT_MAX 16
  ROAD_TYPE_OFS=()
  for ((i=0;i<16;i++));do
    ROAD_TYPE_OFS[$i]="0x`SE32 ${D:$(($i * 4 * 2)):8}`"
  done

  echo "ROAD_TYPE_OFS=${ROAD_TYPE_OFS[@]}"

  for ((i=0;i<16;i++));do

printf 'ROAD_TYPE_OFS[%d]=%d\n' $i ${ROAD_TYPE_OFS[$i]}
T=${ROAD_TYPE_OFS[$i]}
   [ "$T" == $INV32  ] && continue
    echo "CALL decode_ROAD_SHAPE_DATA i=$i"
    echo "T=$(($T * 4 * 2))"
    echo "P1=${D:$(($T * 4 * 2))}"
    decode_ROAD_SHAPE_DATA "${D:$(($T * 4 * 2))}"
  done

  D="$SD" # restore
}

#
# ROAD_NETWORK
#
# sms/sms-core/SMCoreDAL/SMMAL.h
#
# 8 BYTE[] RNET_DIR
#
# (RNET_DIR)
# 4 UINT32 NWLINK_OFS
# 8 UINT32 NWCNCT_OFS
# 12 UINT32 NWLINKEX_OFS
# 16
# 18 UINT32 NWCNTEX_OFS
# 20 UINT32 LINKREG_OFS
# 24 UINT32 IDXLINK_OFS
# 28 UINT32 IDXCNCT_OFS
#
# (LINK_DATA)
# 0 UINT32 LINK_DATA_SIZE
# 4 UINT32 LINK_RECORD_VOL
# 8 BYTE[44]*N LINK_RECORD
#
# (CNCT_DATA)
# 0 UNIT32 CNCT_DATA_SIZE
# 4 UINT32 CNCT_RECORD_VOL
# 8 BYTE[28]*N CNCT_RECORD
#
# (LINKEX_DATA)
# 0 UINT342 LINKEX_DATA_SIZE
# 4 UINT32 LINKEX_RECORD_VOL
# 8 BYTE[]*N LINKEX_RECORD
#
# (IDXLINK)
# 0 UINT342 IDXLINK_DATA_SIZE
# 4 UINT32 IDXLINK_RECORD_VOL
# 8 UINT16*N IDXLINK_RECORD
#
# (IDXCNCT)
# 0 UINT342 IDXCNCT_DATA_SIZE
# 4 UINT32 IDXCNCT_RECORD_VOL
# 8 UINT16*N IDXCNCT_RECORD
#

decode_NWLINK() {
  local D=$1
  local N="0x`SE32 ${D:0:8}`"
  local RECORD_VOL="0x`SE32 ${D:8:8}`"

  printf '# NWLINK\n'
  printf '# N=%d\n' $N
  printf '# RECORD_VOL=%d\n' $RECORD_VOL
  #printf '# RECORD=%s\n' ${D:16}
  printf '# RECORD=%s\n' ${D:16:$((N * 8 - 16))}
  for ((i=0;i<$RECORD_VOL;i++)); do
    # record size 44
    printf 'NWLINK[%d]=%s\n' $i ${D:$((16 + 88 * $i)):88}
  done
}

decode_NWCNCT() {
  local D=$1
  local N="0x`SE32 ${D:0:8}`"
  local RECORD_VOL="0x`SE32 ${D:8:8}`"

  printf '# NWCNCT\n'
  printf '# N=%d\n' $N
  printf '# RECORD_VOL=%d\n' $RECORD_VOL
  #printf '# RECORD=%s\n' ${D:16}
  printf '# RECORD=%s\n' ${D:16:$((N * 8 - 16))}
  for ((i=0;i<$RECORD_VOL;i++)); do
    # record size 28
    printf 'NWCNCT[%d]=%s\n' $i ${D:$((16 + 56 * $i)):56}
  done
}

decode_NWLINKEX() {
  printf '# NWLINKEX\n'
  notReady
}
decode_NWCNTEX() {
  printf '# NWCNTEX\n'
  notReady
}
decode_LINKREG() {
  printf '# LINKREG\n'
  notReady
}

decode_IDXLINK() {
  local D=$1
  local N="0x`SE32 ${D:0:8}`"
  local RECORD_VOL="0x`SE32 ${D:8:8}`"

  printf '# IDXLINK\n'
  printf '# N=%d\n' $N
  printf '# RECORD_VOL=%d\n' $RECORD_VOL
  #printf '# RECORD=%s\n' ${D:16}
  printf '# RECORD=%s\n' ${D:16:$((N * 8 - 16))}
  for ((i=0;i<$RECORD_VOL;i++)); do
    # record size 2
    echo "${D:$((16 + 4 * $i)):4}"
    printf 'IDXLINK[%d]=%d\n' $i "0x`SE16 ${D:$((16 + 4 * $i)):4}`"
  done
}

decode_IDXCNCT() {
  local D=$1
  local N="0x`SE32 ${D:0:8}`"
  local RECORD_VOL="0x`SE32 ${D:8:8}`"

  printf '# IDXLINK\n'
  printf '# N=%d\n' $N
  printf '# RECORD_VOL=%d\n' $RECORD_VOL
  #printf '# RECORD=%s\n' ${D:16}
  printf '# RECORD=%s\n' ${D:16:$((N * 8 - 16))}
  for ((i=0;i<$RECORD_VOL;i++)); do
    # record size 2
    echo "${D:$((16 + 4 * $i)):4}"
    printf 'IDXCNCT[%d]=%d\n' $i "0x`SE16 ${D:$((16 + 4 * $i)):4}`"
  done
}

decode_RNET_DIR() {
  local D=$1

  NWLINK_OFS="0x`SE32 ${D:8:8}`"
  NWCNCT_OFS="0x`SE32 ${D:16:8}`"
  NWLINKEX_OFS="0x`SE32 ${D:24:8}`"
  NWCNCTEX_OFS="0x`SE32 ${D:32:8}`"
  LINKREG_OFS="0x`SE32 ${D:40:8}`"
  IDXLINK_OFS="0x`SE32 ${D:48:8}`"
  IDXCNCT_OFS="0x`SE32 ${D:56:8}`"
}

decode_ROAD_NETWORK() {
  echo "# ROAD_NETWORK"
  [ -n "$VERBOSE" ] && echo "# $1 $2"

  local D=$2

  decode_RNET_DIR ${D:8}

  printf 'NWLINK_OFS=%d\n' $NWLINK_OFS
  printf 'NWCNCT_OFS=%d\n' $NWCNCT_OFS
  printf 'NWLINKEX_OFS=%d\n' $NWLINKEX_OFS
  printf 'NWCNCTEX_OFS=%d\n' $NWCNCTEX_OFS
  printf 'LINKREG_OFS=%d\n' $LINKREG_OFS
  printf 'IDXLINK_OFS=%d\n' $IDXLINK_OFS
  printf 'IDXCNCT_OFS=%d\n' $IDXCNCT_OFS

  if [ "$INV32" != $NWLINK_OFS ]; then
    printf 'NWLINK=%s\n' ${D:$(($NWLINK_OFS * 2 * 4))}
    decode_NWLINK ${D:$(($NWLINK_OFS * 2 * 4))}
  fi
  if [ "$INV32" != $NWCNCT_OFS ]; then
    printf 'NWCNCT=%s\n' ${D:$(($NWCNCT_OFS * 2 * 4))}
    decode_NWCNCT ${D:$(($NWCNCT_OFS * 2 * 4))}
  fi
  if [ "$INV32" != $NWLINKEX_OFS ]; then
    printf 'NWLINKEX=%s\n' ${D:$(($NWLINKEX_OFS * 2 * 4))}
    decode_NWLINKEX ${D:$(($NWLINKEX_OFS * 2 * 4))}
  fi
  if [ "$INV32" != $NWCNCTEX_OFS ]; then
    printf 'NWCNCTEX=%s\n' ${D:$(($NWCNCTEX_OFS * 2 * 4))}
    decode_NWCNCTEX ${D:$(($NWCNCTEX_OFS * 2 * 4))}
  fi
  if [ "$INV32" != $LINKREG_OFS ]; then
    printf 'LINKREG=%s\n' ${D:$(($LINKREG_OFS * 2 * 4))}
    decode_LINKREG ${D:$(($LINKREG_OFS * 2 * 4))}
  fi
  if [ "$INV32" != $IDXLINK_OFS ]; then
    printf 'IDXLINK=%s\n' ${D:$(($IDXLINK_OFS * 2 * 4))}
    decode_IDXLINK ${D:$(($IDXLINK_OFS * 2 * 4))}
  fi
  if [ "$INV32" != $IDXCNCT_OFS ]; then
    printf 'IDXCNCT=%s\n' ${D:$(($IDXCNCT_OFS * 2 * 4))}
    decode_IDXCNCT ${D:$(($IDXCNCT_OFS * 2 * 4))}
  fi
}

#
# BKGD
#

decode_BKGD() {
  echo "!! BKGD"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  SD=$D # save
  D=$2

echo "D=$D"

  BKGD_CNT="0x`SE32 ${D:0:8}`"

  printf 'BKGD_CNT=%d\n' $BKGD_CNT

  D="${D:8}"
  for ((i=0;i<$BKGD_CNT;i++)); do
    N="0x`SE16 ${D:0:4}`"
    N=$(($N * 2 * 4))

echo "BKGD[$i]=${D:0:$N}"

    D=${D:${N}}
  done

  D=$SD
}

#
# BKGD_AREA_CLS
#

decode_BKGD_AREA_CLS() {
  echo "# BKGD_AREA_CLS"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  notReady
}

#
# MARK
#
# See sms/sms-core/SMCoreMP/SMMarkAnalyze.cpp
#

decode_MARK() {
  echo "!! MARK"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  SD=$D
  D="$2"

  MARK_CNT="0x`SE32 ${D:0:8}`"
  printf 'MARK_CNT=%d\n' $MARK_CNT

  D="${D:8}"
  for ((i=0;i<$MARK_CNT;i++)); do
    Z="0x`SE16 ${D:0:4}`"
    Z="$(($Z * 4 * 2))"
    echo "MARK[$i]=${D:0:$Z}"
    D="${D:$Z}"
  done 

  D=$SD
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

  RNLG_SIZE="0x`SE16 ${D:0:4}`"
  RNLG_LANG_KIND="0x${D:4:2}"
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

  RDNM_SIZE="0x`SE16 ${D:0:4}`"
  RDNM_LANG_CNT="0x`SE16 ${D:4:4}`"
  RDNM_ID="0x`SE32 ${D:8:8}`"

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

#
# GUIDE
#

decode_GUIDE() {
  echo "# GUIDE"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  notReady
}

#
# ROAD_DENSITY
#

decode_ROAD_DENSITY() {
  echo "# ROAD_DENSITY"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  notReady
}

#[ -n "$VERBOSE" ] && echo "KIND=$KIND"
#[ -n "$VERBOSE" ] && echo "BLOB=$BLOB"

BLOB="`stripx "$BLOB"`"

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

