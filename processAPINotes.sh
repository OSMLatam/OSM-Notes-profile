#!/bin/bash

# This scripts processes the most recents notes (creation or modification) from
# the OpenStreetMap API.
# * It downloads the notes via HTTP call.
# * Then with an XSLT transformation converts the data into flat files.
# * It uploads the data into temp tables of a PostreSQL database.
# * Finally, it synchronizes the master tables.
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument.
# 243) Logger utility is missing.
#
# Author: Andres Gomez (AngocA)
# Version: 2022-11-22
declare -r VERSION="2022-11-22"

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

# If all files should be deleted. In case of an error, this could be disabled.
# You can defined when calling: export CLEAN=false
declare -r CLEAN="${CLEAN:-true}"

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-FATAL}"

# Logger framework.
# Taken from https://github.com/DushyanthJyothi/bash-logger.
declare -r LOGGER_UTILITY=bash_logger.sh

# Base directory, where the ticket script resides.
# Taken from https://stackoverflow.com/questions/59895/how-can-i-get-the-source-directory-of-a-bash-script-from-within-the-script-itsel
# shellcheck disable=SC2155
declare -r SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" \
  &> /dev/null && pwd)"

# Temporal directory for all files.
#TODO declare -r TMP_DIR=$(mktemp -d "/tmp/${0%.sh}_XXXXXX")
TMP_DIR=./
# Lof file for output.
declare -r LOG_FILE="${TMP_DIR}/${0%.sh}.log"

# Type of process to run in the script: base, sync or boundaries.
declare -r PROCESS_TYPE=${1:-}

# XML Schema of the API notes file.
declare -r XMLSCHEMA_API_NOTES="OSM-notes-API-schema.xsd"
# Jar name of the XSLT processor.
declare -r SAXON_JAR="${SAXON_CLASSPATH:-.}/saxon-he-11.4.jar"
# Name of the file of the XSLT transformation for notes from API.
declare -r XSLT_NOTES_API_FILE="notes-API-csv.xslt"
# Name of the file of the XSLT transformation for note comments from API.
declare -r XSLT_NOTE_COMMENTS_API_FILE="note_comments-API-csv.xslt"
# Filename for the flat file for notes.
declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/output-notes.csv"
# Filename for the flat file for comment notes.
declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/output-note_comments.csv"

# Name of the PostgreSQL database to insert or update the data.
declare -r DBNAME=notes

# Temporal file that contiains the downloaded notes from the API.
declare -r API_NOTES_FILE="${TMP_DIR}/OSM-notes-API.xml"

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
 if [ -f "${SCRIPT_BASE_DIRECTORY}/${LOGGER_UTILITY}" ] ; then
  # Starts the logger mechanism.
  set +e
  # shellcheck source=./bash_logger.sh
  source "${SCRIPT_BASE_DIRECTORY}/${LOGGER_UTILITY}"
  local -i RET=${?}
  set -e
  if [ ${RET} -ne 0 ] ; then
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
 trap '{ printf "%s ERROR: The script did not finish correctly. Line number: %d.\n" "$(date +%Y-%m-%d_%H:%M:%S)" "${LINENO}"; exit ;}' \
   ERR
 trap '{ printf "%s WARN: The script was terminated.\n" "$(date +%Y%m%d_%H:%M:%S)"; exit 1 ;}' \
   SIGINT SIGTERM
 __log_finish
}

