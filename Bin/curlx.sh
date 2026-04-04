#!/usr/bin/env bash

set -x

# usage: curlx <url> <file name>
curl -C - --progress-bar -L "$1" -o "$2"
