#!/bin/bash

# Set of properties for all scripts.
#
# Author: Andres Gomez
# Version: 2023-10-06

# Name of the Postgresql database to connect.
# shellcheck disable=SC2034
declare -r DBNAME=notes

# Mails to send the report to.
declare -r EMAILS="${EMAILS:-angoca@yahoo.com}"

# Overpass interpreter.
# shellcheck disable=SC2034
declare -r OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"