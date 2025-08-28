#!/bin/bash

# This script takes in any revalent xml file and displays values not accounted for by HyperUnlocked
# Requires: xmlstarlet
# Usage: ./clean_xml.sh ORIGINAL_XML.xml module/xml.sh output.xml

FILE1="$1"
FILE2="$2"
OUTPUT="$3"

cp "$FILE1" "$OUTPUT"

# Extract all names from file1.xml
for NAME in $(xmlstarlet sel -t -m "//*[@name]" -v "@name" -n "$FILE1"); do
    # Check if that name exists anywhere in file2
    if grep -q "$NAME" "$FILE2"; then
        # Remove the whole element with that name
        xmlstarlet ed -L -d "//*[@name='$NAME']" "$OUTPUT"
    fi
done

# Remove they stray "$" which exists in many xiaomi xmls so the formatting goes smoothly
sed -i 's/-->\$/-->/g' "$OUTPUT"

# Finally reformat the xml
xmlstarlet fo --indent-tab "$OUTPUT" > "${OUTPUT}.tmp" && mv "${OUTPUT}.tmp" "$OUTPUT"
