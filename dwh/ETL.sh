#!/bin/bash

# ETL process that takes the notes and its comments and populates a table which
# is easy to read from the OSM Notes profile.
# When this ETL is run, it updates each note and comment with an associated
# code.
# The execution of this ETL is independent of the process that retrieves the
# notes from Planet and API. This allows a longer execution that the periodic
# poll for new notes.
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
#
# Author: Andres Gomez (AngocA)
# Version: 2022-12-06
declare -r VERSION="2022-12-06"

# TODO Hay un problema con los nombres de usuario que tiene comilla sencilla.
# Como parte del proceso lo esta duplicando.

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with an non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# Error codes.
# 1: Help message.
declare -r ERROR_HELP_MESSAGE=1
# 241: Library or utility missing.
declare -r ERROR_MISSING_LIBRARY=241
# 242: Invalid argument for script invocation.
declare -r ERROR_INVALID_ARGUMENT=242
# 243: Logger utility is not available.
declare -r ERROR_LOGGER_UTILITY=243

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory, where the ticket script resides.
# Taken from https://stackoverflow.com/questions/59895/how-can-i-get-the-source-directory-of-a-bash-script-from-within-the-script-itsel
# shellcheck disable=SC2155
declare -r SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" \
  &> /dev/null && pwd)"

# Logger framework.
# Taken from https://github.com/DushyanthJyothi/bash-logger.
declare -r LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/bash_logger.sh"

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporal directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
# Lof file for output.
declare LOG_FILE
LOG_FILE="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILE

# Lock file for single execution.
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Name of the PostgreSQL database to insert or update the data.
declare -r DBNAME=notes

# Name of the SQL script that contains the ETL.
declare -r ETL_FILE="${SCRIPT_BASE_DIRECTORY}/ETL.sql"

###########
# FUNCTIONS

### Logger

# Loads the logger (log4j like) tool.
# It has the following functions.
# __log default.
# __logt for trace.
# __logd for debug.
# __logi for info.
# __logw for warn.
# __loge for error. Writes in standard error.
# __logf for fatal.
# Declare mock functions, in order to have them in case the logger utility
# cannot be found.
function __log() { :; }
function __logt() { :; }
function __logd() { :; }
function __logi() { :; }
function __logw() { :; }
function __loge() { :; }
function __logf() { :; }
function __log_start() { :; }
function __log_finish() { :; }

# Starts the logger utility.
function __start_logger() {
 if [[ -f "${LOGGER_UTILITY}" ]] ; then
  # Starts the logger mechanism.
  set +e
  # shellcheck source=./bash_logger.sh
  source "${LOGGER_UTILITY}"
  local -i RET=${?}
  set -e
  if [[ "${RET}" -ne 0 ]] ; then
   printf "\nERROR: Invalid logger framework file.\n"
   exit "${ERROR_LOGGER_UTILITY}"
  fi
  # Logger levels: TRACE, DEBUG, INFO, WARN, ERROR.
  __bl_set_log_level "${LOG_LEVEL}"
  __logd "Logger loaded."
 else
  printf "\nLogger was not found.\n"
 fi
}

# Function that activates the error trap.
function __trapOn() {
 __log_start
 trap '{ printf "%s ERROR: The script did not finish correctly. Line number: %d.\n" "$(date +%Y%m%d_%H:%M:%S)" "${LINENO}"; exit ;}' \
   ERR
 trap '{ printf "%s WARN: The script was terminated.\n" "$(date +%Y%m%d_%H:%M:%S)"; exit ;}' \
   SIGINT SIGTERM
 __log_finish
}

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This is an ETL script that takes the data from notes and comments and"
 echo "process it into a star schema. This schema allows an easier access from"
 echo "the OSM Notes profile."
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 ## PostgreSQL
 if ! psql --version > /dev/null 2>&1 ; then
  __loge "ERROR: PostgreSQL is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## flock
 if ! flock --version > /dev/null 2>&1 ; then
  __loge "ERROR: flock is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Bash 4 or greater.
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]] ; then
  __loge "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
 set -e
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 __logi "Creating star model"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  CREATE SCHEMA IF NOT EXISTS dwh;

  CREATE TABLE IF NOT EXISTS dwh.facts (
   id_note INTEGER NOT NULL, -- id
   created_at TIMESTAMP NOT NULL,
   created_id_user INTEGER,
   closed_at TIMESTAMP,
   closed_id_user INTEGER,
   id_country INTEGER,
   action_comment note_event_enum,
   action_id_user INTEGER,
   action_at TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS dwh.dimension_users (
   user_id INTEGER NOT NULL,
   username VARCHAR(256)
  );

  ALTER TABLE dwh.dimension_users
   ADD CONSTRAINT pk_user_dim
   PRIMARY KEY (user_id);

  ALTER TABLE dwh.facts
   ADD CONSTRAINT fk_users_created
   FOREIGN KEY (created_id_user)
   REFERENCES dwh.dimension_users (user_id);

  ALTER TABLE dwh.facts
   ADD CONSTRAINT fk_users_closed
   FOREIGN KEY (closed_id_user)
   REFERENCES dwh.dimension_users (user_id);

  ALTER TABLE dwh.facts
   ADD CONSTRAINT fk_users_action
   FOREIGN KEY (action_id_user)
   REFERENCES dwh.dimension_users (user_id);

  CREATE TABLE IF NOT EXISTS dwh.dimension_countries (
   country_id INTEGER NOT NULL,
   country_name VARCHAR(100),
   country_name_es VARCHAR(100),
   country_name_en VARCHAR(100)
-- ToDo Include the regions
  );

  ALTER TABLE dwh.dimension_countries
   ADD CONSTRAINT pk_countries_dim
   PRIMARY KEY (country_id);

  ALTER TABLE dwh.facts
   ADD CONSTRAINT fk_country
   FOREIGN KEY (id_country)
   REFERENCES dwh.dimension_countries (country_id);
EOF
 __log_finish
}

# Processes the notes and comments.
function __processNotes {
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${ETL_FILE}"
}

######
# MAIN

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

{
 __start_logger
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}"
 __logi "Processing: ${PROCESS_TYPE}"
} >> "${LOG_FILE}" 2>&1

if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
 __show_help
fi
__checkPrereqs
{
 __logw "Starting process"
 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"
 __logw "Validating single execution."
 flock -n 7

 __createBaseTables
 __processNotes

 __logw "Ending process"
} >> "${LOG_FILE}" 2>&1

if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]] ; then
 mv "${LOG_FILE}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
 rmdir "${TMP_DIR}"
fi
