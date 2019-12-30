#! /bin/sh
# Verze 0.7
# Changelog:
# - upraveno zpracování offer, pokus o odstranění potíží při generaci plalyistu některých tarifů
# - volitelně je možné vložit logo z O2TV (jpg nebo png, 640x640 pix)
# Vytvoření general playlistu obsahující volání streameru pro všechny kanály zaplacené služby OTT O2TV.
# Závislosti: wget, jq
# Předpoklady: existuje soubor acces.id s aktuálními parametry přihlášeného a registrovaného zařízení

# Veškeré parametry bez mezer a českých znaků
# Protokol (HLS, DASH)
# Musíte si být jist, zda vaše ffmpeg umí DASH - je třeba, aby bylo přeložené s knihovnou libxml2.
# Není mi známý žádná zásadní důvod, proč používat DASH, proto doporučuji používat HLS.
streaming_protocol=HLS
# Typ zařízení {TABLET, PC, STB}
device_type=STB
# Do playlistu je možné volitelně vložit logo z O2TV (vložit logo: insert_logo=1, bez loga: insert_logo=)
insert_logo=1
# Absolutní cesta k adresáři služby ve tvaru /.../
data=
# Konec části zadání uživatelských parametrů

# Implementační parametry
debug=

ADDON_DIR=`dirname "$0"`/
if [ -d "${ADDON_DIR}" -a -f "${ADDON_DIR}/settings.sh" ]; then
    source ${ADDON_DIR}/settings.sh
fi

playlist=${data}playlist.general.m3u8
list=${data}channels.lst
list_by_name=${data}channels_by_name.lst
streamer=${data}streamer.sh

encode1=${data}encode1.sed
encode2=${data}encode2.sed

PREFIX=#EXTM3U
PREFIX1ST='#EXTINF:-1 tvh-epg="0"'
PREFIX2ND=pipe://${streamer}

access_id=$(cat ${data}access.id | head -n 1 )
device_name=$(echo ${access_id} | cut -d' ' -f1)
device_id=$(echo ${access_id} | cut -d' ' -f2)
access_token=$(echo ${access_id} | cut -d' ' -f3)
subscription=$(echo ${access_id} | cut -d' ' -f4)

HEADER='--header "X-NanguTv-App-Version:Android#6.4.1" --header "User-Agent:Dalvik/2.1.0" --header "Accept-Encoding:gzip" --header "Connection:Keep-Alive" --header "Content-Type:application/x-www-form-urlencoded;charset=UTF-8"'

printf "Get subscription...\n"

json=$(wget -qO - ${HEADER} --header "X-NanguTv-Access-Token:${access_token}" --header "X-NanguTv-Device-Id:${device_id}" --no-check-certificate "https://app.o2tv.cz/sws/subscription/settings/subscription-configuration.json")
if [ $? != 0 ] ; then printf "ERROR: Bad offer reading\n" ; exit 1 ; fi

subscription=$(echo ${json} | jq -r '.subscription')
locality=$(echo ${json} | jq -r '.locality')
billingParams=$(echo ${json} | jq '.billingParams')
offers=$(echo ${billingParams} | jq '.offers')
tariff=$(echo ${billingParams} | jq -r '.tariff')

if [ ${debug} ] ; then
	echo subscription : ${subscription}
	echo locality : ${locality}
	echo billingParams : ${billingParams}
	echo offers : ${offers}
	echo tariff : ${tariff}
fi

printf "Get channels list...\n"

i=0
totalpurchased=0
maxoffers=$(echo ${offers} | jq '.|length')
printf "" > ${list}
printf "$PREFIX\n" > ${playlist}
while [ ${i} -lt ${maxoffers} ] ; do
	offer=$(echo ${offers} | jq -r ".[$i]")
	json=$(wget -qO - -T 5 --header "X-NanguTv-Access-Token:${access_token}" --header "X-NanguTv-Device-Id:${device_id}" --no-check-certificate "https://app.o2tv.cz/sws/server/tv/channels.json?locality=${locality}&tariff=${tariff}&isp=1&language=ces&deviceType=${device_type}&liveTVStreamingProtocol=${streaming_protocol}&offer=${offer}")
	if [ $? != 0 ] ; then printf "ERROR: Bad channels list reading\n" ; exit 1 ; fi
	count=$(echo ${json} | jq '.totalCount')
	purchased=$(echo ${json} | jq '.purchasedChannels' | jq '.|length')
	if [ ${count} -gt 0 ] && [ ${purchased} -gt 0 ] ; then
		printf "Offer \"%s\" - Total/Purchased channels:%s/%s\n" ${offer} ${count} ${purchased}
		totalpurchased=$((totalpurchased+purchased))
		channels=$(echo ${json} | jq '.channels')
		keys=$(echo ${json} | jq '.purchasedChannels' | jq 'keys_unsorted' )
		j=0
		while [ $j -lt ${purchased} ] ; do
			key=$(echo ${keys} | jq ".[$j]")
			channel=$(echo ${channels} | jq ".${key}")
			channel_key=$(echo ${channel} | jq -r '.channelKey')
			id=$(echo ${channel_key} | sed -f ${encode1})
			service=$(echo ${channel_key} | sed -f ${encode2} | tr "[:upper:]" "[:lower:]")
			logo=$(echo ${channel} | jq -r '.logo' | sed -re "s;/sizes/[0-9]+x[0-9]+/canvas/[0-9]+x[0-9]+/;/sizes/640x640/canvas/640x640/;")
			name=$(echo ${channel} | jq -r '.channelName')
			printf "$PREFIX1ST" >> ${playlist}
			[ ${insert_logo} ] && printf " tvg-logo=\"%s\"" "${logo}" >> ${playlist}
			printf ",%s\n" "${name}" >> ${playlist}
			printf "$PREFIX2ND %s %s\n" "${id}" "${service}" >> ${playlist}
			j=$((j+1))
			printf "Generated: %s channels.\r" ${j}
			printf "%s\n" "${name}" >> ${list}
		done
		printf "\n"
	fi
	i=$((i+1))
done
if [ ${totalpurchased} = 0 ] ; then printf "ERROR: No channels purchased\n" ; exit 1 ; fi

sort ${list} > ${list_by_name} 
printf "Playlist done\n"
printf "Playlist saved to %s\n" "${playlist}"
printf "List of channels saved to %s\n" "${list}"
printf "List of channels sorted by name saved to %s\n" "${list_by_name}"

exit_code=0
chmod +x ${streamer}
if [ $? != 0 ] ; then printf "WARNING: Bad ${streamer} executable setting\n" ; exit_code=2 ; else printf "File ${streamer} set as executable\n" ; fi

printf "OK\n"

exit ${exit_code}
