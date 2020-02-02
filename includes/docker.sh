#!/usr/bin/env bash

# Set strict bash mode
set -euo pipefail

function _exec_in_docker {
  local _cmd="$1"
  shift
  local _arguments="$*"

  TOOLBOX_DOCKER_EXECUTABLE=${TOOLBOX_DOCKER_EXECUTABLE:-docker}
  TOOLBOX_DOCKER_RUN=${TOOLBOX_DOCKER_RUN:-run}
  TOOLBOX_DOCKER_IMAGE=${TOOLBOX_TOOL_DOCKER_IMAGE:-aroq/toolbox:latest}
  TOOLBOX_DOCKER_CMD_LAUNCH_CMD=${TOOLBOX_DOCKER_CMD_LAUNCH_CMD:-sh}
  TOOLBOX_DOCKER_CURRENT_DIR=${TOOLBOX_DOCKER_CURRENT_DIR:-$(pwd)}
  TOOLBOX_DOCKER_VOLUME_SOURCE=${TOOLBOX_VOLUME_SOURCE:-$(pwd)}
  TOOLBOX_DOCKER_VOLUME_TARGET=${TOOLBOX_DOCKER_VOLUME_TARGET:-${TOOLBOX_DOCKER_VOLUME_SOURCE}}
  TOOLBOX_DOCKER_SSH_FORWARD=${TOOLBOX_DOCKER_SSH_FORWARD:-false}
  TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE=${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE:-}

  LOCAL_SSH_ID_RSA_KEY_PATH=${LOCAL_SSH_ID_RSA_KEY_PATH:-~/.ssh}
  LOCAL_SSH_ID_RSA_KEY_FILE=${LOCAL_SSH_ID_RSA_KEY_FILE:-id_rsa}

  local DOCKER_SSH_AUTH_SOCK_FORWARD_PARAMS=
  if [ "${TOOLBOX_DOCKER_SSH_FORWARD}" == "true" ]; then
    case "$OSTYPE" in
      darwin*)  DOCKER_SSH_AUTH_SOCK_FORWARD_PARAMS=${DOCKER_SSH_AUTH_SOCK_FORWARD_PARAMS:---volumes-from=ssh-agent -e SSH_AUTH_SOCK=/.ssh-agent/socket} ;;
      *)        DOCKER_SSH_AUTH_SOCK_FORWARD_PARAMS=${DOCKER_SSH_AUTH_SOCK_FORWARD_PARAMS:-} ;;
    esac

  # Run additional docker container to mount SSH keys and provide volumes for othe containers
  docker ps --filter "name=ssh-agent" --format "{{.Names}}" | grep -q ssh-agent || (docker run --rm -d --name=ssh-agent nardeas/ssh-agent && docker run --rm --volumes-from=ssh-agent -v "${LOCAL_SSH_ID_RSA_KEY_PATH}":/.ssh -it nardeas/ssh-agent ssh-add "/root/.ssh/${LOCAL_SSH_ID_RSA_KEY_FILE}")
  fi

  # Only allocate tty if one is detected. See - https://stackoverflow.com/questions/911168
  TOOLBOX_DOCKER_RUN_FLAGS+=(--rm)
  if [[ -t 0 ]]; then TOOLBOX_DOCKER_RUN_FLAGS+=(-i); fi
  if [[ -t 1 ]]; then TOOLBOX_DOCKER_RUN_FLAGS+=(-t); fi

  local toolbox_env_file
  toolbox_env_file="$(mktemp)"
  (env | grep ^TOOLBOX_) >> "${toolbox_env_file}"
  _log DEBUG "${YELLOW}'TOOLBOX_*' variable list - ${toolbox_env_file}:${RESTORE}"
  _log DEBUG "$(cat "${toolbox_env_file}")"
  TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE="${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE} --env-file=${toolbox_env_file}"

  local run_cmd=("${TOOLBOX_DOCKER_RUN}" \
    $(join_to_string "${TOOLBOX_DOCKER_RUN_FLAGS[@]}") \
    ${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE} \
    -w ${TOOLBOX_DOCKER_CURRENT_DIR} \
    -v ${TOOLBOX_DOCKER_VOLUME_SOURCE}:${TOOLBOX_DOCKER_VOLUME_TARGET} \
    ${DOCKER_SSH_AUTH_SOCK_FORWARD_PARAMS} \
    ${TOOLBOX_DOCKER_IMAGE} \
    ${TOOLBOX_DOCKER_CMD_LAUNCH_CMD} \
    -c "${_cmd} ${_arguments}")

  _exec "Run command in Docker" "${TOOLBOX_DOCKER_EXECUTABLE}" "${run_cmd[@]}"
}

function _exec_tool_in_docker {
  local _cmd="$1"

  TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE=${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE:-}
  if [[ -f "${_cmd}.env" ]]; then
    TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE="${TOOLBOX_DOCKER_RUN_TOOL_ENV_FILE} --env-file=${_cmd}.env"
    _log DEBUG "${YELLOW}Variable list from tool - ${_cmd}.env:${RESTORE}"
    _log DEBUG "$(cat "${_cmd}".env)"
  fi

  _exec_in_docker "$@"
}
