#!/bin/bash

usage_exit() {
  echo "Usage: parcel-blob-decode [-k kind] [blob]
Interpret blob data in PARCEL table.

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
DSIZE= # debug size
ZLIBFLATE="zlib-flate -uncompress"
#ZLIBFLATE="openssl zlib -d"

readonly INV32="0xffffffff"

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

SE8() {
  echo "${1:0:2}"
}
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

NOT_READY() {
  echo "#E NOT IMPLEMENTED YET!! $1"
}


#
# PARCEL_BASIS
#
# sms/sms-core/SMCoreMP/SMParcelBasisAnalyze.h
# sms/sms-core/SMCoreDM/RT/RT_TblMain.c
# See SMRoadShapeAnalyze.cpp
#
# 0 UNIT16 PCLB_SIZE
# 2 BYTE PCLB_SEA_FLG
# 3 BYTE PCLB_AREAREC_CNT
# 4 UINT32 PCLB_REAL_LENGTH_T
# 8 UINT32 PCLB_REAL_LENGTH_B
# 12 UINT32 PCLB_REAL_LENGTH_L
# 16 UINT32 PCLB_REAL_LENGTH_R
# 20 UINT16 PCLB_COUNTRY_CODE_CNT
#

decode_PARCEL_BASIS() {
  echo "# PARCEL_BASIS"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  local D=$2

  PCLB_SIZE="0x`SE16 ${D:0:4}`"
  PCLB_SEA_FLG="0x`SE8 ${D:4:2}`"
  PCLB_AREAREC_CNT="0x`SE8 ${D:6:2}`"
  PCLB_REAL_LENGTH_T="0x`SE32 ${D:8:8}`"
  PCLB_REAL_LENGTH_B="0x`SE32 ${D:16:8}`"
  PCLB_REAL_LENGTH_L="0x`SE32 ${D:24:8}`"
  PCLB_REAL_LENGTH_R="0x`SE32 ${D:32:8}`"
  PCLB_COUNTRY_CODE_CNT="0x`SE16 ${D:40:4}`"

  printf 'PCLB_SIZE=0x%X\n' $PCLB_SIZE
  printf 'PCLB_SEA_FLG=0x%X\n' $PCLB_SEA_FLG
  printf 'PCLB_AREAREC_CNT=%d\n' $PCLB_AREAREC_CNT

  printf 'PCLB_REAL_LENGTH_T=0x%X\n# %s\n' $PCLB_REAL_LENGTH_T \
    "`echo \"scale=4; $(($PCLB_REAL_LENGTH_T)) / 10000\" | bc`"
  printf 'PCLB_REAL_LENGTH_B=0x%X\n# %s\n' $PCLB_REAL_LENGTH_B \
    "`echo \"scale=4; $(($PCLB_REAL_LENGTH_B)) / 10000\" | bc`"
  printf 'PCLB_REAL_LENGTH_L=0x%X\n# %s\n' $PCLB_REAL_LENGTH_L \
    "`echo \"scale=4; $(($PCLB_REAL_LENGTH_L)) / 10000\" | bc`"
  printf 'PCLB_REAL_LENGTH_R=0x%X\n# %s\n' $PCLB_REAL_LENGTH_R \
    "`echo \"scale=4; $(($PCLB_REAL_LENGTH_R)) / 10000\" | bc`"

  printf 'PCLB_COUNTRY_CODE_CNT=%d\n' $PCLB_COUNTRY_CODE_CNT

  COUNTRY_CODE=()
  local i
  for ((i=0;i<$PCLB_COUNTRY_CODE_CNT;i++)); do
    COUNTRY_CODE[$i]="0x`SE16 ${D:$((44 + $i * 4)):4}`"
  done
  echo "COUNTRY_CODE=${COUNTRY_CODE[@]}"

  local M=$(((20 + ((((2 + $PCLB_COUNTRY_CODE_CNT * 2) + 3) << 2) >> 2)) * 2))
  AREA_NO=()
  local i
  for ((i=0;i<$PCLB_AREAREC_CNT;i++)); do
    AREA_NO[$i]="0x`SE8 ${D:$(($M + $i * 2)):2}`"
  done
  echo "AREA_NO=${AREA_NO[@]}"
}

#
# ROAD_SHAPE
#
# sms/sms-core/SMCoreMP/SMRoadShapeAnalyze.h
# sms/sms-core/SMCoreDAL/SMMAL.h
# sms/sms-core/SMCoreRP/RP_lib.h
#
# 0 UINT16 ALL_SHAPE_CNT
# 4 UINT32*16 ROAD_TYPE_OFS
# 68 UINT32 LINK_INDEX_OFS
#
# 8 BYTE[] RSHP_DIR
#
# (RSHP_DIR)
# (T_MapShapeDir)
# 0 UINT32 RECORD15_OFS
# 4 UINT32 RECORD14_OFS
# ..
# 56 UINT32 RECORD1_OFS
# 60 UINT32 RECORD0_OFS
# 64 UINT32 INDEX_LINK_OFS
# 68 UINT32 IDX_UPLINK2_OFS
# 72 UINT32 IDX_UPLINK3_OFS
# 76 UINT32 IDX_UPLINK4_OFS
# 80 UINT32 IDX_UPLINK5_OFS
# 84 UINT32 IDX_UPLINK6_OFS
# 88 UINT32 IDX_UPLINK_OFS
#
# (RECORD)
#
# (INDEX_LINK)
# (T_MapShapeIndexRecord)
# 0 UINT32 SIZE
# 4 UINT32 LINK_VOL
# 8 UINT32*LINK_VOL LINK
#
# (LV2UPPER_IDXLINK)
#
# (UPPER_LINK)
# UPLINK_ID
#
# UINT16 ALL_SHAPE_CNT
#
# xxx OFS
#

decode_RSHP_DIR() {
  local D=$1
echo "RSHP_DIR=$D"

  RECORD15_OFS="0x`SE32 ${D:0:8}`"
  RECORD14_OFS="0x`SE32 ${D:$((4 * 2)):8}`"
  RECORD13_OFS="0x`SE32 ${D:16:8}`"
  RECORD12_OFS="0x`SE32 ${D:24:8}`"
  RECORD11_OFS="0x`SE32 ${D:32:8}`"
  RECORD10_OFS="0x`SE32 ${D:40:8}`"
  RECORD9_OFS="0x`SE32 ${D:48:8}`"
  RECORD8_OFS="0x`SE32 ${D:56:8}`"
  RECORD7_OFS="0x`SE32 ${D:64:8}`"
  RECORD6_OFS="0x`SE32 ${D:72:8}`"
  RECORD5_OFS="0x`SE32 ${D:80:8}`"
  RECORD4_OFS="0x`SE32 ${D:88:8}`"
  RECORD3_OFS="0x`SE32 ${D:96:8}`"
  RECORD2_OFS="0x`SE32 ${D:104:8}`"
  RECORD1_OFS="0x`SE32 ${D:112:8}`"
  RECORD0_OFS="0x`SE32 ${D:120:8}`"

  INDEX_LINK_OFS="0x`SE32 ${D:$((64 * 2)):8}`"

  IDX_UPLINK2_OFS="0x`SE32 ${D:$((68 * 2)):8}`"
  IDX_UPLINK3_OFS="0x`SE32 ${D:$((72 * 2)):8}`"
  IDX_UPLINK4_OFS="0x`SE32 ${D:$((76 * 2)):8}`"
  IDX_UPLINK5_OFS="0x`SE32 ${D:$((80 * 2)):8}`"
  IDX_UPLINK6_OFS="0x`SE32 ${D:$((84 * 2)):8}`"
  IDX_UPLINK_OFS="0x`SE32 ${D:$((88 * 2)):8}`"
}

decode_INDEX_LINK() {
  local D=$1
  local N="0x`SE32 ${D:0:8}`"
  local VOL="0x`SE32 ${D:8:8}`"

  printf '# INDEX_LINK\n'
  printf '# N=%d\n' $N
  printf '# VOL=%d\n' $VOL
  D=${D:0:$(($N * 8))}
  D=${D:8}
  local LINKS=()
  local i
  for ((i=0;i<$VOL;i++)); do
    LINKS[$i]="0x`SE32 ${D:0:8}`"
    D=${D:8}
  done
  echo "LINKS=${LINKS[@]}"
}

decode_LKSP() {
  printf '## decode_LKSP\n'

  local D=$1
  local DATA_SIZE="0x`SE16 ${D:0:4}`"
  local UPDATE_NO="0x`SE16 ${D:4:4}`"
  local LINK_ID="0x`SE32 ${D:8:8}`"
  local LINK_BASE_INFO1="0x`SE32 ${D:16:8}`"
  local LINK_BASE_INFO2="0x`SE32 ${D:24:8}`"
  local XX_INFO="0x`SE32 ${D:32:8}`"
  local POINT_CNT="0x`SE16 ${D:40:4}`"
  local DISP_FLG="0x`SE16 ${D:44:4}`"
  local M=$(($DATA_SIZE * 4 - 24))
  local POINT_X=()
  local POINT_Y=()
  local i
  for ((i=0;i<$POINT_CNT;i++)); do
    POINT_X[$i]="0x`SE16 ${D:$((48 + $i * 8)):4}`"
    POINT_Y[$i]="0x`SE16 ${D:$((52 + $i * 8)):4}`"
    M=$(($M - 4))
  done

  printf '# LKSP\n'
  printf 'DATA_SIZE=%d\n' $DATA_SIZE
  printf 'UPDATE_NO=%d\n' $UPDATE_NO
  printf 'LINK_ID=0x%X\n' $LINK_ID
  printf 'LINK_BASE_INFO1=0x%X\n' $LINK_BASE_INFO1
  printf '# BYPASS_FLG=%d\n' $(($LINK_BASE_INFO1 & 1))
  printf '# TOLL_FLG=%d\n' $((($LINK_BASE_INFO1 >> 1) & 1))
  printf '# IPD_FLG=%d\n' $((($LINK_BASE_INFO1 >> 2) & 1))
  printf '# PLAN_ROAD=%d\n' $((($LINK_BASE_INFO1 >> 3) & 1))
  printf '# UTURN_LINK=%d\n' $((($LINK_BASE_INFO1 >> 4) & 1))
  printf '# UNDER_ROAD_LINK=%d\n' $((($LINK_BASE_INFO1 >> 5) & 1))
  printf '# HIGH_LEVEL_LINK=%d\n' $((($LINK_BASE_INFO1 >> 6) & 1))
  printf '# BRIDGE_LINK=%d\n' $((($LINK_BASE_INFO1 >> 7) & 1))
  printf '# TUNNEL_LINK=%d\n' $((($LINK_BASE_INFO1 >> 8) & 1))
  printf '# MEDIAN_FLG=%d\n' $((($LINK_BASE_INFO1 >> 9) & 3))
  printf '# INFRA_LINK_FLG=%d\n' $((($LINK_BASE_INFO1 >> 11) & 1))
  printf '# DTS_FLG=%d\n' $((($LINK_BASE_INFO1 >> 12) & 1))
  printf '# PASS_FLG=%d\n' $((($LINK_BASE_INFO1 >> 13) & 1))
  printf '# ONE_WAY_FLG=%d\n' $((($LINK_BASE_INFO1 >> 14) & 3))
  printf '# LINK_KIND4=%d\n' $((($LINK_BASE_INFO1 >> 16) & 3))
  printf '# LINK_KIND3=%d\n' $((($LINK_BASE_INFO1 >> 18) & 7))
  printf '# LINK_KIND2=%d\n' $((($LINK_BASE_INFO1 >> 21) & 7))
  printf '# LINK_KIND1=%d\n' $((($LINK_BASE_INFO1 >> 24) & 15))
  printf '# ROAD_KIND=%d\n' $((($LINK_BASE_INFO1 >> 28) & 15))
  printf 'LINK_BASE_INFO2=0x%X\n' $LINK_BASE_INFO2
  printf '# COUNTRY_CODE=%d\n' $(($LINK_BASE_INFO2 & 7))
  printf '# LANE_CNT=%d\n' $((($LINK_BASE_INFO2 >> 3) & 3))
  printf '# OTHER_REGULATION=%d\n' $((($LINK_BASE_INFO2 >> 5) & 1))
  printf '# MILITARY_AREA=%d\n' $((($LINK_BASE_INFO2 >> 6) & 1))
  printf '# FREEZE=%d\n' $((($LINK_BASE_INFO2 >> 7) & 1))
  printf '# FLOODED=%d\n' $((($LINK_BASE_INFO2 >> 8) & 1))
  printf '# SCHOOL_ZONE=%d\n' $((($LINK_BASE_INFO2 >> 9) & 1))
  printf '# FUNCTION_CLASS=%d\n' $((($LINK_BASE_INFO2 >> 10) & 7))
  printf '# WIDTH_CODE=%d\n' $((($LINK_BASE_INFO2 >> 13) & 7))
  printf '# LINK_LENGTH=%d\n' $((($LINK_BASE_INFO2 >> 16) & 4095))
  printf '# LINK_LENGTH_UNIT=%d\n' $((($LINK_BASE_INFO2 >> 28) & 7))
  printf '# RESERVE=%d\n' $((($LINK_BASE_INFO2 >> 31) & 1))
  printf 'XX_INFO=0x%X\n' $XX_INFO
  printf 'POINT_CNT=%d\n' $POINT_CNT
  printf 'DISP_FLG=0x%X\n' $DISP_FLG
  echo "POINT_X=${POINT_X[@]}"
  echo "POINT_Y=${POINT_Y[@]}"

  # XX_INFO
  local AREA_CLASS_FLG=$((($XX_INFO >> 25) & 3))
  local ROUTE_INFO_FLG=$((($XX_INFO >> 27) & 1))
  local HIGHER_LINK_CNT=$((($XX_INFO >> 28) & 7))
  printf 'AREA_CLASS_FLG=%d\n' $AREA_CLASS_FLG
  printf 'ROUTE_INFO_FLG=%d\n' $ROUTE_INFO_FLG
  printf 'HIGHER_LINK_CNT=%d\n' $HIGHER_LINK_CNT

  if (($ROUTE_INFO_FLG == 0)); then
    echo "# no route info"
    printf 'M=%d\n' $M
    return
  fi
   
  # uplv
  local UPLV_HDL=${D:$((48 + $i * 8))}
  if (($HIGHER_LINK_CNT > 0));then
    local UPLV=()
    for ((i=0;i<$HIGHER_LINK_CNT;i++)); do
      UPLV[$i]="0x`SE32 ${UPLV_HDL:$(($i * 8)):8}`"
      M=$(($M - 4))
    done
    echo "UPLV=${UPLV[@]}"
  fi

  # route
  local ROUT_HDL=${UPLV_HDL:$(($HIGHER_LINK_CNT * 8))}
  local ROUT_CNT="0x`SE16 ${ROUT_HDL:0:4}`"
  printf 'ROUT_CNT=%d\n' $ROUT_CNT

  local ROUT_ID=()
  local ROUT_OFS=()
  M=$(($M - 2))
  for ((i=0;i<$ROUT_CNT;i++)); do
    ROUT_ID[$i]="0x`SE32 ${ROUT_HDL:$((8 + $i * 16)):8}`"
    ROUT_OFS[$i]="0x`SE32 ${ROUT_HDL:$((16 + $i * 16)):8}`"
    M=$(($M - 8))
  done
  echo "ROUT_ID=${ROUT_ID[@]}"
  echo "ROUT_OFS=${ROUT_OFS[@]}"

  # area
  local AREA_HDL=${ROUT_HDL:$((8 + $i * 16))}
 
  printf 'M=%d\n' $M
}

decode_ROAD_SHAPE_DATA() {
  local D=$1
#echo "SHAPE_DATA=$D"

  SHAPE_DATA_SIZE="0x`SE32 ${D:0:8}`"
  SHAPE_DATA_CNT="0x`SE32 ${D:8:8}`"

  printf 'SHAPE_DATA_SIZE=%d\n' $SHAPE_DATA_SIZE
  printf 'SHAPE_DATA_CNT=%d\n' $SHAPE_DATA_CNT

  local M=$(($SHAPE_DATA_SIZE * 4))
echo "## SHAPE_DATA=${D:0:$M}"

  local RDSP="${D:16}" # 8 x 2
echo "RDSP=$RDSP"
  M=$(($M - 8))
  local T
  for ((i=0; i < $SHAPE_DATA_CNT;i++));do
    T="0x`SE16 ${RDSP:0:4}`"
    T=$(($T * 4))
    echo "RDSP[$i]=${RDSP:0:$(($T * 2))}"
    decode_LKSP ${RDSP:0:$(($T * 2))}
    RDSP="${RDSP:$(($T * 2))}"
    M=$(($M - $T))
  done
  printf 'SHAPE_DATA M=%d\n' $M
}

decode_IDX_UPLINK() {
  echo "## decode_IDX_UPLINK"
  NOT_READY "${FUNCNAME[0]}"
}
decode_IDX_UPLINK2() {
  echo "## decode_IDX_UPLINK2"
  NOT_READY "${FUNCNAME[0]}"
}
decode_IDX_UPLINK3() {
  echo "## decode_IDX_UPLINK3"
  NOT_READY "${FUNCNAME[0]}"
}
decode_IDX_UPLINK4() {
  echo "## decode_IDX_UPLINK4"
  NOT_READY "${FUNCNAME[0]}"
}
decode_IDX_UPLINK5() {
  echo "## decode_IDX_UPLINK5"
  NOT_READY "${FUNCNAME[0]}"
}
decode_IDX_UPLINK6() {
  echo "## decode_IDX_UPLINK6"
  NOT_READY "${FUNCNAME[0]}"
}

decode_ROAD_SHAPE() {
  echo "!! ROAD_SHAPE"
  [ -n "$VERBOSE" ] && echo "# $1 $2"

  local N=$1
  local D=$2

  M=$(($N * 4))
echo "M=$M"
echo "SHAPE=$D"

####
  # directory

  ALL_SHAPE_CNT="0x`SE16 ${D:0:4}`"

  decode_RSHP_DIR ${D:8:$((92 * 2))} # (4 * 16 + 4 + 4 * 5 + 4)

  M=$(($M - 92))
echo "M=$M"

  printf 'ALL_SHAPE_CNT=%d\n' $ALL_SHAPE_CNT
  printf 'RECORD15_OFS=%d\n' $RECORD15_OFS
  printf 'RECORD14_OFS=%d\n' $RECORD14_OFS
  printf 'RECORD13_OFS=%d\n' $RECORD13_OFS
  printf 'RECORD12_OFS=%d\n' $RECORD12_OFS
  printf 'RECORD11_OFS=%d\n' $RECORD11_OFS
  printf 'RECORD10_OFS=%d\n' $RECORD10_OFS
  printf 'RECORD9_OFS=%d\n' $RECORD9_OFS
  printf 'RECORD8_OFS=%d\n' $RECORD8_OFS
  printf 'RECORD7_OFS=%d\n' $RECORD7_OFS
  printf 'RECORD6_OFS=%d\n' $RECORD6_OFS
  printf 'RECORD5_OFS=%d\n' $RECORD5_OFS
  printf 'RECORD4_OFS=%d\n' $RECORD4_OFS
  printf 'RECORD3_OFS=%d\n' $RECORD3_OFS
  printf 'RECORD2_OFS=%d\n' $RECORD2_OFS
  printf 'RECORD1_OFS=%d\n' $RECORD1_OFS
  printf 'RECORD0_OFS=%d\n' $RECORD0_OFS

  printf 'INDEX_LINK_OFS=%d\n' $INDEX_LINK_OFS

  printf 'IDX_UPLINK2_OFS=%d\n' $IDX_UPLINK2_OFS
  printf 'IDX_UPLINK3_OFS=%d\n' $IDX_UPLINK3_OFS
  printf 'IDX_UPLINK4_OFS=%d\n' $IDX_UPLINK4_OFS
  printf 'IDX_UPLINK5_OFS=%d\n' $IDX_UPLINK5_OFS
  printf 'IDX_UPLINK6_OFS=%d\n' $IDX_UPLINK6_OFS
  printf 'IDX_UPLINK_OFS=%d\n' $IDX_UPLINK_OFS

  # decode shape

  [ "$INV32" != $RECORD15_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD15_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD14_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD14_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD13_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD13_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD12_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD12_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD11_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD11_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD10_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD10_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD9_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD9_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD8_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD8_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD7_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD7_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD6_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD6_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD5_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD5_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD4_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD4_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD3_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD3_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD2_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD2_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD1_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD1_OFS * 4 * 2))}"
  [ "$INV32" != $RECORD0_OFS ] &&
  decode_ROAD_SHAPE_DATA "${D:$(($RECORD0_OFS * 4 * 2))}"

  # decode index

  [ "$INV32" != $INDEX_LINK_OFS ] &&
  decode_INDEX_LINK "${D:$((($INDEX_LINK_OFS * 4) * 2))}"

  [ "$INV32" != $IDX_UPLINK2_OFS ] &&
  decode_IDX_UPLINK2 "${D:$((($IDX_UPLINK2_OFS * 4) * 2))}"
  [ "$INV32" != $IDX_UPLINK3_OFS ] &&
  decode_IDX_UPLINK3 "${D:$((($IDX_UPLINK3_OFS * 4) * 2))}"
  [ "$INV32" != $IDX_UPLINK4_OFS ] &&
  decode_IDX_UPLINK4 "${D:$((($IDX_UPLINK4_OFS * 4) * 2))}"
  [ "$INV32" != $IDX_UPLINK5_OFS ] &&
  decode_IDX_UPLINK5 "${D:$((($IDX_UPLINK5_OFS * 4) * 2))}"
  [ "$INV32" != $IDX_UPLINK6_OFS ] &&
  decode_IDX_UPLINK6 "${D:$((($IDX_UPLINK6_OFS * 4) * 2))}"
  [ "$INV32" != $IDX_UPLINK_OFS ] &&
  decode_IDX_UPLINK "${D:$((($IDX_UPLINK_OFS * 4) * 2))}"
}

