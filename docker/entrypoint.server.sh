#!/bin/sh

export THRUSTER_HTTP_PORT=${PORT:-5138}
export THRUSTER_TARGET_PORT=3000
export THRUSTER_HTTP_IDLE_TIMEOUT=${IDLE_TIMEOUT:-300}

exec thrust pitchfork -c pitchfork.conf
