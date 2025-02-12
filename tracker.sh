#!/bin/bash -l
set -x
set -e

screenint="${SCREENINT:-4}" #takes ~1 sec to take all screenshots

function screenIsLocked { [ "$(/usr/libexec/PlistBuddy -c "print :IOConsoleUsers:0:CGSSessionScreenIsLocked" /dev/stdin 2>/dev/null <<< "$(ioreg -n Root -d1 -a)")" = "true" ] && return 0 || return 1; }

function set_today() {
    today=$(date +"%m%d%y")
    echo "Set today's date: ${today}"
}

function get_dailydir() {
    dir="${TARGETDIR:-$HOME/prodtracker}"
    dailydir="${dir}/${today}"
    echo "${dailydir}"
}


function check_or_create_dir() {
    dailydir=$(get_dailydir)
    if [ ! -d "${dailydir}" ]; then
        mkdir -p "${dailydir}"
        echo "Directory absent, created: ${dailydir}"
    fi
}


function get_monitor_names() {
  # First, try to get monitor names using system_profiler
  local names=$(system_profiler SPDisplaysDataType -json | 
                jq -r '.SPDisplaysDataType[].spdisplays_ndrvs | .[]._name' 2>/dev/null | 
                tr -d ' \t' | 
                tr '[:upper:]' '[:lower:]')
  
  # If the above fails or returns empty, fall back to a simpler method
  if [ -z "$names" ]; then
    names=$(system_profiler SPDisplaysDataType | 
            awk '/Display Type/ {print $3}' | 
            tr -d ' \t' | 
            tr '[:upper:]' '[:lower:]')
  fi
  
  # If we still don't have any names, use a default
  if [ -z "$names" ]; then
    names="display1"
  fi
  
  echo "$names"
}
function screenshot_loop() {
    #Change to writing jpegs
    defaults write com.apple.screencapture type jpg;killall SystemUIServer
    while true; do
        # If it's a new day, reset some variables and create a new directory for saving screenshots.
        date_now=$(date +"%m%d%y")
        if [ "${date_now}" != "${today}" ]; then
            set_today
            check_or_create_dir
        fi
        dailydir=$(get_dailydir)

        # Allow for pausing capture
        if [ ! -f /tmp/trackerpause ]; then
            ts=$(date +"%H%M%S")
            monitor_ix=1
            while read -r monitor_name; do
              targetdir="${dailydir}/${ts}_${monitor_name}.jpg"
              if screenIsLocked; then
                continue
                #errors if try to take a screencapture while screen locked
              fi
              screencapture -x -D $monitor_ix -t jpg  "${targetdir}"
              #saves 50% space
              mogrify -quality 80% "${targetdir}" &
              ((monitor_ix++))
            done < <(get_monitor_names)
            wait
        fi
        sleep "$screenint"
    done
}

function main() {
    set_today
    check_or_create_dir
    screenshot_loop
}

main
