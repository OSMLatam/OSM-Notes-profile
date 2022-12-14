#!/usr/bin/env bash

###################################################
# Script to print log4j style messages for logging
# at different levels:
#	TRACE > DEBUG > INFO > WARN > ERROR > FATAL
#
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
# Author : Dushyanth Jyothi
# Copyright (c) 2017 Dushyanth Jyothi
# Usage: please see test.sh script
##################################################

# TODO(dushyanth): lots of repeat code (improve)

#set -u
set -e

declare -rA __bl_all_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG [INFO]=INFO [WARN]=WARN [ERROR]=ERROR [FATAL]=FATAL)
__bl_requested_log_type="INFO"




function __bl_set_log_level() {
  if [ -z "$1" ]; then
		echo "please provide log level"
  else
		__bl_requested_log_type="$1"
		if [[ ! "${__bl_all_log_levels[${__bl_requested_log_type}]+isset}" ]]; then
			__bl_requested_log_type="INFO"
		fi
	fi
}



# Default log : INFO
# '__' so not to confilct with '_' if any private funcs
# declared in the parent script
function __log() {
	local __bl_log_message_type
	__bl_log_message_type="INFO"

	local __bl_script_name
	__bl_script_name="${BASH_SOURCE[1]}"
	__bl_script_name="${__bl_script_name##*/}"

	local __bl_function_name
	__bl_function_name="${FUNCNAME[1]}"

  local __bl_called_line_number
  __bl_called_line_number="${BASH_LINENO[0]}"

	local __bl_log_message
	__bl_log_message="$*"

	local time_and_date
	time_and_date=$(date '+%Y-%m-%d %H:%M:%S')
	echo "${time_and_date} [${__bl_script_name}:${__bl_function_name}:line:${__bl_called_line_number}] ${__bl_log_message_type} - ${__bl_log_message}"
}

# TRACE: designates finer-grained informational events than the DEBUG
function __logt() {
	declare -A __bl_allowed_log_levels
	__bl_allowed_log_levels=([TRACE]=TRACE)
	if [[ "${__bl_allowed_log_levels[${__bl_requested_log_type}]+isset}" ]]; then
		__bl_log_message_type="TRACE"

  	local __bl_script_name
		__bl_script_name="${BASH_SOURCE[1]}"
		__bl_script_name="${__bl_script_name##*/}"

		local __bl_function_name
		__bl_function_name="${FUNCNAME[1]}"

		local __bl_called_line_number
		__bl_called_line_number="${BASH_LINENO[0]}"


		local __bl_log_message
  	__bl_log_message="$*"

		local __bl_functions_length
		__bl_functions_length=${#FUNCNAME[@]}

		#${FUNCNAME[$i]} was called from the file ${BASH_SOURCE[$i+1]} at line number ${BASH_LINENO[$i]}
    local time_and_date
    time_and_date=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${time_and_date} [${__bl_script_name}:${__bl_function_name}:line:${__bl_called_line_number}] ${__bl_log_message_type} - ${__bl_log_message}"

  if [ ${#FUNCNAME[@]} -gt 2 ]; then
    echo "${time_and_date} [${__bl_script_name}:${__bl_function_name}:line:${__bl_called_line_number}] ${__bl_log_message_type} - Execution call stack:"
  fi

		for (( i=0; i < __bl_functions_length; i++ )); do
    	if [ ! "$i" ==  $(( __bl_functions_length - 1 )) ]; then
				if [[ "${BASH_SOURCE[$i]}" != *"bash_logger"* ]]; then
           echo "   ${BASH_SOURCE[$i+1]//.\//}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}(..)"
				fi
    	else
        echo "   ${BASH_SOURCE[$i]//.\//}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}(..)"
    	fi
  	done
	fi
}


# DEBUG: designates fine-grained informational events that are most useful to debug an application.
function __logd() {
  declare -A __bl_allowed_log_levels
	__bl_allowed_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG)
	if [[ "${__bl_allowed_log_levels[${__bl_requested_log_type}]+isset}" ]]; then
    __bl_log_message_type="DEBUG"

    local __bl_script_name
    __bl_script_name="${BASH_SOURCE[1]}"
    __bl_script_name="${__bl_script_name##*/}"

    local __bl_function_name
    __bl_function_name="${FUNCNAME[1]}"

  local __bl_called_line_number
  __bl_called_line_number="${BASH_LINENO[0]}"

    local __bl_log_message
    __bl_log_message="$*"

    local time_and_date
    time_and_date=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${time_and_date} [${__bl_script_name}:${__bl_function_name}:line:${__bl_called_line_number}] ${__bl_log_message_type} - ${__bl_log_message}"
  fi
}


# INFO: designates informational messages that highlight the progress of the application at coarse-grained level.
function __logi() {
  declare -A __bl_allowed_log_levels
	__bl_allowed_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG [INFO]=INFO)
  if [[ "${__bl_allowed_log_levels[${__bl_requested_log_type}]+isset}" ]]; then
		__bl_log_message_type="INFO"

		local __bl_script_name
    __bl_script_name="${BASH_SOURCE[1]}"
    __bl_script_name="${__bl_script_name##*/}"

    local __bl_function_name
    __bl_function_name="${FUNCNAME[1]}"

  local __bl_called_line_number
  __bl_called_line_number="${BASH_LINENO[0]}"

    local __bl_log_message
    __bl_log_message="$*"

    local time_and_date
    time_and_date=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${time_and_date} [${__bl_script_name}:${__bl_function_name}:line:${__bl_called_line_number}] ${__bl_log_message_type} - ${__bl_log_message}"
  fi
}

# WARN: designates potentially harmful situations.
function __logw() {
  declare -A __bl_allowed_log_levels
	__bl_allowed_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG [INFO]=INFO [WARN]=WARN)
  if [[ "${__bl_allowed_log_levels[${__bl_requested_log_type}]+isset}" ]]; then
    __bl_log_message_type="WARN"

    local __bl_script_name
    __bl_script_name="${BASH_SOURCE[1]}"
    __bl_script_name="${__bl_script_name##*/}"

    local __bl_function_name
    __bl_function_name="${FUNCNAME[1]}"

  local __bl_called_line_number
  __bl_called_line_number="${BASH_LINENO[0]}"

    local __bl_log_message
    __bl_log_message="$*"

    local time_and_date
    time_and_date=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${time_and_date} [${__bl_script_name}:${__bl_function_name}:line:${__bl_called_line_number}] ${__bl_log_message_type} - ${__bl_log_message}"
  fi
}


