#! /bin/sh
# Přihlášení a registrace zařízení služby OTT O2TV
# Verze 0.9
# Changelog:
# - ze scriptu login.sh byl odstraněn refresh způsob autentizace
# Závislosti: wget, jq
# Předpoklady:
# - účet O2TV
# - zaplacená služba OTT O2TV
# - existuje soubor config.json

# Výchozí adresář
dir=$(dirname $0)
pwd=$(pwd)
cd ${dir}
script=$(pwd)
data="${script}/../../../../userdata/addon_data/plugin.video.client-o2tv/"
cd ${pwd}

# Implementační parametry
debug=

config_file=${data}/config.json
access_file=${data}/access.id

if [ ! -f "${config_file}" ] ; then
	printf "ERROR: Configuration file ${config_file} missing\n"
	exit 1
else
	config_json=$(cat ${config_file})
	provider=$(echo ${config_json} | jq -r '.provider')
	username=$(echo ${config_json} | jq -r '.username')
	password=$(echo ${config_json} | jq -r '.password')
	device_name=$(echo ${config_json} | jq -r '.device_name')
	device_type=$(echo ${config_json} | jq -r '.device_type')
	device_id=$(echo ${config_json} | jq -r '.device_id')
	resolution=$(echo ${config_json} | jq -r '.resolution')
	streaming_protocol=$(echo ${config_json} | jq -r '.streaming_protocol')
	parse_stream=$(echo ${config_json} | jq -r '.parse_stream')
	insert_logo=$(echo ${config_json} | jq -r '.insert_logo')
	ffmpeg=$(echo ${config_json} | jq -r '.ffmpeg')
	if [ ${debug} ] ; then
		echo provider: $provider
		echo username: $username
		echo password: $password
		echo device_name: $device_name
		echo device_type: $device_type
		echo device_id: $device_id
		echo resolution: $resolution
		echo streaming_protocol: $streaming_protocol
		echo parse_stream: $parse_stream
		echo insert_logo: $insert_logo
		echo ffmpeg: $ffmpeg
	fi
fi

HEADER='--header "X-NanguTv-App-Version:Android#6.4.1" --header "User-Agent:Dalvik/2.1.0" --header "Accept-Encoding:gzip" --header "Connection:Keep-Alive" --header "Content-Type:application/x-www-form-urlencoded;charset=UTF-8"'
language=cs

printf "1st authentication method will be used!\n"
post="grant_type=password&client_id=tef-web-portal-etnetera&client_secret=2b16ac9984cd60dd0154f779ef200679&platform_id=231a7d6678d00c65f6f3b2aaa699a0d0&language=${language}&username=${username}&password=${password}"
json=$(wget -qO - --no-check-certificate --post-data "${post}" "https://oauth.o2tv.cz/oauth/token")
if [ $? != 0 ] ; then
	printf "WARNING: 1st authentication method not succeeded, 2nd authentication method will be used!\n"
	
	post="username=${username}&password=${password}"
	json=$(wget -qO - ${HEADER} --header "X-NanguTv-Device-Name:${device_name}" --no-check-certificate --post-data "${post}" "https://ottmediator.o2tv.cz:4443/ottmediator-war/login")
	if [ $? != 0 ] ; then printf "ERROR: Bad username and/or password\n" ; exit 1 ; fi

	remote_access_token=$(echo ${json} | jq -r '.remote_access_token')
	services=$(echo ${json} | jq -r '.services')
	service_id=$(echo ${services} | jq -r '.[].service_id')

	if [ ${debug} ] ; then
		echo remote_access_token : ${remote_access_token}
		echo services : ${services}
		echo service_id : ${service_id}
	fi

	post="service_id=${service_id}&remote_access_token=${remote_access_token}"
	wget -qO - ${HEADER} --header "X-NanguTv-Device-Id:${device_id}" --header "X-NanguTv-Device-Name:${device_name}" --no-check-certificate --post-data "${post}" "https://ottmediator.o2tv.cz:4443/ottmediator-war/loginChoiceService"
	if [ $? != 0 ] ; then printf "ERROR: Bad authorization\n" ; exit 1 ; fi

	post="grant_type=remote_access_token&client_id=tef-web-portal-etnetera&client_secret=2b16ac9984cd60dd0154f779ef200679&platform_id=231a7d6678d00c65f6f3b2aaa699a0d0&language=${language}&remote_access_token=${remote_access_token}&authority=tef-sso&isp_id=1"
	json=$(wget -qO - --post-data "${post}" "https://oauth.o2tv.cz/oauth/token")
	if [ $? != 0 ] ; then printf "ERROR: Bad acces_token request\n" ; exit 1 ; fi
	printf "2nd authentication method succeded!\n"
else
	printf "1st authentication method succeded!\n"
fi

access_token=$(echo ${json} | jq -r '.access_token')
refresh_token=$(echo ${json} | jq -r '.refresh_token')
expires_in=$(echo ${json} | jq -r '.expires_in')

if [ ${debug} ] ; then
	echo access_token : ${access_token}
	echo refresh_token : ${refresh_token}
	echo expires_in : ${expires_in}
fi

json=$(wget -qO - ${HEADER} --header "X-NanguTv-Access-Token:${access_token}" --header "X-NanguTv-Device-Id:${device_id}" --header "X-NanguTv-Device-Name:${device_name}" --no-check-certificate "https://app.o2tv.cz/sws/subscription/settings/subscription-configuration.json")
if [ $? != 0 ] ; then printf "ERROR: Bad registration\n" ; exit 1 ; fi

subscription=$(echo ${json} | jq '.subscription' | tr -d '"')
locality=$(echo ${json} | jq '.locality')
billingParams=$(echo ${json} | jq '.billingParams')
offer=$(echo ${billingParams} | jq '.offers')
tariff=$(echo ${billingParams} | jq '.tariff')

if [ ${debug} ] ; then
	echo subscription : ${subscription}
	echo locality : ${locality}
	echo billingParams : ${billingParams}
	echo offer : ${offer}
	echo tariff : ${tariff}
fi

printf "%s %s %s %s %s %s %s %s %s %s" ${device_id} ${access_token} ${refresh_token} ${subscription} ${provider} ${device_type} ${resolution} ${streaming_protocol} ${parse_stream} ${ffmpeg} > ${access_file}
if [ $? != 0 ] ; then printf "ERROR: Bad write to ${access_file}\n" ; exit 1 ; fi
printf "Service's Ids saved to %s\n" "${access_file}"

printf "OK\n"

exit 0
