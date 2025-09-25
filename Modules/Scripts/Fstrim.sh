#!/bin/sh

for partition in system vendor data cache metadata odm system_ext product; do
    fstrim -v "/$partition"
    sleep 0.1
done