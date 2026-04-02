#!/bin/sh
set -eu

swift build -Xswiftc -warnings-as-errors >/dev/null
