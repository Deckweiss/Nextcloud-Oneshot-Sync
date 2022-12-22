#!/usr/bin/env bash
set -e

#___Config_____________________________________________________________________________________________#

nextcloudConfigPath="$HOME/.config/Nextcloud/nextcloud.cfg"
kdewalletName="kdewallet"
logPath="$HOME/nextcloudOneshotSync.log"



#___Helpers____________________________________________________________________________________________#

__VERBOSE=5
declare -A LOG_LEVELS

# https://en.wikipedia.org/wiki/Syslog#Severity_level
LOG_LEVELS=([0]="emerg" [1]="alert" [2]="crit" [3]="err" [4]="warning" [5]="notice" [6]="info" [7]="debug")
function .log () {
  local LEVEL=${1}
  local MESSAGE=${2}
  shift 2
  local isMultiline

  if (( $(grep -c . <<<"$@") > 1 )); then
    isMultiline=true
  else
    isMultiline=false
  fi

  if [ ${__VERBOSE} -ge "${LEVEL}" ]; then
    if [ "$lastLevel" != "$LEVEL" ]; then echo "" |& tee -a "$logPath" ; fi
    local timeStamp
    timeStamp=$(date +"%d.%m.%Y %H:%M:%S")

    if [ "$isMultiline" = true ]; then
      echo "$timeStamp" "[${LOG_LEVELS[$LEVEL]}]" "$MESSAGE" |& tee -a "$logPath"
      echo "┌─────┄" |& tee -a "$logPath"
      while IFS= read -r line; do
          echo "│ " "$line" |& tee -a "$logPath"
      done <<< "$@"
      echo "└─────┄" |& tee -a "$logPath"
    else
      echo "$timeStamp" "[${LOG_LEVELS[$LEVEL]}]" "$MESSAGE" "$@" |& tee -a "$logPath"
    fi
  fi

  lastLevel=$LEVEL
}



#___Actual_code________________________________________________________________________________________#

function main() {
  local nextcloudConfigAllAccounts
  local nextcloudAccountIndexList
  local nextcloudConfigOneAccount

  nextcloudConfigAllAccounts=$(sed -e '/./{H;$!d;};x;s/^\n//;/^\[Accounts\]/!d;' "$nextcloudConfigPath" | sed 's/^\[Accounts\]//;s/^version=2//;/^$/D')

  nextcloudAccountIndexList=$(echo "$nextcloudConfigAllAccounts" | cut -c 1-1 | sort | uniq)

  .log 6 "List of nextcloud accounts indices:" "$nextcloudAccountIndexList"

  while IFS= read -r nextcloudAccountIndex; do
      .log 5 "Working on account:" "$nextcloudAccountIndex"
      nextcloudConfigOneAccount=$(echo "$nextcloudConfigAllAccounts" | sed -n -e '/^'"$nextcloudAccountIndex"'\\/p')
      .log 7 "Nextcloud config for acc $nextcloudAccountIndex:" "$nextcloudConfigOneAccount"
      mainPerAccount "$nextcloudAccountIndex" "$nextcloudConfigOneAccount"
  done <<< "$nextcloudAccountIndexList"
}

function createNetrcTemplate() {
  local user
  local config
  user="$1"
  config="$2"

  echo "default" >> "$config"
  echo "login $user" >> "$config"
  echo "password PUT_YOUR_PASSWORD_HERE" >> "$config"
}

function mainPerAccount() {
  local nextcloudAccountIndex
  local nextcloudConfigOneAccount
  local nextcloudFolderIndexList
  local nextcloudConfigOneFolder
  local nextcloudURL
  local nextcloudUser
  local nextcloudPassword

  nextcloudAccountIndex="$1"
  nextcloudConfigOneAccount="$2"
  nextcloudURL=$(echo "$nextcloudConfigOneAccount" | sed -n 's/.*url=\(.*\)/\1/p')
  nextcloudUser=$(echo "$nextcloudConfigOneAccount" | sed -n 's/.*dav_user=\(.*\)/\1/p')

  nextcloudPassword=$(kwallet-query -f Nextcloud -r "$nextcloudUser:$nextcloudURL/:$nextcloudAccountIndex" "$kdewalletName")

  echo "$nextcloudPassword"

  if [ -z "$nextcloudPassword" ]; then
    .log 3 "Skipping user $nextcloudUser:" "Can not read nextcloud password from KDEwallet for entry $nextcloudUser:$nextcloudURL/:$nextcloudAccountIndex in folder Nextcloud in wallet $kdewalletName"
    exit 0
  fi

  .log 6 "nextcloud URL: " "$nextcloudURL"
  .log 6 "nextcloud User: " "$nextcloudUser"

  nextcloudFolderIndexList=$(echo "$nextcloudConfigOneAccount" | sed -n 's/.*Folders\\\([0-9]*\).*/\1/p' | cut -c 1-1 | sort | uniq)
  .log 6 "List of nextcloud folder indices:" "$nextcloudFolderIndexList"

  while IFS= read -r nextcloudFolderIndex; do
     .log 5 "Working on folder:" "$nextcloudFolderIndex"
     nextcloudConfigOneFolder=$(echo "$nextcloudConfigAllAccounts" | sed -n -e '/^.*Folders\\'"$nextcloudFolderIndex"'\\/p')
     .log 7 "Nextcloud config for folder $nextcloudFolderIndex:" "$nextcloudConfigOneFolder"
     mainPerFolder "$nextcloudURL" "$nextcloudUser" "$nextcloudPassword" "$nextcloudConfigOneFolder"
  done <<< "$nextcloudFolderIndexList"
}

function mainPerFolder() {
  local nextcloudURL
  local nextcloudUser
  local nextcloudPassword
  local folderConfig
  nextcloudURL="$1"
  nextcloudUser="$2"
  nextcloudPassword="$3"
  folderConfig="$4"

  local ignoreHiddenFiles
  local localPath
  local targetPath
  ignoreHiddenFiles=$(echo "$folderConfig" | sed -n 's/.*ignoreHiddenFiles=\(.*\)/\1/p')
  localPath=$(echo "$folderConfig" | sed -n 's/.*localPath=\(.*\)/\1/p')
  targetPath=$(echo "$folderConfig" | sed -n 's/.*targetPath=\(.*\)/\1/p')

logMessage=$(cat <<EOF
  local path: "$localPath"
  target path: "$targetPath"
  ignore hidden files: "$ignoreHiddenFiles"
EOF
  )

  .log 5 "Starting nextcloud sync with parameters:" "$logMessage"

  nextcloudcmd --trust --silent --non-interactive --user "$nextcloudUser" --password "$nextcloudPassword" --path "$targetPath" "$localPath" "$nextcloudURL"
}

main
