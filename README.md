# dnsmasqAdBlockUDM
Dnsmasq based Ad blocking for Unifi equipment (UDM-SE & UDM-PRO)

This is the extension script for the provided ad-block feature for the UDM (as of version 3.0.13 or compatible).
Since the provided list is something like "a secret" and does not allow to be enhanced or is any transparent, I started to investigate how it was working.
Finally, I made it to incorporate the former ad-block-solution from my USG.

You can now add 
- the default PI-Hole lists, 
- own user-defined URLs, 
- an own dnsblacklist for own URLs to be blocked,
- a dnswhitelist to keep URLs from being blocked by the above,
- disable the unify default list but use your own only.

Furthermore, the script allows for an email notification to be set up.
To regularly, run updates, a default cron-script is also provided (disabled by default) in /etc/cron.d/

# Setup
- upload the getBlacklistHosts.sh into a persistant folder on your UDM (e.g. /data/dns-filter)
- run the getBlacklistHosts.sh once to obtain a getBlacklistHosts.conf to set your parameters accordingly
- run getBlacklistHosts.sh a second time to initially load all lists initially and activate the new block-list in the unifi scripts
- schedule a regular run in the provided file /etc/cron.d/getBlacklistHosts (enable both lines then)
- optionally install more https://github.com/topics/adblock-list

# Upgrade from versions prior to V1.2
- remove existing cron-job 
- download new verion of the script 
- make script executable 
- execute script from within its folder 
- wait for the UDM to update its lists automatically

```
rm /etc/cron.d/getBlacklistHosts
curl 'https://raw.githubusercontent.com/ymichel/dnsmasqAdBlockUDM/V1.3-UDM/getBlacklistHosts.sh' > /data/dns-filter/getBlacklistHosts.sh
chmod +x /data/dns-filter/getBlacklistHosts.sh
bash /data/dns-filter/getBlacklistHost.sh
```
