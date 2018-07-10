#!/bin/bash
  
usage_exit() {
  echo "Usage: parcel-blob-encode [-k kind] [blob]
Interpret blob data in PARCEL table.

-k      type of blob
blob    blob data in hex string notation

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
" 1>&2
  exit 1
}

#VERBOSE=
VERBOSE=1
#BLOB=
BLOB="00112233445566778899aabbccddeeff"
INFILE=

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

#
# util functions
#

# format integer into hex string, little endian
# X = N VAL

I2STR() {
  local N=$1
  local I=$2
  local X=""
  while ((N > 0)); do
    X="$X`printf '%02X' $((I & 0xff))`"
    I=$((I >> 8))
    N=$((N - 1))
  done
  echo "$X"
}


NOT_READY() {
  echo "#E NOT IMPLEMENTED YET!! $1"
}

#
#
#

encode_PARCEL_BASIS() {
  if (($LINE_NO == 0)); then
    echo "# ${FUNCNAME[0]}"
    BLOB=""
    NOT_READY "(${FUNCNAME[0]})"
  fi
  [ "${1:0:1}" == "#" ] && return
  local K="${1%%=*}"
  local B="${1#*=}"
  local E

  case $K in
    "PCLB_SIZE" )
      BLOB="$BLOB`I2STR 2 $B`"
      ;;
    "PCLB_SEA_FLG" )
      BLOB="$BLOB`I2STR 1 $B`"
      ;;
    "PCLB_AREAREC_CNT" )
      BLOB="$BLOB`I2STR 1 $B`"
      ;;
    "PCLB_REAL_LENGTH_T" )
      BLOB="$BLOB`I2STR 4 $B`"
      ;;
    "PCLB_REAL_LENGTH_B" )
      BLOB="$BLOB`I2STR 4 $B`"
      ;;
    "PCLB_REAL_LENGTH_L" )
      BLOB="$BLOB`I2STR 4 $B`"
      ;;
    "PCLB_REAL_LENGTH_R" )
      BLOB="$BLOB`I2STR 4 $B`"
      ;;
    "PCLB_COUNTRY_CODE_CNT" )
      BLOB="$BLOB`I2STR 2 $B`"
      ;;
    "COUNTRY_CODE" )
      for E in $B; do
        BLOB="$BLOB`I2STR 2 $E`"
      done
      ;;
    "AREA_NO" )
      for E in $B; do
        BLOB="$BLOB`I2STR 1 $E`"
      done
      ;;
    *)
      echo "#E UNKNOWN K=$K"
      ;;
  esac
}

#
#
#

encode_ROAD_SHAPE() {
  if (($LINE_NO == 0)); then
    echo "# ${FUNCNAME[0]}"
    BLOB=""
    NOT_READY "(${FUNCNAME[0]})"
  fi
  [ "${L:0:1}" == "#" ] && return

  local L=$1
}

#
#
#

encode_ROAD_NETWORK() {
  if (($LINE_NO == 0)); then
    echo "# ${FUNCNAME[0]}"
    BLOB=""
    NOT_READY "(${FUNCNAME[0]})"
  fi
  [ "${L:0:1}" == "#" ] && return

  local L=$1
}

#
#
#

encode_BKGD() {
  if (($LINE_NO == 0)); then
    echo "# ${FUNCNAME[0]}"
    BLOB=""
    NOT_READY "(${FUNCNAME[0]})"
  fi
  [ "${L:0:1}" == "#" ] && return

  local L=$1
}

#
#
#

encode_BKGD_AREA_CLS() {
  if (($LINE_NO == 0)); then
    echo "# ${FUNCNAME[0]}"
    BLOB=""
    NOT_READY "(${FUNCNAME[0]})"
  fi
  [ "${L:0:1}" == "#" ] && return

  local L=$1
}

#
#
#

encode_MARK() {
  if (($LINE_NO == 0)); then
    echo "# ${FUNCNAME[0]}"
    BLOB=""
    NOT_READY "(${FUNCNAME[0]})"
  fi
  [ "${L:0:1}" == "#" ] && return

  local L=$1
}

#
#
#

encode_ROAD_NAME() {
  if (($LINE_NO == 0)); then
    echo "# ${FUNCNAME[0]}"
    BLOB=""
    NOT_READY "(${FUNCNAME[0]})"
  fi
  [ "${L:0:1}" == "#" ] && return

  local L=$1
}

#
#
#

encode_NAME() {
  if (($LINE_NO == 0)); then
    echo "# ${FUNCNAME[0]}"
    BLOB=""
    NOT_READY "(${FUNCNAME[0]})"
  fi
  [ "${L:0:1}" == "#" ] && return

  local L=$1
}

#
#
#

encode_GUIDE() {
  if (($LINE_NO == 0)); then
    echo "# ${FUNCNAME[0]}"
    BLOB=""
    NOT_READY "(${FUNCNAME[0]})"
  fi
  [ "${L:0:1}" == "#" ] && return

  local L=$1
}

#
#
#

encode_DENSITY() {
  if (($LINE_NO == 0)); then
    echo "# ${FUNCNAME[0]}"
    BLOB=""
    NOT_READY "(${FUNCNAME[0]})"
  fi
  [ "${L:0:1}" == "#" ] && return

  local L=$1
}

encode_UNKNOWN() {
  if (($LINE_NO == 0)); then
    echo "# ${FUNCNAME[0]}"
    BLOB=""
    NOT_READY "(${FUNCNAME[0]})"
  fi
  local L=$1
}

echo "# encode KIND=$KIND"

# default

PROC_LINE="encode_NONE"

# set matching process function

case $KIND in
  "PARCEL_BASIS")
    PROC_LINE="encode_PARCEL_BASIS"
    ;;
  "ROAD_SHAPE")
    PROC_LINE="encode_ROAD_SHAPE"
    ;;
  "ROAD_NETWORK")
    PROC_LINE="encode_ROAD_NETWORK"
    ;;
  "BKGD")
    PROC_LINE="encode_BKGD"
    ;;
  "BKGD_AREA_CLS")
    PROC_LINE="encode_BKGD_AREA_CLS"
    ;;
  "MARK")
    PROC_LINE="encode_MARK"
    ;;
  "ROAD_NAME")
    PROC_LINE="encode_ROAD_NAME"
    ;;
  "NAME")
    PROC_LINE="encode_NAME"
    ;;
  "GUIDE")
    PROC_LINE="encode_GUIDE"
    ;;
  "ROAD_DENSITY")
    PROC_LINE="encode_DENSITY"
    ;;
  *)
    ;;
esac

#
# read lines from stdin or file
# encoded data is added to BLOB string
# 

LINE_NO=0

while IFS= read -r L
do
  [ -n "$VERBOSE" ] && echo "#I $L"
  ${PROC_LINE} $L
  LINE_NO=$((LINE_NO + 1))
done < <(cat $INFILE)

# final output

echo "BLOB_OUT=$BLOB"

