#! /bin/sh
# Verze 0.5
# Přihlášení a registrace zařízení služby OTT O2TV
# Závislosti: wget, jq
# Předpoklady: účet O2TV, zaplacená služba OTT O2TV

# Začátek části zadání uživatelských parametrů
# Pozn: Veškeré parametry bez mezer a českých znaků!
# Přihlašovací jméno do služby
username=
# Přihlašovací heslo do služby
password=
# Název zařízení, pod kterým bude ve službě registrováno
device_name=
# Id zařízení, pod kterým bude ve službě registrováno
# Doporučuji unikátní hexadecimalní řetězec - například MAC adresa bez oddělovačů (použijte příkaz "ip link")
# Pokud jste již službu přijímali přes některý script nebo addon autorů ort, JiRo, pavuucek, můžete použít jejich id
device_id=
# Absolutní cesta k adresáři služby ve tvaru /.../
data=
# Konec části zadání uživatelských parametrů

# Implementační parametry
HEADER='--header "X-NanguTv-App-Version:Android#6.4.1" --header "User-Agent:Dalvik/2.1.0" --header "Accept-Encoding:gzip" --header "Connection:Keep-Alive" --header "Content-Type:application/x-www-form-urlencoded;charset=UTF-8"'
language=cs

debug=

ADDON_DIR=`dirname "$0"`/
if [ -d "${ADDON_DIR}" -a -f "${ADDON_DIR}/settings.sh" ]; then
    source ${ADDON_DIR}/settings.sh
fi

post="username=${username}&password=${password}"
json=$(wget -qO - ${HEADER} --header "X-NanguTv-Device-Name:${device_name}" --no-check-certificate --post-data "${post}" "https://ottmediator.o2tv.cz:4443/ottmediator-war/login")
if [ $? != 0 ] ; then printf "ERROR: Bad username and/or password\n" ; exit 1 ; fi

remote_access_token=$(echo ${json} | jq -r '.remote_access_token')
services=$(echo ${json} | jq -r '.services')
service_id=$(echo ${services} | jq -r '.[].service_id')

echo remote_access_token : ${remote_access_token}
echo services : ${services}
echo service_id : ${service_id}

post="service_id=${service_id}&remote_access_token=${remote_access_token}"
wget -qO - ${HEADER} --header "X-NanguTv-Device-Id:${device_id}" --header "X-NanguTv-Device-Name:${device_name}" --no-check-certificate --post-data "${post}" "https://ottmediator.o2tv.cz:4443/ottmediator-war/loginChoiceService"
if [ $? != 0 ] ; then printf "ERROR: Bad authorization\n" ; exit 1 ; fi

post="client_id=tef-web-portal-etnetera&client_secret=2b16ac9984cd60dd0154f779ef200679&platform_id=231a7d6678d00c65f6f3b2aaa699a0d0&language=${language}&grant_type=remote_access_token&remote_access_token=${remote_access_token}&authority=tef-sso&isp_id=1"
json=$(wget -qO - --no-check-certificate --post-data "${post}" "https://oauth.o2tv.cz/oauth/token")
if [ $? != 0 ] ; then printf "ERROR: Bad acces_token request\n" ; exit 1 ; fi

access_token=$(echo ${json} | jq -r '.access_token')
refresh_token=$(echo ${json} | jq -r '.refresh_token')
expires_in=$(echo ${json} | jq -r '.expires_in')

echo access_token : ${access_token}
echo refresh_token : ${refresh_token}
echo expires_in : ${expires_in}

json=$(wget -qO - ${HEADER} --header "X-NanguTv-Access-Token:${access_token}" --header "X-NanguTv-Device-Id:${device_id}" --header "X-NanguTv-Device-Name:${device_name}" --no-check-certificate "https://app.o2tv.cz/sws/subscription/settings/subscription-configuration.json")
if [ $? != 0 ] ; then printf "ERROR: Bad registration\n" ; exit 1 ; fi

subscription=$(echo ${json} | jq '.subscription' | tr -d '"')
locality=$(echo ${json} | jq '.locality')
billingParams=$(echo ${json} | jq '.billingParams')
offer=$(echo ${billingParams} | jq '.offers')
tariff=$(echo ${billingParams} | jq '.tariff')

echo subscription : ${subscription}
echo locality : ${locality}
echo billingParams : ${billingParams}
echo offer : ${offer}
echo tariff : ${tariff}

printf "%s %s %s %s" ${device_name} ${device_id} ${access_token} ${subscription} > ${data}access.id
if [ $? != 0 ] ; then printf "ERROR: Bad write to ${data}access.id\n" ; exit 1 ; fi

printf "Service's Ids saved to %s\n" "${data}access.id"
printf "OK\n"

exit 0
