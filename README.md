# What it does
The `nordvpn-updater.sh` script:

1. Iterates over vpn clients on the router that has a description matching a specific pattern.
2. Only considers the enables ones out of those.
3. Fetches the recommended server from NordVPN API that matches the specs in the description field read earlier.
4. Updates the vpn client with the fetched recommendation.

The script only considers vpn clients with a specific pattern in the description field. The pattern should be:

`nord_<country_code>_<server_category>`

**nord**: must start with the literal word `nord`.  
**<country_code>**: country of the vpn server. The code should match one of the [codes understood by NordVPN API][1]. Or a '-' to disable filting by country.  
**<server_category>**: is one of `standard`, `p2p`, `double_vpn`, `onion_over_vpn`, or `dedicated_ip`.

for example: `nord_kr_p2p`

The updater DOES NOT persist the new servers on disk (flash). So a restart of the router will return the vpn clients to their original state befor the first run ever of the script. This is intentional to not *unnecessarily* cause early write wear on the flash memory of the router. So, after a restart, the updater will be invoked later when the cron job to update starts.

# Prerequisites:
1. You must create the vpn client manually first using one of NordVPN openvpn configs.
2. You must remove the line `verify-x509-name CN=<some-domain-name>` from your *Custom Configuration* section.

The line directive `verify-x509-name` instructs openvpn to check that the hostname of the server matchs the specified domain name.
So when the script runs and switchs the server, openvpn will fail the connection because the new ip is for a server with a different domain name. Removing this line is necessary for dynamically switching servers.

Removing the directive `verify-x509-name` is safe still. As openvpn still validates that the new server presents a certificate signed by NordVPN CA.

# Install
 1. ssh into your router
 2. `curl -sL https://codeberg.org/kdehairy/nordvpn_updater/raw/branch/main/install.sh | sh`
 
 The installer will set a 2 hours schedule in a cron job to invoke the updater.

[1]:https://api.nordvpn.com/v1/servers/countries
