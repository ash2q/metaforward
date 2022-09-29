#!/bin/sh

__ln=( $( ls -Lon "$1" ) )
__size=${__ln[3]}
echo "Size of $1 is: $__size bytes"

echo "There is $((510 - $__size)) bytes remaining to use"