#
# ROAD_NETWORK
#
# sms/sms-core/SMCoreDAL/SMMAL.h
# sms/sms-core/SMCoreDM/RT/RT_MapLib.c
# sms/sms-core/SMCoreRP/RP_lib.h
#
# 8 BYTE[] RNET_DIR
#
# (RNET_DIR)
# 4 UINT32 NWLINK_OFS
# 8 UINT32 NWCNCT_OFS
# 12 UINT32 NWLINKEX_OFS
# 16 UINT32 NWCNTEX_OFS
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

decode_NWLINK_DATA() {
  local D=$1
  local M=$((${#D} / 2))
  printf 'M=%d\n' $M

  local STID="0x`SE32 ${D:0:8}`"
  local EDID="0x`SE32 ${D:8:8}`"
  local STIDX="0x`SE16 ${D:16:4}`"
  local EDIDX="0x`SE16 ${D:20:4}`"
  local ID="0x`SE32 ${D:24:8}`"
  local LIMIT="0x`SE32 ${D:32:8}`"
  local ST_X="0x`SE16 ${D:40:4}`"
  local ST_Y="0x`SE16 ${D:44:4}`"
  local ED_X="0x`SE16 ${D:48:4}`"
  local ED_Y="0x`SE16 ${D:52:4}`"
  local T="0x`SE32 ${D:56:8}`"
  local STDIR=$((($T >> 24) & 0xff))
  local EDDIR=$((($T >> 16) & 0xff))
  local TRAVELTIME=$(($T & 0x3fff))
  T="0x`SE32 ${D:64:8}`"
  local LINKEXOFSFLG=$((($T >> 31) & 0x1))
  local EXOFS=$(($T & 0x7fffffff))
  local FORMOFS=$T
  M=$(($M - 36))

  printf 'STID=0x%X\n' $STID
  printf 'EDID=0x%X\n' $EDID
  printf 'STIDX=0x%X\n' $STIDX
  printf 'EDIDX=0x%X\n' $EDIDX
  printf 'ID=0x%X\n' $ID
  printf 'LIMIT=0x%X\n' $LIMIT
  printf 'ST_X=0x%X\n' $ST_X
  printf 'ST_Y=0x%X\n' $ST_Y
  printf 'ED_X=0x%X\n' $ED_X
  printf 'ED_Y=0x%X\n' $ED_Y
  printf 'STDIR=0x%X\n' $STDIR
  printf 'EDDIR=0x%X\n' $EDDIR
  printf 'TRAVELTIME=0x%X\n' $TRAVELTIME
  printf 'LINKEXOFSFLG=0x%X\n' $LINKESOFSFLG
  printf 'EXOFS=0x%X\n' $EXOFS
  printf 'FORMOFS=0x%X\n' $FORMOFS

  # T_MapBaseLinkInfo
  # BASE1: ROAD_TYPE,LINK1_TYPE, etc.
  # BASE2: LINKDIST, etc.
  local BASE1="0x`SE32 ${D:72:8}`"
  local BASE2="0x`SE32 ${D:80:8}`"
  M=$(($M - 8))

  printf 'BASE1=0x%X\n' $BASE1
  printf '# ROAD_TYPE=%d\n' $((($BASE1 >> 28) & 0xf))
  printf '# LINK1_TYPE=%d\n' $((($BASE1 >> 24) & 0xf))
  printf '# LINK2_TYPE=%d\n' $((($BASE1 >> 21) & 0x7))
  printf '# LINK3_TYPE=%d\n' $((($BASE1 >> 18) & 0x7))
  printf '# LINK4_TYPE=%d\n' $((($BASE1 >> 16) & 0x3))
  printf '# ONEWAY=%d\n' $((($BASE1 >> 14) & 0x3))
  printf '# TOLLFLAG=%d\n' $((($BASE1 >> 1) & 0x1))
  printf '# BYPASS=%d\n' $(($BASE1 & 0xf))
  printf 'BASE2=0x%X\n' $BASE2
  printf '# LINKDIST=%d\n' $((($BASE1 >> 16) & 0x7fff))
  printf '# LANE=%d\n' $((($BASE1 >> 3) & 0x3))
  printf '# EASYRUN=%d\n' $(($BASE1 & 0x7))

  printf '# NWLINK_DATA M=%d\n' $M
  #NOT_READY "${FUNCNAME[0]}"
}

decode_NWLINK() {
  local D=$1
  local N="0x`SE32 ${D:0:8}`"
  local RECORD_VOL="0x`SE32 ${D:8:8}`"
  local M=$(($N * 4))
  M=$(($M - 8))

  printf '# NWLINK\n'
  printf '# N=%d\n' $N
  printf '# RECORD_VOL=%d\n' $RECORD_VOL
  #printf '# RECORD=%s\n' ${D:16}
  printf '# RECORD=%s\n' ${D:16:$((N * 8 - 16))}
  local i
  for ((i=0;i<$RECORD_VOL;i++)); do
    # record size 44
    printf 'NWLINK[%d]=%s\n' $i ${D:$((16 + 88 * $i)):88}
    decode_NWLINK_DATA ${D:$((16 + 88 * $i)):88}
    M=$(($M - 44))
  done
  printf '# NWLINK M=%d\n' $M
}

decode_NWCNCT_DATA() {
  local D=$1
  local M=$((${#D} / 2))
  printf 'M=%d\n' $M

  local STID="0x`SE32 ${D:0:8}`"
  local EDID="0x`SE32 ${D:8:8}`"
  local STIDX="0x`SE16 ${D:16:4}`"
  local EDIDX="0x`SE16 ${D:20:4}`"
  local ID="0x`SE32 ${D:24:8}`"
  local EXOFS="0x`SE32 ${D:32:8}`"
  M=$(($M - 20))

  printf 'STID=0x%X\n' $STID
  printf 'EDID=0x%X\n' $EDID
  printf 'STIDX=0x%X\n' $STIDX
  printf 'EDIDX=0x%X\n' $EDIDX
  printf 'ID=0x%X\n' $ID
  printf 'EXOFS=0x%X\n' $EXOFS

  local COORDX="0x`SE16 ${D:40:4}`"
  local COORDY="0x`SE16 ${D:44:4}`"
  local COUNTRY="0x`SE16 ${D:48:4}`"
  local RESERVED="0x`SE16 ${D:52:4}`"
  M=$(($M - 8))

  printf 'COORDX=0x%X\n' $COORDX
  printf 'COORDY=0x%X\n' $COORDY
  printf 'COUNTRY=0x%X\n' $COUNTRY
  printf 'RESERVED=0x%X\n' $RESERVED

  printf '# NWCNCT_DATA M=%d\n' $M
  #NOT_READY "${FUNCNAME[0]}"
}

decode_NWCNCT() {
  local D=$1
  local N="0x`SE32 ${D:0:8}`"
  local RECORD_VOL="0x`SE32 ${D:8:8}`"
  local M=$(($N * 4))
  M=$(($M - 8))

  printf '# NWCNCT\n'
  printf '# N=%d\n' $N
  printf '# RECORD_VOL=%d\n' $RECORD_VOL
  #printf '# RECORD=%s\n' ${D:16}
  printf '# RECORD=%s\n' ${D:16:$((N * 8 - 16))}
  local i
  for ((i=0;i<$RECORD_VOL;i++)); do
    # record size 28
    printf 'NWCNCT[%d]=%s\n' $i ${D:$((16 + 56 * $i)):56}
    decode_NWCNCT_DATA ${D:$((16 + 56 * $i)):56}
    M=$(($M - 28))
  done
  printf '# NWCNCT M=%d\n' $M
}

decode_NWLINKEX() {
  printf '# NWLINKEX\n'
  NOT_READY "${FUNCNAME[0]}"
}
decode_NWCNTEX() {
  printf '# NWCNTEX\n'
  NOT_READY "${FUNCNAME[0]}"
}
decode_LINKREG() {
  printf '# LINKREG\n'
  NOT_READY "${FUNCNAME[0]}"
}

decode_IDXLINK() {
  local D=$1
  local N="0x`SE32 ${D:0:8}`"
  local RECORD_VOL="0x`SE32 ${D:8:8}`"
  local M=$((8 + 2 * $RECORD_VOL))
  M=$(($M - 8))

  printf '# IDXLINK\n'
  printf '# N=%d\n' $N
  printf '# RECORD_VOL=%d\n' $RECORD_VOL
  printf '# D=%s\n' ${D:16:$((N * 8 - 16))}
  local IDXLINK=()
  local i
  for ((i=0;i<$RECORD_VOL;i++)); do
    # record size 2
    #echo "${D:$((16 + 4 * $i)):4}"
    IDXLINK[$i]="0x`SE16 ${D:$((16 + 4 * $i)):4}`"
    M=$(($M - 2))
  done
  echo "IDXLINK=${IDXLINK[@]}"
  printf '# IDXLINK M=%d\n' $M
}

decode_IDXCNCT() {
  local D=$1
  local N="0x`SE32 ${D:0:8}`"
  local RECORD_VOL="0x`SE32 ${D:8:8}`"
  local M=$((8 + 2 * $RECORD_VOL))
  M=$(($M - 8))

  printf '# IDXCNCT\n'
  printf '# N=%d\n' $N
  printf '# RECORD_VOL=%d\n' $RECORD_VOL
  printf '# D=%s\n' ${D:16:$((N * 8 - 16))}
  local i
  for ((i=0;i<$RECORD_VOL;i++)); do
    # record size 2
    #echo "${D:$((16 + 4 * $i)):4}"
    printf 'IDXCNCT[%d]=%d\n' $i "0x`SE16 ${D:$((16 + 4 * $i)):4}`"
    IDXCNCT[$i]="0x`SE16 ${D:$((16 + 4 * $i)):4}`"
    M=$(($M - 2))
  done
  echo "IDXCNCT=${IDXCNCT[@]}"
  printf '# IDXCNCT M=%d\n' $M
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
# sms/sms-core/SMCoreMP/SMBkgdAnalyze.h
# sms/sms-core/SMCoreMP/MP_Def.h
# sms/sms-core/SMCoreMP/MP_DrawMap.cpp
# sms/sms-core/SMCoreMP/SMCommonAnalyzerData.h
# sms/sms-core/SMCoreDHC/DHC_CashAreaCls.c
# sms/sms-core/SMCoreMP/SMBkgdAnalyze.h
#
# (BKGD)
# SIZE
# CNT
# BKGDH * CNT
#  
# (BKGDH)
# SIZE
# CNT
# BKGDOBJ * CNT
# 
# (BKGDOBJ)
# SIZE
# INFO
# ...
#

decode_BKGDOBJ() {
  local D=$1
  echo "BKGDOBJ=$D"

  local M="0x`SE16 ${D:0:4}`"
  M=$(($M << 2))

  local INFO="0x`SE16 ${D:4:4}`"
  local SORT_ID="0x`SE32 ${D:8:8}`"
  local ID="0x`SE32 ${D:16:8}`"

  printf 'BKGDOBJ_INFO=0x%X\n' $INFO
  printf '# RESERVE=%d\n' $(($INFO & 0x3f)) # max levels (?)
  printf '# EXADD_FLG=%d\n' $((($INFO >> 6) & 1)) # EXADD exist?
  printf '# OBJ3D_FLG=%d\n' $((($INFO >> 7) & 1)) # OBJ3D exist?
  printf '# FIGURE_TYPE=%d\n' $((($INFO >> 8) & 3))
  local TYPE=$((($INFO >> 8) & 3))
  printf '# ZOOM_FLG=%d\n' $(((INFO >> 10) & 0x3f))
  # INFO2?
  printf 'BKGDOBJ_SORT_ID=0x%X\n' $SORT_ID
  printf '# KIND_CD=%d\n' $(($SORT_ID & 0xff))
  printf '# TYPE_CD=%d\n' $((($SORT_ID >> 8) & 0xff))
  printf '# SORT_ID=%d\n' $((($SORT_ID >> 16) & 0xffff))
  printf 'BKGDOBJ_ID=0x%X\n' $ID

  case $TYPE in
    0)
      printf '# SHAPE: POINT\n'
      ;;
    1)
      printf '# SHAPE: LINE\n'
      ;;
    2)
      printf '# SHAPE: POLYGON\n'
      ;;
    3)
      printf '# SHAPE: NOPOLYGON\n'
      ;;
    *)
      printf '# SHAPE: UNKNOWN\n'
      ;;
  esac

  case $TYPE in
    1 | 2 )
 
      # interpret as points

      local POINT_CNT="0x`SE16 ${D:24:4}`"
      local POINT_INFO="0x`SE16 ${D:28:4}`"
 
      printf 'BKGDOBJ_POINT_CNT=%d\n' $POINT_CNT
      printf 'BKGDOBJ_POINT_INFO=%d\n' $POINT_INFO
      printf '# RESERVE2=%d\n' $(($POINT_INFO & 0xff))
      printf '# PRIMITIVE_KIND=%d\n' $((($POINT_INFO >> 8) & 0xf))
      printf '# RESERVE=%d\n' $((($POINT_INFO >> 12) & 0x3))
      printf '# EXPRESS_INFO=%d\n' $((($POINT_INFO >> 14) & 1))
      printf '# DATA_FORM=%d\n' $((($POINT_INFO >> 15) & 1))
      local DATA_FORM=$((($POINT_INFO >> 15) & 1))

      local POINT_X=() 
      local POINT_Y=() 
      POINT_X[0]="0x`SE16 ${D:32:4}`"
      POINT_Y[0]="0x`SE16 ${D:36:4}`"
      M=$(($M - 20))
      local j=1
      local i
      #for ((i=0;i<($POINT_CNT - 1);i++)); do
      for ((i=0;i<$POINT_CNT - 1;i++)); do
        if (($POINT_INFO == 0)); then
          # offset value byte pairs
          POINT_X[$j]="0x`SE8 ${D:$((40 + $i * 4)):2}`"
          POINT_Y[$j]="0x`SE8 ${D:$((42 + $i * 4)):2}`"
          M=$(($M - 2))
        else
          # absolute values word pairs
          POINT_X[$j]="0x`SE16 ${D:$((40 + $i * 8)):4}`"
          POINT_Y[$j]="0x`SE16 ${D:$((44 + $i * 8)):4}`"
          M=$(($M - 4))
        fi
        j=$(($j + 1))
      done

      echo "POINT_X=${POINT_X[@]}"
      echo "POINT_Y=${POINT_Y[@]}"

      ;;

    3)
      # NOPOLYGON, no more data
      printf '#### M=%d\n', $M
      return
      ;;

    *)

      NOT_READY "TYPE=$TYPE"
      printf '#### M=%d\n', $M
      return
      ;;
  esac

  # check size
  printf '#### M=%d\n', $M
}

