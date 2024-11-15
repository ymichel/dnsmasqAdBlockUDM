# dnsmasqAdBlockUDM
dnsmasq based Ad blocking for Unifi equipment (UDM-SE & UDM-PRO)

This is the extension script for the provided ad-block feature for the UDM (as of version 3.0.13 or above).
Since the provided list is something like "a secret" and does not allow to be enhanced or is any transparent, I started to investigate how it was working.
Finally, I made it to incorporate the former ad-block-solution from my USG. 
Sometimes, the provided lists do contain invalid DNS entries. Hence, I added a validation routine according to RFC 1123.

You can now add 
- the default PI-Hole lists, 
- your own user-defined URLs, 
- an own dnsblacklist-file for own URLs to be blocked,
- a dnswhitelist to keep URLs from being blocked by the above,
- disable the unify default list but use your own only (by setting an appropriate parameter).

Furthermore, the script allows for an email notification to be set up.
A default cron-script is also provided (disabled by default) in /etc/cron.d/ to automatically reapply this script's functionality after reboot or update.
If you have setup the email notification, the script will also check if there is a newer version available on github and comment that wihin the email. 

# Setup
- upload the getBlacklistHosts.sh into a persistant folder on your UDM (e.g. /data/dns-filter)
- make the script executable 
- run the getBlacklistHosts.sh once to obtain a getBlacklistHosts.conf to set your parameters accordingly
- run getBlacklistHosts.sh a second time to initially load all lists initially and activate the new block-list in the unifi scripts
- optionally install more https://github.com/topics/adblock-list
- wait for the UDM to trigger the ads update as usually (or process it manually by disabling-/reenabling the feature in the sonsole)

# Upgrade from prior versions
- remove existing cron-job 
- download new version of the script 
- make script executable 
- execute script from within its folder 
- wait for the UDM to update its lists automatically

```
rm /etc/cron.d/getBlacklistHosts
curl 'https://raw.githubusercontent.com/ymichel/dnsmasqAdBlockUDM/V1.7.0/getBlacklistHosts.sh' > /data/dns-filter/getBlacklistHosts.sh
chmod +x /data/dns-filter/getBlacklistHosts.sh
bash /data/dns-filter/getBlacklistHosts.sh
```
