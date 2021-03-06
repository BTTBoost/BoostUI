#!/bin/bash
#
# https://github.com/BTTBoost


PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

check_OS() {
  if [[ -f /etc/lsb-release ]]; then
    return 0
  elif grep -Eqi "debian|raspbian" /etc/issue; then
    return 0
  elif grep -Eqi "ubuntu" /etc/issue; then
    return 0
  elif grep -Eqi "debian|raspbian" /proc/version; then
    return 0
  elif grep -Eqi "ubuntu" /proc/version; then
    return 0
  else
    return 1
  fi
}

error_detect_depends() {
  local command=$1
  local depend=$(echo "${command}" | awk '{print $4}')
  echo -e "[${green}Info${plain}] Starting to install package ${depend}"
  ${command} >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "[${red}Error${plain}] Failed to install ${red}${depend}${plain}"
    exit 1
  fi
}

download() {
  local filename=${1}
  echo -e "[${green}Info${plain}] ${filename} download configuration now..."
  wget --no-check-certificate -q -t3 -T60 -O ${1} ${2}
  if [ $? -ne 0 ]; then
    echo -e "[${red}Error${plain}] Download ${filename} failed."
    exit 1
  fi
}

install_utserver() {
  clear
  echo 'BoostUI Installer'
  echo
  echo "Would you like to allow WebUI access only for specific IP?"
  echo "   1) No (recommended)"
  echo "   2) Yes"
  read -p "Option [1]: " ip
  until [[ -z "$ip" || "$ip" =~ ^[12]$ ]]; do
    echo -e "[${red}Error${plain}] $ip invalid selection."
    read -p "Option [1]: " ip
  done
  case "$ip" in
  1 | "")
    ip=0.0.0.0
    ;;
  2)
    # If system has a single IPv4, it is selected automatically. Else, ask to user
    if [[ $(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}') -eq 1 ]]; then
      ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
    else
      number_of_ip=$(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}')
      echo
      echo "Which IPv4 address should be used?"
      ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | nl -s ') '
      read -p "IPv4 address [1]: " ip_number
      until [[ -z "$ip_number" || "$ip_number" =~ ^[0-9]+$ && "$ip_number" -le "$number_of_ip" ]]; do
        echo -e "[${red}Error${plain}] $ip_number invalid selection."
        read -p "IPv4 address [1]: " ip_number
      done
      [[ -z "$ip_number" ]] && ip_number="1"
      ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "$ip_number"p)
    fi
    ;;
  esac

  echo
  echo "What port should uTorrent WebUI listen to?"
  read -p "Port [8080]: " port
  until [[ -z "$port" || "$port" =~ ^[0-9]+$ && "$port" -le 65535 ]]; do
    echo -e "[${red}Error${plain}] $port invalid port."
    read -p "Port [8080]: " port
  done
  [[ -z "$port" ]] && port="8080"

  echo
  echo "What would be uTorrent WebUI admin name?"
  read -p "Name [admin]: " wuiuser
  until [[ -z "$wuiuser" || "$wuiuser" =~ ^[a-z]+$ ]]; do
    echo -e "[${red}Error${plain}] $wuiuser invalid characters."
    read -p "Name [admin]: " wuiuser
  done
  [[ -z "$wuiuser" ]] && wuiuser="admin"

  echo
  echo "Which WebUI should uTorrent use?"
  echo "   1) Builtin WebUI (recommended)"
  echo "   2) NG WebUI"
  echo "   3) UT WebUI"
  read -p "WebUI [1]: " webui
  until [[ -z "$webui" || "$webui" =~ ^[1-3]$ ]]; do
    echo -e "[${red}Error${plain}] $webui invalid selection."
    read -p "WebUI [1]: " webui
  done
  case "$webui" in
  1 | "")
    webui=1
    ;;
  2)
    webui=2
    ;;
  3)
    webui=3
    ;;
  esac

  echo
  echo "Enter the existing SSH|FTP username who will manage uTorrent download"
  read -p "user: " user
  until [[ $(grep -c "^$user" /etc/passwd) == 1 ]]; do
    echo -e "[${red}Error${plain}] $user does not exist."
    read -p "user: " user
  done

  echo
  echo -e "[${green}Info${plain}] Create system user for uTorrent server"
  addgroup --system utorrent
  adduser --system utorrent
  adduser utorrent utorrent

  echo -e "[${green}Info${plain}] Make directories"
  dl=/home/utorrent/dl
  torrent=/home/utorrent/torrent
  mkdir $dl
  mkdir $torrent

  echo -e "[${green}Info${plain}] Users & Group permission"
  groupadd torrent-manager
  usermod -a -G torrent-manager $user

  chown -R utorrent $torrent
  chgrp -R torrent-manager $torrent
  chmod -R 770 $torrent
  chmod g+s $torrent

  groupadd dl-manager
  usermod -a -G dl-manager $user

  chown -R utorrent $dl
  chgrp -R dl-manager $dl
  chmod -R 770 $dl
  chmod g+s $dl

  error_detect_depends "apt-get update -y"
  error_detect_depends "apt-get install -y curl"
  error_detect_depends "apt-get install -y openssl"
  error_detect_depends "apt-get autoremove -y"
  error_detect_depends "apt-get clean -y"

  echo -e "[${green}Info${plain}] Make uTorrent path"
  sudo mkdir /opt/utorrent

  echo -e "[${green}Info${plain}] Download and unpack uTorrent"
  curl -SL http://download-hr.utorrent.com/track/beta/endpoint/utserver/os/linux-x64-ubuntu-13-04 | sudo tar xz --strip-components 1 -C /opt/utorrent
  ln -s /opt/utorrent/utserver /usr/bin/utserver

  if [[ $webui == 2 ]]; then
    mv /opt/utorrent/webui.zip /opt/utorrent/webui.zip.builtin
    download /opt/utorrent/webui.zip https://github.com/psychowood/ng-torrent-ui/releases/latest/download/webui.zip
  fi

  if [[ $webui == 3 ]]; then
    mv /opt/utorrent/webui.zip /opt/utorrent/webui.zip.builtin
    download /opt/utorrent/webui.zip https://sites.google.com/site/ultimasites/files/utorrent-webui.2013052820184444.zip?attredirects=0
  fi

  echo -e "[${green}Info${plain}] Create utserver.conf"
  echo "bind_ip: $ip