decode_BKGDH() {
  local D=$1
  local SIZE="0x`SE16 ${D:0:4}`"
  local CNT="0x`SE16 ${D:4:4}`"

printf '#### BKGDH %s\n' ${D:0:16}
  printf '### BKGDH SIZE=%d (%d)\n' $SIZE $(($SIZE * 4))
  printf '### BKGDH CNT=%d\n' $CNT

  local M=4
  D=${D:8}
  local i
  for ((i=0;i<$CNT;i++)); do
    local N="0x`SE16 ${D:0:4}`"
    N=$(($N * 4))
    M=$(($M + $N))
    printf '# BKGDOBJ[%d] (%d)\n' $i $N 

    N=$(($N * 2))
    decode_BKGDOBJ ${D:0:$N}
    D=${D:$N}
  done
  printf '### M=%d <-> %d\n' $M $((SIZE * 4))
}

decode_BKGD() {
  echo "!! BKGD"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  local D=$2

echo "D=$D"

  BKGD_CNT="0x`SE32 ${D:0:8}`"

  printf 'BKGD_CNT=%d\n' $BKGD_CNT

  D="${D:8}"
  for ((i=0;i<$BKGD_CNT;i++)); do
    local N="0x`SE16 ${D:0:4}`"
    N=$(($N * 4))
    printf '# BKGDH[%d] (%d)\n' $i  $N
    N=$(($N * 2))

    decode_BKGDH ${D:0:$N}

    D=${D:$N}
  done
}

