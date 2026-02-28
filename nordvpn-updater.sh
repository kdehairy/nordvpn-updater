#!/bin/sh

set -e

info() {
	logger -c -t nordvpn -p5 "$1"
}

error() {
	logger -c -t nordvpn -p2 "$1"
}

warn() {
	logger -c -t nordvpn -p3 "$1"
}

# All clients with description beginning with "nordvpn" will be considered.
nordvpn_clients=$(nvram show 2>/dev/null | grep -E "^vpn_client[[:digit:]]{1}_desc=nord_[[:alpha:]]{2}_.+$")
if [ -z "$nordvpn_clients" ]; then
	info "For clients you want to manage, put 'nord_<country-code>_<vpn-type>' in the description field"
	info "<country-code>: is one of NordVpn's country codes listed in 'https://api.nordvpn.com/v1/servers/countries' or '-'"
	info "<vpn-type>: is either: standard, p2p, or double"
	warn "Found no NordVpn Clients"
	exit 1
fi

countries_response=$(curl -s "https://api.nordvpn.com/v1/servers/countries")

for client in $nordvpn_clients; do
	client_name="vpn_$(echo "$client" | cut -d_ -f2)"
	if [ -z "$client" ]; then
		error "Failed while reading vpn client identifier"
		exit 2
	fi

	state=$(nvram get "${client_name}_state")
	if [ "$state" = 0 ]; then
		continue
	fi

	country_code=$(echo "$client" | cut -d_ -f4)
	if [ -z "$country_code" ]; then
		error "Malformatted description field. Expected country_code not found"
		exit 2
	fi
	if [ "$country_code" != "-" ]; then
		country_id=$(echo "$countries_response" | jq -r ".[] | select(.code | match(\"^${country_code}$\";\"i\")) | [.id] | \"\(.[0])\"")
		if [ -z "$country_code" ]; then
			error "No NordVPN server found in country ${country_code} for client $client_name. Ignoring"
			continue
		fi
	fi
	vpn_type=$(echo "$client" | cut -d_ -f5)
	if [ -z "$vpn_type" ]; then
		error "Failed to read vpn type for client $client"
		exit 2
	fi
	proto=$(nvram get "${client_name}_proto" | cut -d- -f1)

	info "Found '$client_name' connects to server in '$country_code' of type '$vpn_type' using proto '$proto'"

	if [ "$country_code" != "-" ]; then
		json_response=$(curl -s --get 'https://api.nordvpn.com/v1/servers/recommendations' \
			--data-urlencode "filters[servers_technologies][identifier]=openvpn_${proto}" \
			--data-urlencode "filters[servers_groups][identifier]=legacy_${vpn_type}" \
			--data-urlencode "filters[country_id]=${country_id}" \
			--data-urlencode 'limit=1')
	else
		json_response=$(curl -s --get 'https://api.nordvpn.com/v1/servers/recommendations' \
			--data-urlencode "filters[servers_technologies][identifier]=openvpn_${proto}" \
			--data-urlencode "filters[servers_groups][identifier]=legacy_${vpn_type}" \
			--data-urlencode 'limit=1')
	fi

	new_host=$(echo "$json_response" | jq -r '.[0].hostname')
	new_ip=$(echo "$json_response" | jq -r '.[0].ips[0].ip.ip')
	if [ "$new_ip" = "null" ]; then
		warn "Did not find a server with the requested specs in client $client_name"
		continue
	fi
	current_ip=$(nvram get "${client_name}_addr")

	if [ "$new_ip" != "$current_ip" ]; then
		info "Got new server: '${new_host}' with ip: '${new_ip}'"
		nvram set "${client_name}_addr"="$new_ip"
		nvram set "${client_name}_cn"="$new_host"
		service "restart_${client_name}"
	fi
done
