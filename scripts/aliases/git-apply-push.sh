#!/bin/sh
# Apply all root-level patch files in the current Git directory, then push.
# Never delete patches if git am or git push fails.

set -- ./*.patch
if [ ! -f "$1" ]; then
    echo "No patch files found." >&2
    exit 1
fi

git am "$@" && git push && rm -f -- "$@"
