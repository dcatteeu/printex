#!/bin/bash

# Make a thumbnail of all files in current directory.
# Usage: thumbit.sh 

## Some constants.
ROOT=~/Research/scrap/vlastreffen_2010/
LOGO=${ROOT}/url.gif # Locatie van het logo tov ROOT.
JPEGEXT=JPG # Kan ook jpeg, jpg, etc. zijn.
THUMBS=lr # Thumbnails komen in deze subdirectory met zelfde naam als originele foto. 

## Make the subdir for thumbnails.
mkdir ${THUMBS}

## For all files with JPEG extension:
for i in *.${JPEGEXT}
do
    if [[ -f ${i} ]] # Test if file (and not dir).
    then
	echo ${i}

	## Strip profiles, resize and compose with logo.
        ## Original remains untouched.
	convert ${i} -density 72 -sampling-factor 1x1 -quality 95 -filter lanczos -strip -resize '370x370' ${LOGO} -geometry +0+175 -composite ${THUMBS}/${i}

    fi
done
