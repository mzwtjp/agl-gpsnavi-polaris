
## Polaris.db files

### Original data

The below are data extracted from the original db files.

* jp
* uk

Each of the set consist of the following files.

DB files

* Polaris.db (large!, not incnluded in the repo)

Dump data generated from Polaris.db

* DOWNLOAD_AREA_MAP.txt
* DOWNLOAD_BASE_VERSION.txt
* DOWNLOAD_SYS.txt
* PARCEL.txt (large!, not included in the repo)
* SYSTEM_INFORMATION.txt

PARCEL.txt is quite large and not included in the shared repogitory.  You have to generate them locally as follows.

$ wget http://agl.wismobi.com/data/UnitedKingdom_TR9/navi_data_UK.tar.gz
$ tar xvfz ./navi_data_UK.tar.gz
$ ls -l navi_data_UK/UnitedKingdom_TR9/Map/JPN/

>total 1683800
>drwxr-xr-x  7 tmatsuzawa  staff        224 Nov  7  2016 Config
>-rwxr-xr-x  1 tmatsuzawa  staff          0 Jul  2  2015 Depot.db
>drwxr-xr-x  2 tmatsuzawa  staff         64 Jun 11  2016 Log
>-rwxr-xr-x  1 tmatsuzawa  staff  846976000 Nov  7  2016 Polaris.db
>-rwxr-xr-x  1 tmatsuzawa  staff       4096 Jul  2  2015 SensorData.db
>drwxr-xr-x  3 tmatsuzawa  staff         96 Nov  7  2016 TTS
>drwxr-xr-x  2 tmatsuzawa  staff         64 Jun 11  2016 Temp
>-rwxr-xr-x  1 tmatsuzawa  staff       5120 Jun 11  2016 poi.db

$ sqlite3 navi_data_UK/UnitedKingdom_TR9/Map/JPN/Polaris.db ".dump PARCEL" > PARCEL.txt
$ ls -l 

>total 4918536
>-rw-r--r--  1 tmatsuzawa  staff  1657274578 Jun 30 17:58 PARCEL.txt
>drwxr-xr-x  4 tmatsuzawa  staff         128 Nov  7  2016 navi_data_UK
>-rw-r--r--@ 1 tmatsuzawa  staff   845062286 Nov  7  2016 navi_data_UK.tar.gz

## OSM files

