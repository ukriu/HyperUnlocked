#!/usr/bin/env python3
"""
Convert device feature XML files into JSON files.

Usage:
    python3 xml2json.py --src /path/to/dev_feat/ --dst /dest/to/json/
"""

import argparse
import json
import os
import xml.etree.ElementTree as ET
from typing import Any, List, Dict
import sys

# return to a python value for a given xml element based on its tag.
def _parse_value(tag: str, element: ET.Element) -> Any:
    text = (element.text or "").strip()
    if tag == "bool":
        return text.lower() == "true"
    if tag == "integer":
        return int(text) if text else 0
    if tag == "float":
        return float(text) if text else 0.0
    if tag == "string":
        return text
    if tag.endswith("-array"):
        items = [itm.text or "" for itm in element.findall("item")]
        if tag == "integer-array":
            return [int(itm) for itm in items if itm]
        if tag == "float-array":
            return [float(itm) for itm in items if itm]
        # string-array or other array types
        return items
    # fallback for unknown types
    return text

# convert a xml file to a json structure.
def xml2json(xml_path: str, include_arrays: bool = False) -> List[Dict[str, Any]]:
    tree = ET.parse(xml_path)
    root = tree.getroot()
    features: List[Dict[str, Any]] = []
    for child in root:
        tag = child.tag  # => 'bool', 'integer', 'string-array', ...
        # skip array types unless explicitly requested
        if not include_arrays and tag in ("string-array", "integer-array"):
            continue
        name = child.attrib.get("name")
        if not name:
            # just skip elements without 'name' attribute
            continue
        feature_entry = {
            "name": name,
            "type": "boolean" if tag == "bool" else tag,
            "value": _parse_value(tag, child),
        }
        features.append(feature_entry)
    # sort by name for deterministic output
    features.sort(key=lambda item: item["name"])
    return features

def main() -> None:
    parser = argparse.ArgumentParser(description="Convert device feature XMLs to JSON")
    parser.add_argument(
        "--src",
        help="Directory containing source XML files",
    )
    parser.add_argument(
        "--dst",
        help="Target directory for generated JSON files",
    )
    # New flag to include array-type features
    parser.add_argument(
        "-a", "--all",
        action="store_true",
        help="Include arrays (not recommended)",
    )
    if len(sys.argv) == 1:
        parser.print_help()
        return
    args = parser.parse_args()
    src_dir = os.path.abspath(args.src)
    dst_dir = os.path.abspath(args.dst)
    os.makedirs(dst_dir, exist_ok=True)
    xml_files = [f for f in os.listdir(src_dir) if f.endswith(".xml")]
    if not xml_files:
        print("No XML files found")
        return
    for xml_file in xml_files:
        xml_path = os.path.join(src_dir, xml_file)
        json_filename = os.path.splitext(xml_file)[0] + ".json"
        json_path = os.path.join(dst_dir, json_filename)
        try:
            data = xml2json(xml_path, include_arrays=args.all)
            with open(json_path, "w", encoding="utf-8") as fh:
                json.dump(data, fh, ensure_ascii=False, indent=4)
            print(f"Cooked {xml_file} -> {json_filename}")
        finally:
            print("Done!")




if __name__ == "__main__":
    main() 