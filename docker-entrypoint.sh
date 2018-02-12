#!/bin/sh

set -x

socat tcp-listen:2375,fork,reuseaddr unix-connect:/var/run/docker.sock

exec "$@"