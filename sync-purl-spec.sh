#!/bin/bash

# sync-purl-spec - Sync the PURL specs
#
# (C) 2025, Giuseppe Di Terlizzi <giuseppe.diterlizzi@gmail.com>

cd $(dirname $0) ; CWD=$(pwd)

PURL_ARCHIVE_URL="https://github.com/package-url/purl-spec/archive/refs/heads/main.zip"
PURL_ARCHIVE_FILE=$(mktemp)

rm -rf $CWD/lib/URI/PackageURL/resources/types/*

mkdir -p $CWD/lib/URI/PackageURL/resources/types/

wget -O $PURL_ARCHIVE_FILE $PURL_ARCHIVE_URL
unzip -j $PURL_ARCHIVE_FILE 'purl-spec-main/types/*.json'  -d $CWD/lib/URI/PackageURL/resources/types
rm $PURL_ARCHIVE_FILE
