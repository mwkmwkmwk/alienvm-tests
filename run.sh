#!/bin/sh

for t in hello rot13 block sha512 rc4
do

echo -n "$t... "
if python3 $t.py
then
	echo ok
fi

done
