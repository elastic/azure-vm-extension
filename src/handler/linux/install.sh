#!/usr/bin/env bash
set -euo pipefail

# install script ran at the installation time, check on distros the extension supports and installs required packages for the elastic agent to run

# log will log any exceptions in the install process
log()
{
  echo \[$(date +%H:%M:%ST%d-%m-%Y)\]  "$1" "$2"
  if [ -d "/var/log/azure/" ]; then
    echo \[$(date +%H:%M:%ST%d-%m-%Y)\]  "$1" "$2" >> /var/log/azure/install-es-agent.log
fi
}


DISTRO_NAME=""
DISTRO_VERSION=""

# get_distro will return distro name and version
get_distro() {
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    DISTRO_NAME=$NAME
    DISTRO_VERSION=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    DISTRO_NAME=$(lsb_release -si)
    DISTRO_VERSION=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    DISTRO_NAME=$DISTRIB_ID
    DISTRO_VERSION=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    DISTRO_NAME=Debian
    DISTRO_VERSION=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
    echo -e "Unsupported OS"
    clean_and_exit 51
#elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    DISTRO_NAME=$(uname -s)
    DISTRO_VERSION=$(uname -r)
fi
}

# install_dependencies will install jq, wget packages if missing
install_dependencies() {
  get_distro
  distro=${DISTRO_NAME,,}
  if [[ "$distro" = "sles" ]] || [[ "$distro" = *"suse"* ]] || [[ "$distro" = *"flatcar"* ]] ; then
    echo -e "Unsupported OS"
    clean_and_exit 51
  fi
  if [[ $distro == "redhat"* && $DISTRO_VERSION == "6"* ]] || [[ $distro == "red hat"* && $DISTRO_VERSION == "6"* ]] ; then
    echo -e "Unsupported OS"
    clean_and_exit 51
  fi
  log "distro: $DISTRO_NAME version: $DISTRO_VERSION" "INFO"
  if dpkg -S /bin/ls >/dev/null 2>&1 || dpkg -S /usr/bin/ls >/dev/null 2>&1; then
    log "[install_dependencies] distro is Debian" "INFO"
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
    log "[install_dependencies] distro is RPM" "INFO"
     if [[ $distro == "red hat"*  && $DISTRO_VERSION == "6"* ]] ||  [[ $distro == "red hat"*  &&  $DISTRO_VERSION == "7.2" ]] ;then
      sed -i -e "s/Defaults    requiretty.*/ #Defaults    requiretty/g" /etc/sudoers
    fi
    #sudo yum update -y --disablerepo='*' --enablerepo='*microsoft*'
    if ! command -v wget &> /dev/null; then
      sudo yum install wget -y
    else
      log "[install_dependencies] wget is already installed" "INFO"
    fi
    if ! command -v jq &> /dev/null; then
      if [[ $distro == *"centos"* ]] && [[ $DISTRO_VERSION == "6"* ]] ; then
        log "CentOS install jq" "INFO"
        sudo wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
        sudo chmod +x ./jq
        sudo cp jq /usr/bin
        log "CentOS install jq finished" "INFO"
      elif [[ $distro == "oracle"* ]] && [[ $DISTRO_VERSION == "6"* ]] ; then
        log "Redhat install jq" "INFO"
        sudo wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
        sudo chmod +x ./jq
        sudo cp jq /usr/bin
        log "Redhat install jq finished" "INFO"
      else
        sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y -q
        sudo yum install jq -y
      fi
    else
      log "[install_dependencies] jq is already installed" "INFO"
    fi
  else
    log "[install_dependencies] distro is OTHER" "INFO"
    pacman -Qq | grep -qw jq || pacman -S jq
  fi
}

Install_Extension() {
  local script_path
  script_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  local recovery_marker="$script_path/.uninstall-recovery-required"

  # Azure passes the previous handler's uninstall exit code during an update.
  # In particular, 1.2 can fail before package removal when fleet.yml is absent.
  # Retry cleanup using this handler, which does not need Fleet credentials or
  # fleet.yml. Enable will then install and enroll the agent normally.
  case "${AZURE_GUEST_AGENT_UNINSTALL_CMD_EXIT_CODE:-NOT_RUN}" in
    ""|0|NOT_RUN) ;;
    *)
      # Keep the requirement across install retries, when Azure may no longer
      # supply the original uninstall exit code.
      touch "$recovery_marker" || return $?
      ;;
  esac

  if [ -f "$recovery_marker" ]; then
    log "INFO" "[Install_Extension] Previous handler uninstall failed; retrying local cleanup"
    if ! bash "$script_path/uninstall.sh" --upgrade-recovery; then
      log "ERROR" "[Install_Extension] Local cleanup failed; stopping update"
      return 1
    fi
    rm "$recovery_marker" || return $?
  fi

  install_dependencies
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  Install_Extension
fi


