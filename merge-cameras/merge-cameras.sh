#!/bin/bash

## Enable use of extended globs: http://mywiki.wooledge.org/glob
## This is used for JPEG_FILES.
shopt -s extglob

## Some constants.
JHEAD=./jhead # The jhead program. E.g., use "jhead" if the program is
	      # in the search path.
JPEG_FILES=@(*.jpg|*.JPG|*.jpeg|*.JPEG) # Add any extensions here of
					# files you want to accept as
					# pictures. Keep the format:
					# @(*.ext1|*.ext2|...|*.extn)!
OUTPUT_EXT=JPG # The extension to be used for output, such as renamed
	       # pictures.
FIELD_SEPARATOR=, # Field separator for a temporary file.
MINIMUM_NOF_DIGITS=4 # The minimum number of digits for naming JPEGs.


## Check parameters.
usage() {
    echo "merge-cameras.sh <dest> <src 1> <src 2>"
    echo "Expects 3 directories relative to the current directory."
    echo "The first directory is the one where the renamed pictures"
    echo "0000.JPG, 0001.JPG, 0002.JPG, ... will be copied to. The"
    echo "second and third directory contain the JPEGs of the first"
    echo "and second camera."
}
if [ $# -ne 3 ]; then
    echo "ERROR: expects 3 parameters, not $#"
    usage
    exit 1
fi
if [ -e "${1}" ]; then
    echo "ERROR: destination directory already exists: ${1}"
    exit 1
fi
if [ ! -d "${2}" ]; then
    echo "ERROR: source directory does not exist: ${2}"
    exit 1
fi
if [ ! -d "${3}" ]; then
    echo "ERROR: source directory does not exist: ${3}"
    exit 1
fi

jpegtime() {
# params: filename of a JPEG
# output: date/time in in YYYY/MM/DD hh:mm:ss format
# Returns Exif Date/Time of <picture> in YYYY/MM/DD hh:mm:ss format. This is 
# one of the formats that the "date" program can convert to seconds since 
# 1970/1/1. Requires the "jhead" program.
# Uses sed to extract and manipulate the Date/Time from jhead's output.
# line 2: removes the part "Date/Time    : " => "2011:08:01 14:30:56"
# line 3: replaces first : (colon) by / => "2011/08:01 14:30:56"
# line 4: replaces next : (colon) by / => "2011/08/01 14:30:56" and print 
# result
    "${JHEAD}" "${1}" | sed -n '/Date\/Time/{
s/Date\/Time[[:space:]]*: //
s/:/\//
s/:/\//p
}'
}

datetime_2_seconds() {
# params: a date/time string
# output: time in seconds since 1/1/1970
    date -d "${1}" +%s
}

timestamp() {
# params: filename of a JPEG relative to working directory
# output: time when picture was taken in seconds since 1/1/1970
    timestamp=`jpegtime "${1}"`
    timestamp=`datetime_2_seconds "${timestamp}"`
    echo ${timestamp}
}

time_oldest_picture() { 
# params: directory relative to working directory containing the JPEG of 1 
# camera
# output: time when oldest picture was taken in seconds since 1/1/1970
    oldest_time=0
    for i in "${1}"/${JPEG_FILES}; do
	timestamp=`timestamp "${i}"`
	oldest_time="${timestamp}"
	break
    done
    for i in "${1}"/${JPEG_FILES}; do
	timestamp=`timestamp "${i}"`
	if [ ${oldest_time} -gt ${timestamp} ]; then
	    oldest_time=${timestamp}
	fi
    done
    echo ${oldest_time}
}

write_2_table() { 
# params: source directory with JPEGs of one camera, time in seconds since 
# oldest picture was taken, temporary file to write table
# output: none
    for i in "${1}"/${JPEG_FILES}; do
	offset=$[`timestamp "${i}"` - ${2}]
	filename=`basename "${i}"`
	echo "${offset},${filename},${1}" >> "${3}"
    done
}

first() { 
# params: string, charactor as separator
# output: everything before the first occurance of the separator 
    echo "${1%%${2}*}"
}

rest() {
# params: string, charactor as separator
# output: everything after the first occurance of the separator 
    echo "${1#*${2}}"
}

## for both source directories, find time of oldest picture and append a 
## line for each picture to a temporary file. Each line has: "offset in 
## seconds to oldest picture", "filename", "source directory".
table_file=`mktemp`
for cam in "${2}" "${3}"; do
    echo "INFO: finding oldest picture in ${cam}"
    oldest_time=`time_oldest_picture "${cam}"`
    echo "INFO: building list of relative timestamps for pictures in ${cam}"
    write_2_table "${cam}" "${oldest_time}" "${table_file}"
done

## sort the file with table: time offset, filename, source directory
echo "INFO: sorting list of relative timestamps"
sorted_table_file=`mktemp`
sort --general-numeric-sort --stable --field-separator=${FIELD_SEPARATOR} "${table_file}" > "${sorted_table_file}"

## create destination directory
echo "INFO: creating destination path ${1}"
mkdir "${1}"

prepad() {
# params: string, padding char, minimum length
# output: the <string> with extended with <padding char> to the <mimimum length>
    printf "%${3}s" ${1} | tr " " "${2}"
}

## go through file with sorted table, copy and rename pictures one by one to 
## destination directory
echo "INFO: copying and renaming sorted pictures"
linenbr=0
while read line; do
    offset=`first "${line}" ${FIELD_SEPARATOR}`
    line=`rest "${line}" ${FIELD_SEPARATOR}`
    old_filename=`first "${line}" ${FIELD_SEPARATOR}`
    cam=`rest "${line}" ${FIELD_SEPARATOR}`
    new_filename=`prepad ${linenbr} 0 ${MINIMUM_NOF_DIGITS}`
    cp "${cam}/${old_filename}" "${1}/${new_filename}.${OUTPUT_EXT}"
    linenbr=$[ ${linenbr} + 1 ]
done < "${sorted_table_file}"
echo "INFO: done"
