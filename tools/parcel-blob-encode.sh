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

NOT_READY() {
  echo "## NOT IMPLEMENTED YET!!"
}

#
#
#

encode_PARCEL_BASIS() {
  echo "# encode_PARCEL_BASIS"
  NOT_READY
}

#
#
#

encode_ROAD_SHAPE() {
  echo "# encode_ROAD_SHAPE"
  NOT_READY
}

#
#
#

encode_ROAD_NETWORK() {
  echo "# encode_ROAD_NETWORK"
  NOT_READY
}

#
#
#

encode_BKGD() {
  echo "# encode_BKGD"
  NOT_READY
}

#
#
#

encode_BKGD_AREA_CLS() {
  echo "# encode_BKGD_AREA_CLS"
  NOT_READY
}

#
#
#

encode_MARK() {
  echo "# encode_MARK"
  NOT_READY
}

#
#
#

encode_ROAD_NAME() {
  echo "# encode_ROAD_NAME"
  NOT_READY
}

#
#
#

encode_NAME() {
  echo "# encode_NAME"
  NOT_READY
}

#
#
#

encode_GUIDE() {
  echo "# encode_GUIDE"
  NOT_READY
}

#
#
#

encode_DENSITY() {
  echo "# encode_DENSITY"
  NOT_READY
}

echo "KIND=$KIND"

case $KIND in
  "PARCEL_BASIS")
    encode_PARCEL_BASIS
    ;;
  "ROAD_SHAPE")
    encode_ROAD_SHAPE
    ;;
  "ROAD_NETWORK")
    encode_ROAD_NETWORK
    ;;
  "BKGD")
    encode_BKGD
    ;;
  "BKGD_AREA_CLS")
    encode_BKGD_AREA_CLS
    ;;
  "MARK")
    encode_MARK
    ;;
  "ROAD_NAME")
    encode_ROAD_NAME
    ;;
  "NAME")
    encode_NAME
    ;;
  "GUIDE")
    encode_GUIDE
    ;;
  "ROAD_DENSITY")
    encode_DENSITY
    ;;
  *)
    ;;
esac

# final output

echo "BLOB_OUT=$BLOB"