ut_webui_port: $port
dir_active: $dl
dir_torrent_files: $torrent
dir_temp_files: /tmp
dir_request: /opt/utorrent
admin_name: $wuiuser
ut_webui_dir: /opt/utorrent
# bind_port: 6881
seed_ratio: 100" >/opt/utorrent/utserver.conf

  echo -e "[${green}Info${plain}] Change uTorrent root directory ownership"
  chown -R utorrent:utorrent /opt/utorrent/

  echo -e "[${green}Info${plain}] Create a systemd service"
  echo "[Unit]
Description=uTorrent Server
After=network.target

[Service]
Type=simple
User=utorrent
Group=utorrent
ExecStart=/usr/bin/utserver -settingspath /opt/utorrent -configfile /opt/utorrent/utserver.conf &
ExecStop=/usr/bin/pkill utserver
Restart=always
SyslogIdentifier=uTorrent Server

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/utserver.service

  echo -e "[${green}Info${plain}] Reload systemd and start utserver"
  systemctl daemon-reload
  pkill utserver
  systemctl start utserver
  systemctl enable utserver
}
uninstall_utserver() {
  echo
  read -p "Confirm uTorrent removal? [y/N]: " remove
  until [[ "$remove" =~ ^[yYnN]*$ ]]; do
    echo -e "[${red}Error${plain}] $remove invalid selection."
    read -p "Confirm uTorrent removal? [y/N]: " remove
  done
  if [[ "$remove" =~ ^[yY]$ ]]; then
    sudo pkill utserver
    sudo rm -rf /usr/bin/utserver
    sudo rm -rf /opt/utorrent

    # Double check
    # Delete if utorrent directory exist
    if [[ -d /opt/utorrent ]]; then
      sudo pkill utserver
      sudo rm -rf /usr/bin/utserver
      sudo rm -rf /opt/utorrent
    fi
    # Delete utserver.service if exist
    if [[ -f /etc/systemd/system/utserver.service ]]; then
      systemctl stop utserver
      systemctl disable utserver
      rm /etc/systemd/system/utserver.service
      systemctl daemon-reload
    fi
    # Delete user if exist
    if [[ $(grep -c '^utorrent' /etc/passwd) == 1 ]]; then
      userdel -r utorrent
    fi
    # Delete user group if exist
    if [[ $(grep -c '^utorrent' /etc/group) == 1 ]]; then
      groupdel utorrent
    fi
    # Delete user group if exist
    if [[ $(grep -c '^torrent-manager' /etc/group) == 1 ]]; then
      groupdel torrent-manager
    fi
    # Delete user group if exist
    if [[ $(grep -c '^dl-manager' /etc/group) == 1 ]]; then
      groupdel dl-manager
    fi
    exit
  else
    echo
    echo -e "[${red}Error${plain}] uTorrent removal aborted!"
  fi
}

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] Please run as root user to execute the script!" && exit 1

check_OS || {
  echo -e "[${red}Error${plain}] This script can be run only on Ubuntu|Debian OS"
  exit 1
}

if [[ ! -e /usr/bin/utserver ]]; then
  install_utserver
else
  clear
  echo "uTorrent is already installed."
  echo
  echo "Select an option:"
  echo "   1) Remove uTorrent"
  echo "   2) Grant download folder access to webserver"
  echo "   3) Exit"
  read -p "Option: " option
  until [[ "$option" =~ ^[1-3]$ ]]; do
    echo "$option: invalid selection."
    read -p "Option: " option
  done
  case "$option" in

  1)
    uninstall_utserver
    ;;

  2)
    usermod -a -G dl-manager www-data
    exit
    ;;

  3)
    exit
    ;;
  esac
fi
