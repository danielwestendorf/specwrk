#!/bin/sh

export THRUSTER_HTTP_PORT=${PORT:-5138}
export THRUSTER_TARGET_PORT=3000
export THRUSTER_HTTP_IDLE_TIMEOUT=${IDLE_TIMEOUT:-305}

exec thrust puma --workers 0 --bind tcp://127.0.0.1:3000 --threads ${PUMA_THREADS:-1}
