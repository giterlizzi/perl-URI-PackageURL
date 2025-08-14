#!/bin/bash

# sync-purl-tests - Sync the PURL and VERS tests
#
# (C) 2025, Giuseppe Di Terlizzi <giuseppe.diterlizzi@gmail.com>

cd $(dirname $0) ; CWD=$(pwd)

PURL_ARCHIVE_URL="https://github.com/package-url/purl-spec/archive/refs/heads/main.zip"
PURL_ARCHIVE_FILE=$(mktemp)

VERS_ARCHIVE_URL="https://github.com/package-url/vers-spec/archive/refs/heads/main.zip"
VERS_ARCHIVE_FILE=$(mktemp)

rm -rf $CWD/{purl,vers}/*

mkdir -p $CWD/{purl,vers}
mkdir -p $CWD/purl/{spec,types}

# PURL tests
wget -O $PURL_ARCHIVE_FILE $PURL_ARCHIVE_URL
unzip -j $PURL_ARCHIVE_FILE 'purl-spec-main/tests/spec/*'  -d $CWD/purl/tests/spec
unzip -j $PURL_ARCHIVE_FILE 'purl-spec-main/tests/types/*' -d $CWD/purl/tests/types
rm $PURL_ARCHIVE_FILE

# VERS tests
wget -O $VERS_ARCHIVE_FILE $VERS_ARCHIVE_URL
unzip -j $VERS_ARCHIVE_FILE 'vers-spec-main/tests/*'  -d $CWD/vers/tests
rm $VERS_ARCHIVE_FILE
