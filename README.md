# dnsmasqAdBlockUDM
Dnsmasq based Ad blocking for Unifi equipment (UDM-SE)

This is the extension script for the provided ad-block feature for the UDM-SE (as of version 3.0.13 or compatible).
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
- upload the getBlacklistHosts.sh into a persistant folder on your UDM
- run the getBlacklistHosts.sh once to obtain a getBlacklistHosts.conf to set your parameters accordingly
- run getBlacklistHosts.sh a second time to initially load all lists initially and activate the new block-list in the unifi scripts
- schedule a regular run in the provided file /etc/cron.d/getBlacklistHosts (enable both lines then)
