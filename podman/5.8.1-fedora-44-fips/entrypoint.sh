#!/bin/bash
################################################################################
# Podman FIPS Entrypoint Script
################################################################################
# This script sets FIPS environment variables at runtime and then executes
# the command passed to the container.

# Set Go FIPS environment variables for strict FIPS enforcement
export GOLANG_FIPS=1
export GODEBUG=fips140=only
export GOEXPERIMENT=strictfipsruntime

# Execute the command passed to the container
exec "$@"
