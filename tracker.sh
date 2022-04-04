#! /bin/bash
set -e

screenint="${SCREENINT:-30}"

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
  system_profiler SPDisplaysDataType -json |
  jq -r '.SPDisplaysDataType[1].spdisplays_ndrvs | .[] | ._name' | 
  tr -d ' \t' |
  tr '[A-Z]' '[a-z]'
}

function get_num_monitors() {
  system_profiler SPDisplaysDataType | grep -c 'Resolution:'
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
            monitor_names=($(get_monitor_names))
            for monitor_ix in $(seq $(get_num_monitors)); do
              monitor=${monitor_names[((monitor_ix-1))]} 
              targetdir="${dailydir}/${ts}_${monitor}.jpg"
              screencapture -x -D $monitor_ix -t jpg  "${targetdir}"
              #saves 50% space
              mogrify -quality 80% "${targetdir}" &
            done
            wait
        fi
        sleep $screenint
    done
}

function main() {
    set_today
    check_or_create_dir
    screenshot_loop
}

main
