#!/bin/bash

# Set of properties for all scripts. This file should be modified for specific
# customization.
#
# Author: Andres Gomez
# Version: 2025-07-17

# Database configuration.
# shellcheck disable=SC2034
declare -r DBNAME="notes"
# shellcheck disable=SC2034
declare -r DB_USER="notes"

# Email configuration for reports.
declare -r EMAILS="username@domain.com"

# OpenStreetMap API configuration.
# shellcheck disable=SC2034
declare -r OSM_API="https://api.openstreetmap.org/api/0.6"

# OpenStreetMap Planet dump URL.
# shellcheck disable=SC2034
declare -r PLANET="https://planet.openstreetmap.org"

# Overpass interpreter URL. Used to download the countries and maritime boundaries.
# shellcheck disable=SC2034
declare -r OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"

# Rate limiting configuration.
# Wait between loops when downloading boundaries, to prevent "Too many requests".
# shellcheck disable=SC2034
declare -r SECONDS_TO_WAIT="30"

# Processing configuration.
# Quantity of notes to process per loop, to get the location of the note.
# shellcheck disable=SC2034
declare -r LOOP_SIZE="10000"

# Maximum number of notes to download from the API.
declare -r MAX_NOTES="10000"

# Parallel processing configuration.
# Number of threads to use in parallel processing.
# It should be less than the number of cores of the server.
# shellcheck disable=SC2034
declare MAX_THREADS="4"
MAX_THREADS=$(nproc)
