#!/usr/bin/env bash

set +e

OUTPUT=$1
shift

if [[ ! "$OUTPUT" ]]; then
	echo "output file required"
	echo "usage: $0 libcombined.a libx.a liby.a libz.a"
	exit 1
fi
if [[ ! $1 ]]; then
	echo "at least one library is required"
	echo "usage: $0 $OUTPUT libx.a liby.a libz.a"
	exit 1
fi

# create temp directory and delete on exit
OUTPUT_TMP=$(mktemp -d "$OUTPUT.XXXXX")
trap "rm -r '$OUTPUT_TMP'" EXIT

# copy all source libraries
for LIB in "$@"; do
	cp "$LIB" "$OUTPUT_TMP"
done

# extract each library into .o files
pushd "${OUTPUT_TMP}" > /dev/null
for LIB in "$@"; do
	ar -x $(basename "$LIB")
done
popd > /dev/null

# create new archive from all .o files
rm -f "$OUTPUT"
ar -rcs "$OUTPUT" $OUTPUT_TMP/*.o
