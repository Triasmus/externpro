#!/usr/bin/env bash
cd "$( dirname "$0" )"
pushd .. > /dev/null
rel=$(grep FROM .devcontainer/centos7-pro.dockerfile | cut -d- -f2)
rel=${rel//:}
rel=bp${rel/./-}
display_host=$(echo ${DISPLAY} | cut -d: -f1)
if [[ -z "${display_host}" ]]; then
  display_env=${DISPLAY}
  xauth_env=
elif [[ "${display_host}" == "localhost" ]]; then
  echo "NOTE: X11UseLocahost should be no in /etc/ssh/sshd_config"
else
  display_screen=$(echo $DISPLAY | cut -d: -f2)
  display_num=$(echo ${display_screen} | cut -d. -f1)
  magic_cookie=$(xauth list ${DISPLAY} | awk '{print $3}')
  xauth_file=/tmp/.X11-unix/docker.xauth
  docker_host=$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')
  touch ${xauth_file}
  xauth -f ${xauth_file} add ${docker_host}:${display_num} . ${magic_cookie}
  display_env=${docker_host}:${display_screen}
  xauth_env=${xauth_file}
fi
env="COMPOSE_PROJECT_NAME=${PWD##*/}"
env="${env}\nHNAME=${rel}"
env="${env}\nUSERID=$(id -u ${USER})"
env="${env}\nGROUPID=$(id -g ${USER})"
env="${env}\nDISPLAY_ENV=${display_env}"
env="${env}\nXAUTH_ENV=${xauth_env}"
echo -e "${env}" > .env
popd > /dev/null