#
# BKGD_AREA_CLS
#

decode_BKGD_AREA_CLS() {
  echo "# BKGD_AREA_CLS"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  NOT_READY "${FUNCNAME[0]}"
}

#
# MARK
#
# See sms/sms-core/SMCoreMP/SMMarkAnalyze.cpp
#

decode_MARK() {
  echo "!! MARK"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  local D="$2"

  MARK_CNT="0x`SE32 ${D:0:8}`"
  printf 'MARK_CNT=%d\n' $MARK_CNT

  D="${D:8}"
  for ((i=0;i<$MARK_CNT;i++)); do
    Z="0x`SE16 ${D:0:4}`"
    Z="$(($Z * 4 * 2))"
    echo "MARK[$i]=${D:0:$Z}"
    D="${D:$Z}"
  done 
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
  local D=$1

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
  local D=$1

  RDNM_SIZE="0x`SE16 ${D:0:4}`"
  RDNM_LANG_CNT="0x`SE16 ${D:4:4}`"
  RDNM_ID="0x`SE32 ${D:8:8}`"

  printf 'RDNM_SIZE=%d\n' $RDNM_SIZE
  printf 'RDNM_LANG_CNT=%d\n' $RDNM_LANG_CNT
  printf 'RDNM_ID=0x%X\n' $RDNM_ID

  D=${D:16}
  local i
  for ((i=0;i<$RDNM_LANG_CNT;i++)); do
    N=$((0x`SE16 ${D:0:4}` * 8)) # CNT * 4
    decode_RNLG ${D:0:$N}
    D=${D:$N}
  done
}

