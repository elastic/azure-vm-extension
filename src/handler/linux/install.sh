#!/usr/bin/env bash
set -euo pipefail

install_dependencies() {
  if dpkg -S /bin/ls >/dev/null 2>&1; then
    echo "[install_dependencies] distro is Debian" "INFO"
    sudo apt-get update
    if [ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
      #sudo apt-get --yes install  curl;
      (sudo apt-get --yes install  curl || (sleep 15; sudo apt-get --yes install  curl))
    fi
    if [ $(dpkg-query -W -f='${Status}' jq 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
      #sudo apt-get --yes install  jq;
      (sudo apt-get --yes install  jq || (sleep 15; apt-get --yes install  jq))
    fi
  elif rpm -q -f /bin/ls >/dev/null 2>&1; then
    echo "[install_dependencies] distro is RPM" "INFO"
    #sudo yum update -y --disablerepo='*' --enablerepo='*microsoft*'
    if ! rpm -qa | grep -qw jq; then
      #yum install epel-release -y
      yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y
      yum install jq -y
    fi
  else
    echo "[install_dependencies] distro is OTHER" "INFO"
    pacman -Qq | grep -qw jq || pacman -S jq
  fi
}

install_dependencies
