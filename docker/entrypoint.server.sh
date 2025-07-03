#!/bin/sh

exec specwrk serve --port ${PORT:-$SPECWRK_SRV_PORT} --bind 0.0.0.0 --no-single-run --verbose
