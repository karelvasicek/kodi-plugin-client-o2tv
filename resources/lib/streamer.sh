#!/bin/sh
# Verze 0.5
# Streamer, který vytváří stream pro Tvheadend předávaný metodou pipe:// na stdout scriptu, resp. volaného ffmpeg.
# Changelog:
# - stream cache ano/ne - viz mplementační parametry cache=1/cachce=
# - mapování streamů v ffmpeg - viz parametr spuštění, řetězec mapování ffmpeg v "...", je třeba editovat ručně v souboru playlist.m3u8
# Závislosti: ffmpeg, wget, jq
# Předpoklady: existuje soubor acces.id s aktuálními parametry přihlášeného a registrovaného zařízení

# Začátek části zadání uživatelských parametrů
# Pozn: Veškeré parametry bez mezer a českých znaků!
# Identifikace poskytovatele služby, které se přenese do Kodi jako "Poskytovatel" - zobrazí se v OSD PVR
provider=o2tv.cz
# Typ zařízení. Je určující pro nabídku streamů služby {STB, PC, TABLET, MOBILE}
device_type=STB
# Rozlišení, závisí na typu zařízení {HD, SD} Např, pro STB je HD 1920x1080, 50 FPS a SD 1024x576, 25 FPS. 
resolution=HD
# Protokol (HLS, DASH)
# Musíte si být jist, zda vaše ffmpeg umí DASH - je třeba, aby bylo přeložené s knihovnou libxml2.
# Není mi známý žádný zásadní důvod, proč používat DASH, proto doporučuji používat HLS.
streaming_protocol=HLS
# Absolutní cesta k adresáři služby ve tvaru /.../
data=
# Absolutní cesta k adresáři s ffmpeg /.../ nebo prázdné (ffmpeg=)
ffmpeg=
# Konec části zadání uživatelských parametrů

# Implementační parametry
debug=
valid=86400
cache=

ADDON_DIR=`dirname "$0"`/
if [ -d "${ADDON_DIR}" -a -f "${ADDON_DIR}/settings.sh" ]; then
    source ${ADDON_DIR}/settings.sh
fi

# Parametry spuštění
channel=$1
service=$2
[ ! ${service} ] && service=n/a
mapping=$3

[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") PARAM ${service} ${channel} ${mapping} >> ${data}streamer.log

if [ ! ${cache} ] ; then
	[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") MODE No cached streams >> ${data}streamer.log
	access_id=$(head -n 1 ${data}access.id)
	device_id=$(echo ${access_id} | cut -d' ' -f2)
	access_token=$(echo ${access_id} | cut -d' ' -f3)
	subscription=$(echo ${access_id} | cut -d' ' -f4)
	json=$(wget -qO - --header "X-NanguTv-Access-Token:${access_token}" --header "X-NanguTv-Device-Id:${device_id}" --no-check-certificate "https://app.o2tv.cz/sws/server/streaming/uris.json?serviceType=LIVE_TV&deviceType=${device_type}&streamingProtocol=${streaming_protocol}&resolution=${resolution}&subscriptionCode=${subscription}&channelKey=${channel}&encryptionType=NONE")
	stream=$(echo ${json} | jq -r '.uris' | jq -r '.[0].uri' | sed "s/_sd_/_hd_/")
else
	[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") MODE Cached streams >> ${data}streamer.log
	cache=.cache
	[ ! -d ${data}${cache} ] && mkdir ${data}${cache}
	if [ -e ${data}${cache}/${service}.strm ] ; then
		[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") CACHE Tested >> ${data}streamer.log
		stream=$(cat ${data}${cache}/${service}.strm)
		create=$(echo ${stream} | sed -re "s;(http|https)\:\/\/stc\.o2tv\.cz\/at\/[0-9a-z]*\/([0-9]{10})[0-9]*\/.*;\2;")
		expire=$((create+valid))
		[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") TIME Create: $(date -d @${create} +"%Y-%m-%d %H:%M:%S") Expire: $(date -d @${expire} +"%Y-%m-%d %H:%M:%S") >> ${data}streamer.log
		now=$(date +%s)
		[ ${expire} -le ${now} ] && stream=
	fi
	if [ ! ${stream} ] ; then
		[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") CACHE Created >> ${data}streamer.log
		access_id=$(head -n 1 ${data}access.id)
		device_id=$(echo ${access_id} | cut -d' ' -f2)
		access_token=$(echo ${access_id} | cut -d' ' -f3)
		subscription=$(echo ${access_id} | cut -d' ' -f4)
		json=$(wget -qO - --header "X-NanguTv-Access-Token:${access_token}" --header "X-NanguTv-Device-Id:${device_id}" --no-check-certificate "https://app.o2tv.cz/sws/server/streaming/uris.json?serviceType=LIVE_TV&deviceType=${device_type}&streamingProtocol=${streaming_protocol}&resolution=${resolution}&subscriptionCode=${subscription}&channelKey=${channel}&encryptionType=NONE")
		[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") JSON ${json} >> ${data}streamer.log
		stream=$(echo ${json} | jq -r '.uris' | jq -r '.[0].uri')
		create=$(echo ${stream} | sed -re "s;(http|https)\:\/\/stc\.o2tv\.cz\/at\/[0-9a-z]*\/([0-9]{10})[0-9]*\/.*;\2;")
		expire=$((create+valid))
		[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") TIME Create: $(date -d @${create} +"%Y-%m-%d %H:%M:%S") Expire: $(date -d @${expire} +"%Y-%m-%d %H:%M:%S") >> ${data}streamer.log
		printf "%s" ${stream} > ${data}${cache}/${service}.strm
	fi
fi
[ ${debug} ] && echo $(date +"%Y-%m-%d %H:%M:%S.%N") STREAM ${stream} >> ${data}streamer.log
${ffmpeg}ffmpeg -fflags +genpts -v fatal -i ${stream} -c copy ${mapping} -f mpegts -mpegts_service_type digital_tv -metadata service_provider=${provider} -metadata service_name=${service} pipe:1 #2> ${data}ffmpeg.err