decode_ROAD_NAME() {
  echo "# ROAD_NAME"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  local D="$2"
  local RDNM_CNT="0x`SE32 ${D:0:8}`" # 4 bytes
  printf 'RDNM_CNT=%d\n' $RDNM_CNT
  local i
  for ((i=0;i<$RDNM_CNT;i++));do
    local N="0x`SE16 ${D:8:4}`"
    N=$(($N * 4))
    printf '# RDNM[%d] (%d)\n' $i $N
    decode_RDNM ${D:8:$(($N*2))}
  done
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
  local D=$1

  echo "XXX=$D"

  local M="0x`SE16 ${D:0:4}`" # SIZE
 
#  NAME_SIZE="0x`SE16 ${D:0:4}`"
  NAME_LNG_CNT="0x`SE16 ${D:4:4}`"
  NAME_NAME_KIND="0x`SE32 ${D:8:8}`"
  NAME_ID="0x`SE32 ${D:16:8}`"

  M=$(($M - 12)) # SIZE
  D=${D:24}

  echo "YYYY=$D"

  NMLG_SIZE="0x`SE16 ${D:0:4}`"
  NMLG_LANG_KIND="0x${D:4:2}"
  NMLG_INFO1="0x`SE32 ${D:8:8}`"
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
  NOT_READY "${FUNCNAME[0]}"
}