# Shows the help information.
function __show_help {
 __log_start
  echo "${0} version ${VERSION}."
  echo
  echo "This is a script that downloads the OSM notes from the OpenStreetMap"
  echo "API. It takes the most recent ones and synchronizes a database that"
  echo "holds the whole history."
  echo
  echo "It does not receive any parameter. This script should be configured"
  echo "in a crontab or similar scheduler."
  echo
  echo "Written by: Andres Gomez (AngocA)."
  echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
  exit "${ERROR_HELP_MESSAGE}"
 __log_finish
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 __logd "Checking process type."
 if [ "${PROCESS_TYPE}" != "" ] && [ "${PROCESS_TYPE}" != "--help" ] \
   && [ "${PROCESS_TYPE}" != "-h" ] ; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string (nothing)."
  echo " * --help"
  __loge "ERROR: Invalid parameter."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 ## PostgreSQL
 __logd "Checking PostgreSQL."
 if ! psql --version > /dev/null 2>&1 ; then
  echo "ERROR: PostgreSQL is missing."
  __loge "ERROR: PostgreSQL is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Wget
 __logd "Checking wget."
 if ! wget --version > /dev/null 2>&1 ; then
  echo "ERROR: Wget is missing."
  __loge "ERROR: Wget is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## osmtogeojson
 __logd "Checking OSMtoGeoJSON."
 if ! osmtogeojson --version > /dev/null 2>&1 ; then
  echo "ERROR: osmtogeojson is missing."
  __loge "ERROR: osmtogeojson is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## gdal ogr2ogr
 __logd "Checking GDAL ogr2ogr."
 if ! ogr2ogr --version > /dev/null 2>&1 ; then
  echo "ERROR: ogr2ogr is missing."
  __loge "ERROR: ogr2ogr is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## cURL
 __logd "Checking cURL."
 if ! curl --version > /dev/null 2>&1 ; then
  echo "ERROR: curl is missing."
  __loge "ERROR: curl is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Java
 __logd "Checking Java."
 if ! java --version > /dev/null 2>&1 ; then
  echo "ERROR: Java JRE is missing."
  __loge "ERROR: Java JRE is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XML lint
 __logd "Checking XML lint."
 if ! xmllint --version > /dev/null 2>&1 ; then
  echo "ERROR: XMLlint is missing."
  __loge "ERROR: XMLlint is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Saxon Jar
 __logd "Checking Saxon Jar."
 if [ ! -r "${SAXON_JAR}" ] ; then
  echo "ERROR: Saxon jar is missing at ${SAXON_JAR}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Bash 4 or greater.
 __logd "Checking Bash version."
 if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  echo "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 __log_finish
 set -e
}

# Drop tables for notes from API.
function __dropApiTables {
 __log_start
 __logi "Droping tables."
 psql -d "${DBNAME}" << EOF
  DROP TABLE note_comments_api;
  DROP TABLE notes_api;
EOF
 __log_finish
}

# Creates tables for notes from API.
function __createApiTables {
 __log_start
 __logi "Creating tables"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF 
  CREATE TABLE notes_api (
   note_id INTEGER NOT NULL,
   latitude DECIMAL NOT NULL,
   longitude DECIMAL NOT NULL,
   created_at TIMESTAMP NOT NULL,
   closed_at TIMESTAMP,
   status note_status_enum,
   id_country INTEGER
  );
 
  CREATE TABLE note_comments_api (
   note_id INTEGER NOT NULL,
   event note_event_enum NOT NULL,
   created_at TIMESTAMP NOT NULL,
   user_id INTEGER,
   username VARCHAR(256)
  );
EOF
 __log_finish
}

# Creates table properties during the execution.
function __createPropertiesTable {
 __log_start
 __logi "Creating properties table"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  DO
  \$\$
  DECLARE
   last_update VARCHAR(32);
   new_last_update VARCHAR(32);
   qty INT;
  BEGIN
   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'execution_properties'
   ;

   IF (qty = 0) THEN
    EXECUTE 'CREATE TABLE execution_properties ('
      || 'key VARCHAR(256) NOT NULL,'
      || 'value VARCHAR(256)'
      || ')';
   END IF;

   SELECT MAX(TIMESTAMP) INTO new_last_update
   FROM (
    SELECT MAX(created_at) TIMESTAMP
    FROM notes
    UNION
    SELECT MAX(closed_at) TIMESTAMP
    FROM notes
    UNION
    SELECT MAX(created_at) TIMESTAMP
    FROM note_comments
   ) T;

   SELECT value INTO last_update
     FROM execution_properties
     WHERE key = 'lastUpdate';

   IF (last_update IS NULL) THEN
    INSERT INTO execution_properties VALUES
      ('lastUpdate', last_update);
   ELSE
    UPDATE execution_properties
      SET value = new_last_update
      WHERE key = 'lastUpdate';
   END IF;
  END;
  \$\$;

EOF
 __log_finish
}
 

