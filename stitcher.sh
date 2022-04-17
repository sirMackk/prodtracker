#! /bin/bash
set -x
set -e

dir="${TARGETDIR:-$HOME/prodtracker}"

# Settled on these after manual experimentation. Optimizing for size.
framerate=2
crf=19

function set_todays() {
    todays=$(date +"%m%d%y")
}

#List all monitor names that were used in dir
function get_monitor_names() { 
  find "$1" -type f -name '*.jpg'  |
  tr '_\.' ' ' |
  cut -d' ' -f2 | 
  sort | 
  uniq |
  awk 'NF' #remove empty lines
}

function stitch() {
    targetdir="$1"
    monitor_name="$2"
    output_file="${targetdir}/summary_${monitor_name}.mp4"

    #write images to have the filename timestamp HMS embedded as H:M:S
    echo "Adding timestamps to images for $monitor_name in $targetdir"
    ls "${targetdir}/"*_"${monitor_name}".jpg  |
      awk -F'[/_]' '{print $0,substr($2,1,2)":"substr($2,3,2)":"substr($2,5,2)}'   |
      xargs -L1 -P8 bash -c '
        file="$0"
        time=$1
        out_file="${file/.jpg/_mod.jpg}"
        text_file=$(uuidgen)
        echo $time > $text_file
        ffmpeg -i $file -vf "drawtext=:fontsize=24:textfile=$text_file:fontcolor=white@0.8:x=7:y=7" $out_file 2>/dev/null
        rm $text_file
      '

    #generate video from the new images 
    echo "Generating video(s) for $monitor_name in $targetdir: $output_file"
    ffmpeg -r ${framerate} \
      -f image2 \
      -pattern_type glob \
      -i "${targetdir}/*_${monitor_name}_mod.jpg" \
      -vcodec libx264 \
      -crf ${crf} \
      "${output_file}"

    #remove new images
    rm "${targetdir}/"*_mod.jpg
}


function clean() {
    targetdir=$1
    if [ "$(find "${targetdir}" -name '*.jpeg' -o -name '*.jpg' | wc -l)" -gt 0 ]; then
        echo "Deleting *.jpeg/jpg files in ${targetdir}"
        rm "${targetdir}"/*.jpg || :
        rm "${targetdir}"/*.jpeg || :
    fi
}

function main() {
    set_todays
    while true; do
        date_now=$(date +"%m%d%y")
        if [ "${date_now}" != "${todays}" ]; then
            set_todays
        fi
        
        while read -r d; do 
            # Do not stitch or clean today's directory, only those from the past.
            if [ "${d: -6}" == "${todays}" ] ; then
                continue
            fi
            #function is only evaluated at the start
            while read -r monitor_name; do 
              # Use summary.mp4 as a marker whether a directory has been processed or not.
              output_file="${d}/summary_${monitor_name}.mp4"
              if [ ! -f "${output_file}" ]; then
                  echo "starting $output_file"
                  stitch "${d}" "$monitor_name" 
              fi
            done < <(get_monitor_names "$d")
            clean "${d}"
        done < <(find "$dir" -maxdepth 1 -mindepth 1 -type d)
        # Re-run this loop every hour, so if you suspend your computer over night,
        # this will create a new video summary and clean up older files.
        sleep 3600
    done
}

main