# ERROR: designates error events that might still allow the application to continue running.
function __loge() {
  declare -A __bl_allowed_log_levels
	__bl_allowed_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG [INFO]=INFO [WARN]=WARN [ERROR]=ERROR)
  if [[ "${__bl_allowed_log_levels[${__bl_requested_log_type}]+isset}" ]]; then
    __bl_log_message_type="ERROR"

    local __bl_script_name
    __bl_script_name="${BASH_SOURCE[1]}"
    __bl_script_name="${__bl_script_name##*/}"

    local __bl_function_name
    __bl_function_name="${FUNCNAME[1]}"

  local __bl_called_line_number
  __bl_called_line_number="${BASH_LINENO[0]}"

    local __bl_log_message
    __bl_log_message="$*"

    local time_and_date
    time_and_date=$(date '+%Y-%m-%d %H:%M:%S')
		>&2  echo "${time_and_date} [${__bl_script_name}:${__bl_function_name}:line:${__bl_called_line_number}] ${__bl_log_message_type} - ${__bl_log_message}"
  fi
}


# FATAL: designates very severe error events that will presumably lead the application to abort.
function __logf() {
  declare -A __bl_allowed_log_levels
	__bl_allowed_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG [INFO]=INFO [WARN]=WARN [ERROR]=ERROR [FATAL]=FATAL)
  if [[ "${__bl_allowed_log_levels[${__bl_requested_log_type}]+isset}" ]]; then
    __bl_log_message_type="FATAL"

    local __bl_script_name
    __bl_script_name="${BASH_SOURCE[1]}"
    __bl_script_name="${__bl_script_name##*/}"

    local __bl_function_name
    __bl_function_name="${FUNCNAME[1]}"

  local __bl_called_line_number
  __bl_called_line_number="${BASH_LINENO[0]}"

    local __bl_log_message
    __bl_log_message="$*"

    local time_and_date
    time_and_date=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${time_and_date} [${__bl_script_name}:${__bl_function_name}:line:${__bl_called_line_number}] ${__bl_log_message_type} - ${__bl_log_message}"
  fi
}

# info message to log start of something
function __log_start() {
  declare -A __bl_allowed_log_levels
	__bl_allowed_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG [INFO]=INFO)
  if [[ "${__bl_allowed_log_levels[${__bl_requested_log_type}]+isset}" ]]; then
	__bl_log_message_type="INFO"

	local __bl_script_name
  __bl_script_name="${BASH_SOURCE[1]}"
  __bl_script_name="${__bl_script_name##*/}"

  local __bl_function_name
  __bl_function_name="${FUNCNAME[1]}"

  local __bl_called_line_number
  __bl_called_line_number="${BASH_LINENO[0]}"

  local __bl_log_message
  __bl_log_message="STARTED"

  local time_and_date
  time_and_date=$(date '+%Y-%m-%d %H:%M:%S')
  echo "${time_and_date} [${__bl_script_name}:${__bl_function_name}:line:${__bl_called_line_number}] ${__bl_log_message_type} - ${__bl_log_message}"
  fi
}

# info message to log end of something
function __log_finish() {
  declare -A __bl_allowed_log_levels
	__bl_allowed_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG [INFO]=INFO)
  if [[ "${__bl_allowed_log_levels[${__bl_requested_log_type}]+isset}" ]]; then
	__bl_log_message_type="INFO"

  local __bl_script_name
  __bl_script_name="${BASH_SOURCE[1]}"
  __bl_script_name="${__bl_script_name##*/}"

  local __bl_function_name
  __bl_function_name="${FUNCNAME[1]}"

  local __bl_called_line_number
  __bl_called_line_number="${BASH_LINENO[0]}"

  local __bl_log_message
  __bl_log_message="FINISHED"

  local time_and_date
  time_and_date=$(date '+%Y-%m-%d %H:%M:%S')
  echo "${time_and_date} [${__bl_script_name}:${__bl_function_name}:line:${__bl_called_line_number}] ${__bl_log_message_type} - ${__bl_log_message}"
  #echo ""
  fi
}
