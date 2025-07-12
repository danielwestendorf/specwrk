#!/bin/sh

export SPECWRK_SRV_SINGLE_RUN=1

exec puma --port ${PORT:-$SPECWRK_SRV_PORT} --bind tcp://0.0.0.0 --threads 1 --workers 0 --silent
