#!/bin/bash

# This script checks the loaded notes in the database, with a new planet
# download, and compares the notes. It allows to identify incorrectly
# processed notes. The scripts downloads the notes from planet, and load
# them into a new table for this purpose.
#
# The script structure is:
# * Creates the database structure.
# * Downloads the planet notes.
# * Converts the notes into flat CSV files.
# * Imports the notes into the db.
#
# This is an example about how to call this script:
#
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processCheckPlanetNotes.sh
#
# When running under MacOS or zsh, it is better to invoke bash:
# bash ./processPlanetNotes.sh
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/processCheckPlanetNotes_* | tail -1)/processCheckPlanetNotes.log
#
# The database should already be prepared with base tables for notes.
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
# 247) Error downloading planet notes file.
#
# For contributing, please execute these commands before subimitting:
# * shellcheck -x -o all processCheckPlanetNotes.sh
# * shfmt -w -i 1 -sr -bn processCheckPlanetNotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-07
declare -r VERSION="2025-07-07"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with an non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
 &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Loads the global properties.
# shellcheck source=../../etc/properties.sh
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporal directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
chmod 777 "${TMP_DIR}"
# Lof file for output.
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Lock file for single execution.
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}

# Flat file to start from load.
declare -r FLAT_NOTES_FILE=${2:-}
declare -r FLAT_NOTE_COMMENTS_FILE=${3:-}

# Name of the file to download.
declare -r PLANET_NOTES_NAME="planet-notes-latest.osn"
# Filename fot the OSM Notes from Planet.
declare -r PLANET_NOTES_FILE="${TMP_DIR}/${PLANET_NOTES_NAME}"

# PostgreSQL files.
# Drop check tables.
declare -r POSTGRES_DROP_CHECK_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes-11-dropCheckTables.sql"
# Create check tables.
declare -r POSTGRES_CREATE_CHECK_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes-21-createCheckTables.sql"
# Load check notes.
declare -r POSTGRES_LOAD_CHECK_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes-31-loadCheckNotes.sql"
# Analyze and vacuum.
declare -r POSTGRES_ANALYZE_AND_VACUUM="${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes-41-analyzeAndVacuum.sql"

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

###########
# FUNCTIONS

# shellcheck source=../functionsProcess.sh
source "${FUNCTIONS_FILE}"
# __downloadPlanetNotes
# __validatePlanetNotesXMLFile
# __convertPlanetNotesToFlatFile

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This script checks the loaded notes to validate if their state is"
 echo "correct."
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 __checkPrereqsCommands

 ## Checks the flat file if exist.
 if [[ "${FLAT_NOTES_FILE}" != "" ]] && [[ ! -r "${FLAT_NOTES_FILE}" ]]; then
  __loge "ERROR: The flat file cannot be accessed: ${FLAT_NOTES_FILE}."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 ## Checks the flat file if exist.
 if [[ "${FLAT_NOTE_COMMENTS_FILE}" != "" ]] \
  && [[ ! -r "${FLAT_NOTE_COMMENTS_FILE}" ]]; then
  __loge "ERROR: The flat file cannot be accessed: ${FLAT_NOTE_COMMENTS_FILE}."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_DROP_CHECK_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_DROP_CHECK_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_CREATE_CHECK_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_CREATE_CHECK_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_LOAD_CHECK_NOTES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_LOAD_CHECK_NOTES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_ANALYZE_AND_VACUUM}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_ANALYZE_AND_VACUUM}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
 set -e
}

# Drop check tables.
function __dropCheckTables {
 __log_start
 __logi "Droping check tables."
 psql -d "${DBNAME}" -f "${POSTGRES_DROP_CHECK_TABLES}" 2>&1
 __log_finish
}

# Creates check tables that receives the whole history.
function __createCheckTables {
 __log_start
 __logi "Creating tables."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_CREATE_CHECK_TABLES}"
 __log_finish
}

# Loads new notes from check.
function __loadCheckNotes {
 __log_start
 # Loads the data in the database.
 export OUTPUT_NOTES_FILE
 export OUTPUT_NOTE_COMMENTS_FILE
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$OUTPUT_NOTES_FILE,$OUTPUT_NOTE_COMMENTS_FILE' \
   < "${POSTGRES_LOAD_CHECK_NOTES}" || true)"
 __log_finish
}

# Calculates statistics on all tables and vacuum.
function __analyzeAndVacuum {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_ANALYZE_AND_VACUUM}"
 __log_finish
}

# Cleans files generated during the process.
function __cleanNotesFiles {
 __log_start
 rm -f "${PLANET_NOTES_FILE}.xml" "${OUTPUT_NOTES_FILE}" \
  "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
 __log_finish
}

######
# MAIN

function main() {
 __log_start
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Processing: ${PROCESS_TYPE}."

 if [[ "${PROCESS_TYPE}" == "-h" ]] \
  || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi
 __checkPrereqs
 __logw "Starting process."

 # Sets the trap in case of any signal.
 __trapOn
 if [[ "${PROCESS_TYPE}" != "--flatfile" ]]; then
  exec 7> "${LOCK}"
  __logw "Validating single execution."
  ONLY_EXECUTION="no"
  flock -n 7
  ONLY_EXECUTION="yes"
 fi

 __dropCheckTables
 __createCheckTables
 __downloadPlanetNotes 2>&1
 __validatePlanetNotesXMLFile
 __convertPlanetNotesToFlatFile
 __loadCheckNotes
 __analyzeAndVacuum
 __cleanNotesFiles
 __logw "Ending process."
 __log_finish
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ ! -t 1 ]]; then
 __set_log_file "${LOG_FILENAME}"
 main >> "${LOG_FILENAME}"
 mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
 rmdir "${TMP_DIR}"
else
 main
fi
