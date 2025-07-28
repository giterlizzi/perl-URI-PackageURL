#!/bin/sh

# sync-purl-tests - Sync the PURL tests
#
# (C) 2025, Giuseppe Di Terlizzi <giuseppe.diterlizzi@gmail.com>

cd $(dirname $0) ; CWD=$(pwd)

PURL_ARCHIVE_URL="https://github.com/package-url/purl-spec/archive/refs/heads/main.zip"
PURL_ARCHIVE_FILE=$(mktemp)

mkdir -p $CWD/official-tests
rm $CWD/official-tests/*

wget -O $PURL_ARCHIVE_FILE $PURL_ARCHIVE_URL
unzip -j $PURL_ARCHIVE_FILE 'purl-spec-main/tests/*' -d $CWD/official-tests

rm $PURL_ARCHIVE_FILE
