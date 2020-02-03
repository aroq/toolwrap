#!/usr/bin/env bash

# Set strict bash mode
set -euo pipefail

TOOLBOX_TOOL_DIRS=${TOOLBOX_TOOL_DIRS:-toolbox}

RESTORE=$(echo -en '\033[0m')
RED=$(echo -en '\033[00;31m')
GREEN=$(echo -en '\033[00;32m')
YELLOW=$(echo -en '\033[00;33m')
BLUE=$(echo -en '\033[00;34m')
# MAGENTA=$(echo -en '\033[00;35m')
# PURPLE=$(echo -en '\033[00;35m')
# CYAN=$(echo -en '\033[00;36m')
# LIGHTGRAY=$(echo -en '\033[00;37m')
# LRED=$(echo -en '\033[01;31m')
LGREEN=$(echo -en '\033[01;32m')
LYELLOW=$(echo -en '\033[01;33m')
# LBLUE=$(echo -en '\033[01;34m')
# LMAGENTA=$(echo -en '\033[01;35m')
# LPURPLE=$(echo -en '\033[01;35m')
# LCYAN=$(echo -en '\033[01;36m')
# WHITE=$(echo -en '\033[01;37m')

TOOLBOX_TOOL_DIRS=${TOOLBOX_TOOL_DIRS:-toolbox}
export TOOLBOX_RUN=${TOOLBOX_RUN:-false}
export TOOLBOX_DOCKER_SKIP=${TOOLBOX_DOCKER_SKIP:-false}

function _log {
  action=$1 && shift
  case $action in
      TRACE)  [[ $TOOLBOX_LOG_LEVEL =~ TRACE ]]                 && echo "${LYELLOW}$*${RESTORE}" 1>&2 ;;
      DEBUG)  [[ $TOOLBOX_LOG_LEVEL =~ TRACE|DEBUG ]]           && echo "${LGREEN}$*${RESTORE}" 1>&2 ;;
      INFO)   [[ $TOOLBOX_LOG_LEVEL =~ TRACE|DEBUG|INFO ]]      && echo "${GREEN}$*${RESTORE}" 1>&2  ;;
      WARN)   [[ $TOOLBOX_LOG_LEVEL =~ TRACE|DEBUG|INFO|WARN ]] && echo "${YELLOW}$*${RESTORE}" 1>&2  ;;
      ERROR)  [[ ! $TOOLBOX_LOG_LEVEL =~ NONE ]]                && echo "${RED}$*${RESTORE}" 1>&2 ;;
  esac
  true;
}

function _exec {
  local args
  local title
  local title=${1:-"Execute command"}
  shift

  if [ ! -z ${title+x} ]; then
    _log DEBUG "${BLUE}---> ${title}:${RESTORE}"
  fi

  args=$(join_to_string "$@")
  _log INFO "${GREEN}${args}${RESTORE}"

  exec "$@"
}

function _run {
  local args
  local title
  local title=${1:-"Execute command"}
  shift

  if [ ! -z ${title+x} ]; then
    _log DEBUG "${BLUE}---> ${title}:${RESTORE}"
  fi

  args=$(join_to_string "$@")
  _log INFO "${GREEN}${args}${RESTORE}"

  "$@"
}

function _exec_in_host {
  _exec "Exec command" "$@"
}

function _run_in_host {
  _run "Run command" "$@"
}

function join_to_string { local IFS=" "; echo "$*"; }

function find_tool_path() {
  # Find tool path
  export TOOL_PATH=${TOOL_PATH:-${1}}
  if [ ! -f "${TOOL_PATH}" ]; then
    for i in $(echo "$TOOLBOX_TOOL_DIRS" | sed "s/,/ /g")
    do
      _log DEBUG "Check if tool exists: $i/${1}"
      if [[ -f "${i}/${1}" ]]; then
        echo "${i}/${1}"
        break
      fi
    done
    exit 1
  fi
}

function _exec_tool() {
  # Decide about Docker mode
  if [ "${TOOLBOX_RUN}" == "false" ] && [ "${TOOLBOX_DOCKER_SKIP}" == "false" ]; then
    if [ -f /.dockerenv ]; then
      echo "Inside docker already, setting TOOLBOX_DOCKER_SKIP to true"
      TOOLBOX_DOCKER_SKIP=true
    fi
  fi

  CMD=${1}
  # Remove the first argument
  shift

  TOOL_PATH=${CMD:-}
  echo "TOOL_PATH: ${TOOL_PATH}"
  if [ ! -f "${TOOL_PATH}" ]; then
    # Find tool path
    local IFS=" "
    for i in $(echo "$TOOLBOX_TOOL_DIRS" | sed "s/,/ /g")
    do
      _log DEBUG "Check if tool exists: $i/${CMD}"
      if [[ -f "${i}/${CMD}" ]]; then
        TOOL_PATH="${i}/${CMD}"
        break
      fi
    done
  fi

  if [ -z "${TOOL_PATH}" ]; then
    echo "Tool ${CMD} is not found"
  else
    TOOLBOX_RUN=true
    if [ "${TOOLBOX_DOCKER_SKIP}" == "true" ]; then
      _exec_in_host "${TOOL_PATH}" "$@"
    else
      _exec_tool_in_docker "${TOOL_PATH}" "$@"
    fi
  fi
}