#
# ROAD_DENSITY
#

decode_ROAD_DENSITY() {
  echo "# ROAD_DENSITY"
  [ -n "$VERBOSE" ] && echo "# $1 $2"
  NOT_READY "${FUNCNAME[0]}"
}

#[ -n "$VERBOSE" ] && echo "KIND=$KIND"
#[ -n "$VERBOSE" ] && echo "BLOB=$BLOB"

BLOB="`stripx "$BLOB"`"

DATA=$BLOB
SIZE=$((${#DATA} / 8))

#
# handle blobs with volume header
#
# DATA blob data without header and uncompressed if necessary
# SIZE byte size of DATA
#

unpack_Blob() {
  local D=$1

  DHC_VOLUM_INFO="0x`SE32 ${D:0:8}`" # 4 bytes

  echo "DHC_VOLUM_INFO: $DHC_VOLUM_INFO"

  local COMP="$((($DHC_VOLUM_INFO & 0xE0000000) >> 29))"
  SIZE="$((($DHC_VOLUM_INFO & ~0xE0000000)))"

  printf 'COMP=0x%X\n' $COMP
  printf 'SIZE=0x%X\n' $SIZE

  DATA=${BLOB:8}
  echo "DATA=$DATA"
  if [ "$COMP" == "1" ]; then
    DATA=`unzip_str $DATA`
    echo "DATA2=$DATA"
  fi
  printf 'SIZE2=0x%X (0x%X)\n' $SIZE2 ${#DATA}

  SIZE=$((${#DATA} / 8))
}

case $KIND in
  "PARCEL_BASIS")
    decode_PARCEL_BASIS $SIZE ${DATA:0:$(($SIZE * 8))}
    ;;
  "ROAD_SHAPE")
    unpack_Blob $DATA
    decode_ROAD_SHAPE $SIZE ${DATA:0:$(($SIZE * 8))}
    ;;
  "ROAD_NETWORK")
    unpack_Blob $DATA
    decode_ROAD_NETWORK $SIZE ${DATA:0:$(($SIZE * 8))}
    ;;
  "BKGD")
    unpack_Blob $DATA
    decode_BKGD $SIZE ${DATA:0:$(($SIZE * 8))}
    ;;
  "BKGD_AREA_CLS")
    unpack_Blob $DATA
    decode_BKGD_AREA_CLS $SIZE ${DATA:0:$(($SIZE * 8))}
    ;;
  "MARK")
    unpack_Blob $DATA
    decode_MARK $SIZE ${DATA:0:$(($SIZE * 8))}
    ;;
  "ROAD_NAME")
    unpack_Blob $DATA
    decode_ROAD_NAME $SIZE ${DATA:0:$(($SIZE * 8))}
    ;;
  "NAME")
    unpack_Blob $DATA
    decode_NAME $SIZE ${DATA:0:$(($SIZE * 8))}
    ;;
  "GUIDE")
    unpack_Blob $DATA
    decode_GUIDE $SIZE ${DATA:0:$(($SIZE * 8))}
    ;;
  "ROAD_DENSITY")
    unpack_Blob $DATA
    decode_DENSITY $SIZE ${DATA:0:$(($SIZE * 8))}
    ;;
  *)
    NOT_READY "KIND=$KIND"
    ;;
esac

