#!/bin/sh
# Tests/make-fixtures.sh - build the document fixtures the suite runs against.
#
# Generated rather than committed. These are all text formats, so the generator
# is both smaller and more informative than the files it produces: it states
# exactly what each fixture contains, which is what the assertions read back.
# Usage: make-fixtures.sh <dest-dir>

set -e

dest="${1:?usage: make-fixtures.sh <dest-dir>}"
/bin/mkdir -p "$dest"

# A marker string the conversions carry through, so a test can prove the content
# survived rather than only that a file appeared.
printf 'Hello from plain text. MARKER-TXT\n' > "$dest/notes.txt"

cat > "$dest/page.html" <<'HTML'
<html><head><title>Fixture</title></head>
<body><h1>Heading</h1><p>Hello from html. MARKER-HTML</p></body></html>
HTML

# Real RTF, written out rather than converted, so the fixture set does not
# depend on textutil to build the inputs textutil is being tested on.
cat > "$dest/memo.rtf" <<'RTF'
{\rtf1\ansi\ansicpg1252\cocoartf2639
{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
\pard\f0\fs24 Hello from rtf. MARKER-RTF\
}
RTF

# Not a document textutil can read. The applet lists it anyway - it filters on
# extension, and .bin is not in its list - so this is the fixture for "a file
# that fails at conversion time" rather than "a file that is refused up front".
printf '\000\001\002binary\n' > "$dest/blob.bin"

/bin/chmod a-w "$dest"/* 2>/dev/null || true
