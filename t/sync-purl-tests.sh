#!/bin/bash

# sync-purl-tests - Sync the PURL tests
#
# (C) 2025, Giuseppe Di Terlizzi <giuseppe.diterlizzi@gmail.com>

cd $(dirname $0) ; CWD=$(pwd)

PURL_ARCHIVE_URL="https://github.com/package-url/purl-spec/archive/refs/heads/main.zip"
PURL_ARCHIVE_FILE=$(mktemp)

mkdir -p $CWD/tests/{spec,types}
rm $CWD/tests/{spec,types}/*

wget -O $PURL_ARCHIVE_FILE $PURL_ARCHIVE_URL
unzip -j $PURL_ARCHIVE_FILE 'purl-spec-main/tests/spec/*'  -d $CWD/tests/spec
unzip -j $PURL_ARCHIVE_FILE 'purl-spec-main/tests/types/*' -d $CWD/tests/types

rm $PURL_ARCHIVE_FILE