# Gets the new notes
function __getNewNotesFromApi {
 __log_start
 declare TEMP_FILE="${TMP_DIR}/last_update_value.txt"
 # Gets the most recent value on the database.
  psql -d "${DBNAME}" -Atq \
    -c "SELECT TO_CHAR(TO_DATE(value, 'YYYY-MM-DD HH24:MI:SS') at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM execution_properties WHERE KEY = 'lastUpdate'" \
    -v ON_ERROR_STOP=1 > "${TEMP_FILE}" 2> /dev/null
 LAST_UPDATE=$(cat "${TEMP_FILE}")
 __logt "Last update ${LAST_UPDATE}"

 # Gets the values from OSM API.
 wget -O "${API_NOTES_FILE}" \
   "https://api.openstreetmap.org/api/0.6/notes/search.xml?closed=-1&from=${LAST_UPDATE}"

 rm "${TEMP_FILE}"
 __log_finish
}

# Validates the XML file to be sure everything will work fine.
function __validateApiNotesXMLFile {
 __log_start
 xmllint --noout --schema "${XMLSCHEMA_API_NOTES}" "${API_NOTES_FILE}"
 __log_finish
}

# Creates the XSLT files and process the XML files with them.
# The CSV file structure for notes is:
# 3451247,29.6141093,-98.4844977,"2022-11-22 02:13:03 UTC",,"open"
# 3451210,39.7353700,-104.9626400,"2022-11-22 01:30:39 UTC","2022-11-22 02:09:32 UTC","close"
#
# The CSV file structure for comments is:
# 3450803,'opened','2022-11-21 17:13:10 UTC',17750622,'Juanmiguelrizogonzalez'
# 3450803,'closed','2022-11-22 02:06:53 UTC',15422751,'GHOSTsama2503'
# 3450803,'reopened','2022-11-22 02:06:58 UTC',15422751,'GHOSTsama2503'
# 3450803,'commented','2022-11-22 02:07:24 UTC',15422751,'GHOSTsama2503'
function __convertApiNotesToFlatFile {
 __log_start
 # Process the notes file.
 # XSLT transformations.
 cat << EOF > "${XSLT_NOTES_API_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" />
<xsl:template match="/">
 <xsl:for-each select="osm/note"><xsl:value-of select="id"/>,<xsl:value-of select="@lat"/>,<xsl:value-of select="@lon"/>,"<xsl:value-of select="date_created"/>",<xsl:choose><xsl:when test="date_closed != ''">"<xsl:value-of select="date_closed"/>","close"
</xsl:when><xsl:otherwise>,"open"<xsl:text>
</xsl:text></xsl:otherwise></xsl:choose>
 </xsl:for-each>
</xsl:template>
</xsl:stylesheet>
EOF

 cat << EOF > "${XSLT_NOTE_COMMENTS_API_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" />
<xsl:template match="/">
 <xsl:for-each select="osm/note">
 <xsl:variable name="note_id"><xsl:value-of select="id"/></xsl:variable>
  <xsl:for-each select="comments/comment">
<xsl:choose> <xsl:when test="uid != ''"> <xsl:copy-of select="\$note_id" />,'<xsl:value-of select="action" />','<xsl:value-of select="date"/>',<xsl:value-of select="uid"/>,'<xsl:value-of select="replace(user,'''','''''')"/>'<xsl:text>
</xsl:text></xsl:when><xsl:otherwise>
<xsl:copy-of select="\$note_id" />,'<xsl:value-of select="action" />','<xsl:value-of select="date"/>',,<xsl:text>
</xsl:text></xsl:otherwise> </xsl:choose>
  </xsl:for-each>
 </xsl:for-each>
</xsl:template>
</xsl:stylesheet>
EOF

 # Converts the XML into a flat file in CSV format.
 java -Xmx1000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
   -s:"${API_NOTES_FILE}" -xsl:"${XSLT_NOTES_API_FILE}" \
   -o:"${OUTPUT_NOTES_FILE}"
 java -Xmx1000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
   -s:"${API_NOTES_FILE}" -xsl:"${XSLT_NOTE_COMMENTS_API_FILE}" \
   -o:"${OUTPUT_NOTE_COMMENTS_FILE}"

 grep "<note>" ${API_NOTES_FILE} | wc -l
 head "${OUTPUT_NOTES_FILE}"
 wc -l "${OUTPUT_NOTES_FILE}"
 grep "<comment>" ${API_NOTES_FILE} | wc -l
 head "${OUTPUT_NOTE_COMMENTS_FILE}"
 wc -l "${OUTPUT_NOTE_COMMENTS_FILE}"
 __log_finish
}

# Loads notes from API into the database.
function __loadApiNotes {
 __log_start
 # Loads the data in the database.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  COPY notes_api (note_id, latitude, longitude, created_at, closed_at, status)
    FROM '${OUTPUT_NOTES_FILE}' csv;
  SELECT COUNT(1) FROM notes_api;
  COPY note_comments_api FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv
    DELIMITER ',' QUOTE '''';
  SELECT COUNT(1) FROM note_comments_api;
EOF
 __log_finish
}


