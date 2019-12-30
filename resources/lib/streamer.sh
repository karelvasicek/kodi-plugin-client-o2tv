#! /bin/sh
# Vytváří stream pro Tvheadend předávaný metodou pipe:// na stdout scriptu, resp. volaného ffmpeg
# Verze 0.8
# Changelog:
# - typ výpisu ffmpeg je možné zadat v sekci implementační parametry (např. level="-v fatal" vs level=)
# - byla zdrušena možnost používat cache streamů
# Závislosti: ffmpeg, wget, jq
# Předpoklady:
# - existuje soubor acces.id s aktuálními parametry přihlášeného a registrovaného zařízení

# Výchozí adresář
dir=$(dirname $0)
pwd=$(pwd)
cd ${dir}
script=$(pwd)
data="${script}/../../../../userdata/addon_data/plugin.video.client-o2tv/"
cd ${pwd}

# Parametry spuštění
channel=$1
service=$2
[ ! ${service} ] && service=n/a
mapping=$3

# Implementační parametry
debug=1
level="-v fatal"

config_file=${data}/config.json
access_file=${data}/access.id

log_file=${data}/streamer.log
err_file=${data}/ffmpeg.err

[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") PARAM ${dir} ${channel} ${service} ${mapping} >> ${log_file}

access_id=$(head -n 1 ${access_file})
device_id=$(echo ${access_id} | cut -d' ' -f1)
access_token=$(echo ${access_id} | cut -d' ' -f2)
subscription=$(echo ${access_id} | cut -d' ' -f4)
provider=$(echo ${access_id} | cut -d' ' -f5)
device_type=$(echo ${access_id} | cut -d' ' -f6)
resolution=$(echo ${access_id} | cut -d' ' -f7)
streaming_protocol=$(echo ${access_id} | cut -d' ' -f8)
parse_stream=$(echo ${access_id} | cut -d' ' -f9)
ffmpeg=$(echo ${access_id} | cut -d' ' -f10)
[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") ACCESS.ID ${access_id} >> ${log_file}

json=$(wget -qO - --header "X-NanguTv-Access-Token:${access_token}" --header "X-NanguTv-Device-Id:${device_id}" --no-check-certificate "https://app.o2tv.cz/sws/server/streaming/uris.json?serviceType=LIVE_TV&deviceType=${device_type}&streamingProtocol=${streaming_protocol}&resolution=${resolution}&subscriptionCode=${subscription}&channelKey=${channel}&encryptionType=NONE")
[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") JSON ${json} >> ${log_file}
stream=$(echo ${json} | jq -r '.uris' | jq -r '.[0].uri')

# [ ${resolution} = "HD" ] && stream=$(echo ${stream} | sed -e "s/_sd_/_hd_/")
# [ ${resolution} = "SD" ] && stream=$(echo ${stream} | sed -e "s/_hd_/_sd_/")
[ ${parse_stream} ] && [ ${parse_stream} != 0 ] && stream=$(wget -qO - "${stream}" | tail -n${parse_stream} | head -n 1)
[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") STREAM ${stream} >> ${log_file}

${ffmpeg}ffmpeg -fflags +genpts ${level} -i ${stream} -c copy ${mapping} -f mpegts -mpegts_service_type digital_tv -metadata service_provider=${provider} -metadata service_name=${service} pipe:1 #2> ${err_file}

