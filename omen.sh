#!/bin/sh

cd "$(dirname "$(readlink -f "$0")")"

exec sh odysseus.sh