# Inserts new notes and comments into the database.
function __insertNewNotesAndComments {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  SELECT COUNT(1) FROM notes;
  DO
  \$\$
   DECLARE
    r RECORD;
    closed_time VARCHAR(100);
    created_time VARCHAR(100);
   BEGIN
     FOR r IN
      SELECT note_id, latitude, longitude, created_at, closed_at, status
      FROM notes_api
     LOOP
      closed_time := 'TO_DATE(''' || r.closed_at
        || ''', ''YYYY-MM-DD HH24:MI:SS'')';
      EXECUTE 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
        || r.longitude || ', ' 
        || 'TO_DATE(''' || r.created_at || ''', ''YYYY-MM-DD HH24:MI:SS''), '
        || COALESCE (closed_time, 'NULL') || ','
        || '''' || r.status || '''::note_status_enum)';
     END LOOP;
   END;
  \$\$;
  SELECT COUNT(1) FROM notes;

  SELECT COUNT(1) FROM note_comments;
  DO
  \$\$
   DECLARE
    r RECORD;
    created_time VARCHAR(100);
   BEGIN
    FOR r IN
     SELECT note_id, event, created_at, user_id, username
     FROM note_comments_api
    LOOP
     created_time := 'TO_DATE(''' || r.created_at
       || ''', ''YYYY-MM-DD HH24:MI:SS'')';
     EXECUTE 'CALL insert_note_comment (' || r.note_id || ', '
       || '''' || r.event || '''::note_event_enum, '
       || COALESCE (created_time, 'NULL') || ', ' 
       || COALESCE (r.user_id || '', 'NULL') || ', '
       || COALESCE ('''' || r.username || '''', 'NULL') || ')';
    END LOOP;
   END;
  \$\$;
  SELECT COUNT(1) FROM note_comments;
EOF
 __log_finish
}

# Updates the refresh value.
function __updateLastValue {
 __log_start
 __logi "Updating last update time"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  SELECT value FROM execution_properties WHERE key = 'lastUpdate';
  DO
  \$\$
   DECLARE
    last_update VARCHAR(32);
    new_last_update VARCHAR(32);
   BEGIN
    SELECT MAX(TIMESTAMP) INTO new_last_update
    FROM (
     SELECT MAX(created_at) TIMESTAMP
     FROM notes
     UNION
     SELECT MAX(closed_at) TIMESTAMP
     FROM notes
     UNION
     SELECT MAX(created_at) TIMESTAMP
     FROM note_comments
    ) T;
 
    UPDATE execution_properties
     SET value = new_last_update
     WHERE key = 'lastUpdate';
   END;
  \$\$;
  SELECT value FROM execution_properties WHERE key = 'lastUpdate';
EOF
 __log_finish
}

# Clean files generated during the process.
function __cleanNotesFiles {
 __log_start
# ToDo rm "${API_NOTES_FILE}" "${OUTPUT_NOTES_FILE}" "${OUTPUT_NOTE_COMMENTS_FILE}"
 __log_finish
}

######
# MAIN

# Return value for several functions.
declare -i RET

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

{
 __start_logger
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}"
 
 # Sets the trap in case of any signal.
 __trapOn
 __checkPrereqs
 if [ "${PROCESS_TYPE}" == "-h" ] || [ "${PROCESS_TYPE}" == "--help" ]; then
  __show_help
 fi
 __logw "Process started."
 # TODO Locks for only one execution
 __dropApiTables
 __createApiTables
 __createPropertiesTable
 __getNewNotesFromApi
 __validateApiNotesXMLFile
 __convertApiNotesToFlatFile
 __loadApiNotes
 __insertNewNotesAndComments
 __updateLastValue
 __cleanNotesFiles
 __logw "Process finished."
} >> "${LOG_FILE}" 2>&1

if [ -n "${CLEAN}" ] && [ "${CLEAN}" = true ] ; then
 # ToDo mv "${LOG_FILE}" "/tmp/${0%.log}_$(date +%Y-%m-%d_%H-%M-%S).log"
 rmdir "${TMP_DIR}"
fi