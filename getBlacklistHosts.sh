#!/bin/bash
#   This script gets various anti-ad hosts files, merges, sorts, and uniques, then installs.
#   Run from cron regularly with provided template.
#
#   This script is modified version of / based on buildhosts by:
#   Matthew Headlee <mmh@matthewheadlee.com> (http://matthewheadlee.com/).
#
#   This file is getBlacklistHosts
#
#   getBlacklistHosts is free software: you can redistribute
#   it and/or modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 3 of the License,
#   or (at your option) any later version.
#
#   getBlacklistHosts is distributed in the hope that it will
#   be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
#   Public License for more details.
#
#   You should have received a copy of the GNU General Public License along with
#   buildhosts.  If not, see
#   <http://www.gnu.org/licenses/>.

## the user configurable options are now located in getBlacklistHosts.conf
## which is created in the same directory this script is in, on first run of this script.
## If it does not exist, run this script to create it, then edit it (if desired).

#Version of this script
version="V1.0 UDM"

#name to use for the options file that will be generated in dnsmasqHome if options found in conf file
#variable dnsmasqOptions
optionsFileName="getBlacklistOptions.conf"

#place where the blacklist is processed from (default is /usr/share/ubios-udapi-server/ips/bin/getsig.sh)
dnsfilterfile="/usr/share/ubios-udapi-server/ips/bin/getsig.sh"

#get the scripts current home
SOURCE="${BASH_SOURCE}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
scriptHome="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

#filename of file which holds the various conf elements, this needs to exist in the same directory this script is running in
dataFile="${scriptHome}/getBlacklistHosts.conf"
cronFile="/etc/cron.d/getBlacklistHosts.sh"

#temp file to hold mail message (deleted by script after use)
messageFile="$(mktemp "/tmp/tmp.BlacklistMessage.txt.XXXXXX")"

#temp file to hold mail header (deleted by script after use)
messageHeader="$(mktemp "/tmp/tmp.BlacklistHeader.txt.XXXXXX")"

#temp file to hold mail footer (deleted by script after use)
messageFooter="$(mktemp "/tmp/tmp.BlacklistFooter.txt.XXXXXX")"

#location of log file. This file gets reset with each run of this script
readonly logFile="/var/log/getBlacklistHosts.log"

echo $(date) > ${logFile}
startTime=`date +%s`

declare -i iBlackListCount=0

function cleanup() {
    #Removes temporary files created during this scripts execution.
    echo ".    Purging temporary files..." | sendmsg
    rm -f "${sTmpNewHosts}" "${sTmpAdHosts}" "${sTmpShallaMD5}" "${sTmpDomainss}" "${sTmpSubFilters}" "${sTmpCleaneds}" "${sTmpWhiteDomains}" "${sTmpDomains2s}" "${sTmpWhiteHosts}" "${sTmpWhiteNoneWild}" "${sTmpWhiteNonSub}" "${sTmpCurlDown}"
}

function cleanupOthers() {
    #Removes other temporary files created during this scripts execution.
    rm -f "${messageFile}" "${messageHeader}" "${messageFooter}"
	rm -rf ${sTmpExtracts}
	rm -rf ${sTmpHostSplitterD}
	rm -rf ${sTmpCurlUnzip}
}

function control_c() {
    echo -e "Script canceled."
    cleanup
	cleanupOthers
    exit 4
}

#create default crontab file if it does not exist
function check_crontab() {
    if [ ! -f ${cronFile} ]; then
        echo -e "#This is the crontab file for ${scriptHome}/getBlacklistHosts.sh ${version}\n\ #MAILTO=""\n\ #29 1 * * * root ${scriptHome}/getBlacklistHosts.sh\n\ #@reboot    root sleep 60 && ${scriptHome}/getBlacklistHosts.sh\n"> /etc/cron.d/getBlacklistHosts.sh
        echo " " | sendmsg
        echo ".    Created default crontab file ${cronFile} which did not exist." | sendmsg
        echo ".    Remember to uncomment the lines and adjust the timing to your needs." | sendmsg
        echo ".    It is not automatically activated but needs your action." | sendmsg
        echo " " | sendmsg
    fi
}

#create default conf file if it does not exist
function check_config_file() {
    if [ ! -f ${dataFile} ]; then
        echo -e "#This is the user configuration file for ${scriptHome}/getBlacklistHosts.sh ${version}\n\
\n\
\n\
#location of the whitelist. This file contains one host/domain per line that will\n\
#be excluded from the blacklist. If the file does not exist it wll not be used.\n\\n\
readonly whitelist=\"${scriptHome}/dnswhitelist\"\n\\n\
#Examples below show the whitelist results on these blacklist entries:\n\
#somedomain.com\n\
#api.somedomain.com\n\
#cdn.somedomain.com\n\
#events.somedomain.com\n\\n\
#no dnswhitelist entry:\n\
#entire somedomain.com is blocked due to 'somedomain.com' being included in the blacklist data\n\\n\
#dnswhitelist entry: *somedomain.com (note no dot between * and domain name)\n\
#resulting blacklist entries:\n\
#none - entire domain whitelisted\n\\n\
#dnswhitelist entry: somedomain.com\n\
#resulting blacklist entries:\n\
#api.somedomain.com\n\
#cdn.somedomain.com\n\
#events.somedomain.com\n\\n\
#dnswhitelist entry: api.somedomain.com - this one subdomain will be whitelisted\n\
#resulting blacklist entries:\n\
#somedomain.com\n\
#cdn.somedomain.com\n\
#events.somedomain.com\n\\n\\n\\n\\n\
#location of the user-defined blacklist. This file contains one host/domain per line that will\n\
#be included in the final blacklist. If the file does not exist it will not be used.\n\
#If a domain is listed the entire domain and all subdomains will be blocked.\n\
#If a subdomain or specific host is listed, only that will be blocked.\n\
#This does not use the * to denote a domain as the whitelist does.\n\
readonly userblacklist=\"${scriptHome}/dnsblacklist\"\n\\n\
#location of the Unifi provided ads.list\n\
unifiblacklist=\"/run/utm/ads.list\"\n\\n\\n\
#location (directory) of the list-files _this_ script will be generating\n\
listTargetPath=\"/run/getBlacklistHosts\"\n\\n\
#user-defined source URLs\n\
#you can add your own source URLs here from which the script will download\n\
#additional blacklist entries. You can have as may as you like.\n\
#If no URLs are defined it will be skipped during processing.\n\
#This URL can be a zip file containing one or more files.\n\\n\
#user-defined source URL format is:\n\
#URLarray[uniqueLabel]=\"sourceUrl\"\n\
#where uniqueLabel is a unique (per URL) character string with no spaces or extended characters and\n\
#sourceUrl is the URL to pull from.\n\\n\
#example:\n\
#URLarray[site1]=\"https://TestMyLocalUDMsDNS.com/badhosts\"\n\
#URLarray[site2]=\"https://TestMyLocalUDMsDNS2.com/morebadhosts\"\n\\n\\n\\n\\n\
#script-provided source URLs\n\
#These are the source URLs that come with this script.\n\
#The first entries are the pi-hole sources listed at\n\
#https://github.com/pi-hole/pi-hole/blob/master/adlists.default\n\
#If you want to run exactly the same sources as pi-hole, comment out\n\
#the other sources in this section.\n\
#If you do not want to use any of these sources you may comment them all out.\n\
#As a note, please do not remove or add lines from this section.\n\
#To remove sources simply comment out the line with a leading #.\n\
#To add sources please add them to the user-defined section above.\n\
#This is to ensure that if future updates contain more sources they can be added\n\
#via the script during the update process and not confict with any user made changes.\n\\n\
#Pi-hole source 1: StevenBlack list\n\
ProvidedURLarray[pi1]=\"https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts\"\n\\n\
#Pi-hole source 2: MalwareDomains\n\
ProvidedURLarray[pi2]=\"https://raw.githubusercontent.com/RPiList/specials/master/Blocklisten/malware\"\n\\n\
#Pi-hole source 3: Cameleon\n\
ProvidedURLarray[pi3]=\"http://sysctl.org/cameleon/hosts\"\n\\n\
#Pi-hole source 4: Zeustracker\n\
ProvidedURLarray[pi4]=\"https://zeustracker.abuse.ch/blocklist.php?download=domainblocklist\"\n\\n\
#Pi-hole source 5: Disconnect.me Tracking\n\
ProvidedURLarray[pi5]=\"https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt\"\n\\n\
#Pi-hole source 6: Disconnect.me Ads\n\
ProvidedURLarray[pi6]=\"https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt\"\n\\n\
#Pi-hole source 7: Hosts-file.net\n\
ProvidedURLarray[pi7]=\"https://raw.githubusercontent.com/evankrob/hosts-filenetrehost/master/ad_servers.txt\"\n\\n\
#Other source 1\n\
ProvidedURLarray[os1]=\"http://winhelp2002.mvps.org/hosts.txt\"\n\\n\
#Other source 2\n\
ProvidedURLarray[os2]=\"https://adaway.org/hosts.txt\"\n\\n\
#Other source 3\n\
ProvidedURLarray[os3]=\"https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&mimetype=plaintext\"\n\\n\
#Other source 4\n\
ProvidedURLarray[os4]=\"https://someonewhocares.org/hosts/hosts/\"\n\\n\
#What is the time limit (in seconds) for each file download?\n\
#This is to set a limit for curl when downloading from each source.\n\
#Without a limit curl would wait forever for a file to finish.\n\
#This sets the --max-time parameter for curl.\n\
#If you have a slower connection, you may need to increase the default 60 seconds.\n\
curlMaxTime=\"60\"\n\\n\
#What IP address do you want the blocked hosts to resolve to?\n\
#0.0.0.0 is the default setting.\n\
#This has to be a valid IP address, not URL or hostname.\n\
#For more information on why the default is not 127.0.0.1, see here:\n\
#https://github.com/StevenBlack/hosts#we-recommend-using-0000-instead-of-127001\n\
resolveAddress=\"0.0.0.0\"\n\\n\
#debugging\n\
#do you want to save a copy of these files for debugging:\n\
#nonFilteredHosts - contains raw dump of all the downloaded and user-defined hosts\n\
#singleDomains - list of all single domains from which all sub-domains will be removed in the final list\n\
#filteredHosts - contains the cleaned list before whitelist processing\n\
#finalHosts - final file after whitelist procesing that dnsmasq entries are created from\n\
#these files will be saved in ${scriptHome}/debug by default.\n\
#true/false\n\
enableDebugging=false\n\\n\
#change the default debugging output directory by changing the next line\n\
#this directory must exist. Do not put a trailing slash\n\
debugDirectory=${scriptHome}/debug\n\\n\
#do you want to stop the script before files are created?\n\
#false (default setting) - script runs and configures only\n\
#true - script will process downloads then stop. It will not create final list nor update the active settings\n\
#This will let you test your file downloads and generate (if you configure them) debug files.\n\
stopBeforeConfig=false\n\\n\
#do you want to receive an email when script is run? true/false\n\
#note this host must be setup to send mail via /usr/bin/ssmtp\n\
#see revaliases and ssmtp.conf in /etc/ssmtp to be adjusted accordingly\n\
sendEmails=false\n\
#email address (user@domain.com) to send mail to\n\
emailtoaddr=\"youruser@somedomain.com\"\n\\n\
#mail from name to use\n\
emailfromname=\"UDM Main Router\"\n\\n\
#email address (user@domain.com) to send mail from\n\
#note this address must be setup to send mail via /usr/bin/ssmtp\n\
#see revaliases and ssmtp.conf in /etc/ssmtp\n\
emailfromaddr=\"udm@somedomain.com\"\n\\n\
#email subject to use\n\
emailsubject=\"UDM hostblacklist updated\"\n\\n\
#do you want to create a comma delimited history count when script is run? true/false\n\
recordHistory=false\n\\n\
#full path and filename to file which holds the comma delmited hosts count history\n\
#this is ignored if recordHistory is set to false above\n\
historycountFile=\"${scriptHome}/BlacklistHistoryCount.txt\"\n\\n\
################################\n\
#data from reoccuring runs is below, do not edit\n"> ${dataFile}

        echo -e "current_count=\"$convert_current\"" >> ${dataFile}
        echo -e "old_count=\"$convert_old\"" >> ${dataFile}

        cleanup
        cleanupOthers

        echo " " | sendmsg
        echo ".    Created default data file which did not exist, the Blacklist Hosts have NOT been updated." | sendmsg
        echo ".    Next time the script runs the Blacklist Hosts will be updated." | sendmsg
        echo ".    This is so you can adjust settings in ${dataFile} before the first updates." | sendmsg
        echo ".    Once you have made changes (or not if you want the defaults), run this script again." | sendmsg
        echo " " | sendmsg
        exit
    fi
}

function check_dependencies() {
    echo ".    Checking dependencies for getBlacklistHosts ${version}..." | sendmsg
    #Sanity check to ensure all script dependencies are met.
    for cmd in cat curl date mktemp pkill rm sed sort uniq grep; do
        if ! type "${cmd}" &> /dev/null; then
            bError=true
            echo ".      This script requires the command '${cmd}' to run. Install '${cmd}', make it available in \$PATH and try again." | sendmsg
        fi
    done
    ${bError:-false} && echo ".    ...failed" | sendmsg && exit 1
    echo ".    ....passed." | sendmsg

    stringGrepText=$(grep --version 2>&1)

    if [[ $stringGrepText = *"BusyBox"* ]]; then
        echo ".    WARNING - BusyBox Grep detected. This script may take several hours to run, please install GNU Grep for a better experience!" | sendmsg
    fi
}

sendmsg()
{
	read IN
	if [ -t 1 ]; then
	    echo -e "$IN"
		echo -e "$IN" >> ${logFile}
		
	else
	    echo -e "$IN" >> ${logFile}
	fi
}

################################################################################
# MAIN 
################################################################################
#Used for cleanup on ctrl-c / ensure this script exit cleanly.
trap 'control_c' HUP INT QUIT TERM

echo " " | sendmsg
echo ".    Starting getBlacklistHosts ${version}..." | sendmsg

check_dependencies

#Temporary files to hold the new hosts and cleaned up hosts
readonly sTmpNewHosts="$(mktemp "/tmp/tmp.newhosts.XXXXXX")"
readonly sTmpAdHosts="$(mktemp "/tmp/tmp.adhosts.XXXXXX")"
readonly sTmpDomainss="$(mktemp "/tmp/tmp.addomains.XXXXXX")"
readonly sTmpSubFilters="$(mktemp "/tmp/tmp.subFilters.XXXXXX")"
readonly sTmpDomains2s="$(mktemp "/tmp/tmp.addomains2.XXXXXX")"
readonly sTmpCleaneds="$(mktemp "/tmp/tmp.cleaned.XXXXXX")"
readonly sTmpWhiteDomains="$(mktemp "/tmp/tmp.whiteDomains.XXXXXX")"
readonly sTmpWhiteHosts="$(mktemp "/tmp/tmp.whiteHosts.XXXXXX")"
readonly sTmpWhiteNoneWild="$(mktemp "/tmp/tmp.whiteNonWild.XXXXXX")"
readonly sTmpExtracts="$(mktemp -d "/tmp/tmp.hostExtract.XXXXXX")"
readonly sTmpHostSplitterD="$(mktemp -d "/tmp/tmp.hostsplitter.XXXXXX")"
readonly sTmpWhiteNonSub="$(mktemp "/tmp/tmp.whiteNonWild.XXXXXX")"
readonly sTmpCurlDown="$(mktemp "/tmp/tmp.CurlDown.XXXXXX")"
readonly sTmpCurlUnzip="$(mktemp -d "/tmp/tmp.CurlUnzip.XXXXXX")"

if [ ! -w "${messageFile}" ]; then
    echo "Failed to create temporary file messageFile " | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${messageHeader}" ]; then
    echo "Failed to create temporary file messageHeader " | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${messageFooter}" ]; then
    echo "Failed to create temporary file messageFooter " | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpNewHosts}" ]; then
    echo "Failed to create temporary file sTmpNewHosts " | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpAdHosts}" ]; then
    echo "Failed to create temporary file sTmpAdHosts" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpDomainss}" ]; then
    echo "Failed to create temporary file sTmpDomainss" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpSubFilters}" ]; then
    echo "Failed to create temporary file sTmpSubFilters" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi


if [ ! -w "${sTmpDomains2s}" ]; then
    echo "Failed to create temporary file sTmpDomains2s" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpCleaneds}" ]; then
    echo "Failed to create temporary file sTmpCleaneds" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpWhiteDomains}" ]; then
    echo "Failed to create temporary file sTmpWhiteDomains" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpWhiteHosts}" ]; then
    echo "Failed to create temporary file sTmpWhiteHosts" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpWhiteNoneWild}" ]; then
    echo "Failed to create temporary file sTmpWhiteNoneWild" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpWhiteNonSub}" ]; then
    echo "Failed to create temporary file sTmpWhiteNonSub" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpCurlDown}" ]; then
    echo "Failed to create temporary file sTmpCurlDown" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpCurlUnzip}" ]; then
    echo "Failed to create temporary directory sTmpCurlUnzip" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpExtracts}" ]; then
    echo "Failed to create temporary directory sTmpExtracts" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

if [ ! -w "${sTmpHostSplitterD}" ]; then
    echo "Failed to create temporary directory sTmpHostSplitterD" | sendmsg
    echo "This probably means the filesystem is full or read-only." | sendmsg
    cleanup
	cleanupOthers
    exit 2
fi

check_crontab
check_config_file

declare -A URLarray
declare -A ProvidedURLarray

source ${dataFile}

if [ "$enableDebugging" = true ] ; then
	echo ".    Directory for debugging: ${debugDirectory}" | sendmsg
	mkdir -p ${debugDirectory}
fi

if [ ! -f "${listTargetPath}" ] ; then
	echo ".    Target path for generated lists: ${listTargetPath}" | sendmsg
    mkdir -p ${listTargetPath}
fi

#Download and merge multiple hosts files to ${sTmpNewHosts}

downloadErrors=0

## one to test with
#even if all other sources are disabled you will have one record
echo "#debugging: getBlacklistHosts.sh Testing record start" > "${sTmpNewHosts}"
echo "testMyLocalUDMsDNS.com" >> "${sTmpNewHosts}"
echo "#debugging: getBlacklistHosts.sh Testing record end" >> "${sTmpNewHosts}"

if [ ! -f "${unifiblacklist}" ] ; then
	echo ".    Not using the unifi-default blacklist..." | sendmsg
else
    echo ".    Adding the unifi-default blacklist..." | sendmsg
	echo "#debugging: unifi-default blacklist records start" >> "${sTmpNewHosts}"
	lastCount=$(wc -l < ${sTmpNewHosts});
	cat ${unifiblacklist} >> "${sTmpNewHosts}"
	thisCount=$(wc -l < ${sTmpNewHosts})
	echo ".    Got "$((thisCount-lastCount))" records. Raw data count now: "${thisCount}| sendmsg
	echo "#debugging: unifi-default blacklist records end" >> "${sTmpNewHosts}"
fi

if [ ! -f ${userblacklist} ]; then
	echo ".    Not using a user-defined blacklist..." | sendmsg
else
    echo ".    Using a user-defined blacklist..." | sendmsg
	echo ".    Cleaning user-defined blacklist..." | sendmsg
	sed -i -e "s/[[:space:]]\+//g" ${userblacklist}
	sed -i '/^ *$/d' ${userblacklist}
	echo ".    Adding user-defined blacklist..." | sendmsg
	echo "#debugging: user-defined blacklist records start" >> "${sTmpNewHosts}"
	lastCount=$(wc -l < ${sTmpNewHosts});
	cat ${userblacklist} >> "${sTmpNewHosts}"
	thisCount=$(wc -l < ${sTmpNewHosts})
	echo ".    Got "$((thisCount-lastCount))" records. Raw data count now: "${thisCount}| sendmsg
	echo "#debugging: user-defined blacklist records end" >> "${sTmpNewHosts}"
fi

if [ ${#URLarray[@]} -eq 0 ]; then
    echo ".    Not using any user-defined source URLs..." | sendmsg
else
	echo ".    Using user-defined source URLs..." | sendmsg
	for URLarray_idx in ${!URLarray[@]}; do
		echo ".    Downloading user-defined URL $URLarray_idx - ${URLarray[$URLarray_idx]}..." | sendmsg
		echo "#debugging: user-defined source: ${URLarray[$URLarray_idx]} records start" >> "${sTmpNewHosts}"
		lastCount=$(wc -l < ${sTmpNewHosts});
		lastCount=$((lastCount-1));
		#curl --silent --max-time ${curlMaxTime} ${URLarray[$URLarray_idx]} >> "${sTmpNewHosts}"
		curlError=$((curl -# --silent --show-error --max-time ${curlMaxTime} -o ${sTmpCurlDown} ${URLarray[$URLarray_idx]} >/dev/null) 2>&1)
		curlCode=$?
		if [ $curlCode -eq 0 ]; then
			#unzip if need be
			if [ ${URLarray[$URLarray_idx]: -4} == ".zip" ]; then
				echo ".    Unzipping file..." | sendmsg
				rm -f ${sTmpCurlUnzip}/*
				unzipError=$((/usr/bin/unzip -qq ${sTmpCurlDown} -d ${sTmpCurlUnzip} >/dev/null) 2>&1)
				zipCode=$?
				if [ $zipCode -eq 0 ]; then
					> ${sTmpCurlDown}
					cat ${sTmpCurlUnzip}/* >> ${sTmpCurlDown}
				else
				echo ".    Unzip had an error of code "$zipCode| sendmsg
				fi
			fi
		
			cat ${sTmpCurlDown} >> ${sTmpNewHosts}
		else
			if [ $curlCode -ne 0 ]; then
				((downloadErrors++))
				echo ".    Warning from "$curlError| sendmsg
			fi 
		
			if [ $curlCode -eq 28 ]; then
				echo ".    The curlMaxTime of ${curlMaxTime} in the conf file is too small"| sendmsg
			fi
		fi

		thisCount=$(wc -l < ${sTmpNewHosts})
		echo ".    Got "$((thisCount-lastCount))" records. Raw data now: "${thisCount}| sendmsg
		echo "#debugging: user-defined source: ${URLarray[$URLarray_idx]} records end" >> "${sTmpNewHosts}"
	done
fi

if [ ${#ProvidedURLarray[@]} -eq 0 ]; then
    echo ".    Not using any script-provided source URLs..." | sendmsg
else
	echo ".    Using script-provided source URLs..." | sendmsg
	for ProvidedURLarray_idx in ${!ProvidedURLarray[@]}; do
		echo ".    Downloading script-provided URL $ProvidedURLarray_idx - ${ProvidedURLarray[$ProvidedURLarray_idx]}..." | sendmsg
		echo "#debugging: script-provided source: ${ProvidedURLarray[$ProvidedURLarray_idx]} records start" >> "${sTmpNewHosts}"
		lastCount=$(wc -l < ${sTmpNewHosts});
		lastCount=$((lastCount-1));
		#curl --silent --max-time ${curlMaxTime} ${ProvidedURLarray[$ProvidedURLarray_idx]} >> "${sTmpNewHosts}"
		curlError=$((curl -# --silent --show-error --max-time ${curlMaxTime} -o ${sTmpCurlDown} ${ProvidedURLarray[$ProvidedURLarray_idx]} >/dev/null) 2>&1)
		curlCode=$?
		if [ $curlCode -eq 0 ]; then
			#unzip if need be
			if [ ${ProvidedURLarray[$ProvidedURLarray_idx]: -4} == ".zip" ]; then
				echo ".    Unzipping file..." | sendmsg
				rm -f ${sTmpCurlUnzip}/*
				unzipError=$((/usr/bin/unzip -qq ${sTmpCurlDown} -d ${sTmpCurlUnzip} >/dev/null) 2>&1)
				zipCode=$?
				if [ $zipCode -eq 0 ]; then
					> ${sTmpCurlDown}
					cat ${sTmpCurlUnzip}/* >> ${sTmpCurlDown}
				else
				echo ".    Unzip had an error of code "$zipCode| sendmsg
				fi
			fi
		
			cat ${sTmpCurlDown} >> ${sTmpNewHosts}
		else
			if [ $curlCode -ne 0 ]; then
				((downloadErrors++))
				echo ".    Warning from "$curlError| sendmsg
			fi 
		
			if [ $curlCode -eq 28 ]; then
				echo ".    The curlMaxTime of ${curlMaxTime} in the conf file is too small"| sendmsg
			fi
		fi
		
		thisCount=$(wc -l < ${sTmpNewHosts})
		echo ".    Got "$((thisCount-lastCount))" records. Raw data count now: "${thisCount}| sendmsg
		echo "#debugging: script-provided source: ${ProvidedURLarray[$ProvidedURLarray_idx]} records end" >> "${sTmpNewHosts}"
	done
fi

if [ "$enableDebugging" = true ] ; then
	echo ".    Creating debugging file nonFilteredHosts..." | sendmsg
    cp ${sTmpNewHosts} ${debugDirectory}/nonFilteredHosts
fi

#Convert hosts text to the UNIX format. Strip comments, blanklines, and invalid characters.
#Replaces tabs/spaces with a single space, remove localhost entries.
#There will be at least one here due to the hardcoded testMyLocalUSGDns.com hostname
echo ".    Sanitizing downloaded blacklists..." | sendmsg
echo ".    Raw data stage 1 count: "$(wc -l < ${sTmpNewHosts})| sendmsg

#pre-remove subdirectories and lines with no '.' 
sed -i -e 's~http[s]*://~~g' ${sTmpNewHosts}
sed -i -e '/\./!d' -e 's/\/.*$//' -e 's/\-*//' -e 's/^www[[:digit:]]*\.//' -e 's/\.*//' -e 's/\.$//' ${sTmpNewHosts}

exec 3>"${sTmpAdHosts}"
sed -r -e "s/$(echo -en '\r')//g" \
       -e '/^#/d' \
       -e 's/#.*//g' \
       -e 's/[^a-zA-Z0-9\.\_\t \-]//g' \
       -e 's/(\t| )+/ /g' \
       -e 's/^127\.0\.0\.1/0.0.0.0/' \
       -e '/ localhost( |$)/d' \
       -e '/^ *$/d' \
        "${sTmpNewHosts}" >&3
exec 3>&-

echo ".    Raw data stage 2 count: "$(wc -l < ${sTmpNewHosts})| sendmsg

echo ".    Converting full blacklist..." | sendmsg
/bin/sed -i -r -e 's/0.0.0.0 //g' ${sTmpAdHosts}  
/bin/sed -i -r -e '/^[0-9\.]*$/d' ${sTmpAdHosts}  
/bin/sed -i -e "s/[[:space:]]\+//g" ${sTmpAdHosts}

#make the list unique
/usr/bin/sort -u ${sTmpAdHosts} -o ${sTmpAdHosts}

echo ".    Creating list of single domains..." | sendmsg
#process out single domains
grep -E "^[^.]*+.[^.]*+$" ${sTmpAdHosts} > ${sTmpDomainss}
#so we have a filter even if no whitelist
cp ${sTmpDomainss} ${sTmpSubFilters}

if [ -f ${whitelist} ]; then
	echo ".    Using a whitelist..." | sendmsg
	echo ".    Cleaning whitelist..." | sendmsg
	sed -i -e "s/[[:space:]]\+//g" ${whitelist}
	sed -i '/^ *$/d' ${whitelist}

	#process out sub domains from whitelist
	grep -Ev "^[^.]*+.[^.]*+$" ${whitelist} > ${sTmpWhiteHosts}
	
	#get list of domains only
	grep -E "^[^.]*+.[^.]*+$" ${whitelist} > ${sTmpWhiteNonSub}
	
	#remove any whitelisted non wildcards from sTmpDomainss
	sed '/\*/!d' ${whitelist} > ${sTmpWhiteNoneWild}
	
	#add start and end
	/bin/sed -i -e 's/^/\$/' -e 's/$/\$/' ${sTmpWhiteNoneWild}
	/bin/sed -i -e 's/^/\$/' -e 's/$/\$/' ${sTmpDomainss}
	/bin/grep -v -F -f ${sTmpWhiteNoneWild} ${sTmpDomainss} > ${sTmpDomains2s}
	
	#remove whitelisted domains from single domain blacklist filter to keep the subs in blacklist
	#add start and end
	/bin/sed -i -e 's/^/\$/' -e 's/$/\$/' ${sTmpWhiteNonSub}
	/bin/grep -v -F -f ${sTmpWhiteNonSub} ${sTmpDomainss} > ${sTmpSubFilters}
	
	#remove start and end
	#### end /bin/sed -i -e "s/\$\+//g"
	/bin/sed -i -e "s/\$\+//g" ${sTmpWhiteNoneWild}
	/bin/sed -i -e "s/\$\+//g" ${sTmpDomainss}
	/bin/sed -i -e "s/\$\+//g" ${sTmpDomains2s}
	/bin/sed -i -e "s/\$\+//g" ${sTmpWhiteNonSub}
	/bin/sed -i -e "s/\$\+//g" ${sTmpSubFilters}
	
	cat ${sTmpDomains2s} > ${sTmpDomainss}
fi

#add start of string marker to single domain list
/bin/sed -i -e 's/$/\$/' ${sTmpDomainss}

#add end of string marker to the blacklist list
/bin/sed -i -e 's/$/\$/' ${sTmpAdHosts}

iSingleDomainCount="$(wc -l "${sTmpDomainss}" | cut -d ' ' -f 1)"
echo ".    Found ${iSingleDomainCount} single domains..." | sendmsg

#add leading dot to single domain list
/bin/sed -i -e 's/^/\./' ${sTmpSubFilters}

echo ".    Removing sub-domains..." | sendmsg
#remove any subdomains of our domains list since we are blocking as domains
/bin/grep -v -F -f ${sTmpSubFilters} ${sTmpAdHosts} > ${sTmpCleaneds}

if [ "$enableDebugging" = true ] ; then
	echo ".    Creating debugging file singleDomains..." | sendmsg
	#remove the end of string marker
	/bin/sed -i -e "s/\$\+//g" ${sTmpDomainss}
	cp ${sTmpDomainss} ${debugDirectory}/singleDomains
fi

#add cleaned to domain list
cat ${sTmpCleaneds} >> ${sTmpDomainss}

#remove the end of string marker
/bin/sed -i -e "s/\$\+//g" ${sTmpDomainss}

#safety check remove sub-directories
/bin/sed -i 's/\/.*//' ${sTmpDomainss}

#make the list unique
/usr/bin/sort -u ${sTmpDomainss} -o ${sTmpDomainss}

#safety check remove any blank lines and lines with no dot
/bin/sed -i '/^[^.]*$/d' ${sTmpDomainss}

#replace our original list with the cleaned list
cat ${sTmpDomainss} > ${sTmpAdHosts}

old_count=${current_count}

if [ "$enableDebugging" = true ] ; then
	echo ".    Creating debugging file filteredHosts..." | sendmsg
	cp ${sTmpAdHosts} ${debugDirectory}/filteredHosts
fi

#Verify parsing of the hostlist succeeded, at least 1 blacklist entries are expected.
iBlackListCount="$(wc -l "${sTmpAdHosts}" | cut -d ' ' -f 1)"
if [ "${iBlackListCount}" -lt "1" ]; then
    echo ".    ${iBlackListCount} blacklist entries discovered. Minimum of 1 expected. Aborting." | sendmsg
    cleanup
	cleanupOthers
    exit 3
fi

if [ ! -f ${whitelist} ]; then
	echo ".    Not using a whitelist..." | sendmsg
    cat ${sTmpAdHosts} > ${sTmpHostSplitterD}/fullhosts
	current_count=$(wc -l < ${sTmpAdHosts})
else
	mathbeforewhite=$(wc -l < ${sTmpAdHosts})
	echo ".    Processing whitelist..." | sendmsg
	#add the whitelist found single domains to the empty sTmpWhiteDomains file
	#there used to be data in sTmpWhiteDomains at this point
	#but the whitelist logic changed that.
	#this is to maintain the used var name moving forward
	cat ${whitelist} >> ${sTmpWhiteDomains}
	
	#make the list unique
	/usr/bin/sort -u ${sTmpWhiteDomains} -o ${sTmpWhiteDomains}
	
	#add start and end of string marker 
	/bin/sed -i -e 's/^/\$/' -e 's/$/\$/' ${sTmpWhiteDomains}
	/bin/sed -i -e 's/^/\$/' -e 's/$/\$/' ${sTmpAdHosts}
	
	#remove start of line marker and * from wildcards
	/bin/sed -i 's/^\$\*[\.]*//g' ${sTmpWhiteDomains}
	
    /bin/grep -v -F -f  ${sTmpWhiteDomains} ${sTmpAdHosts} > ${sTmpHostSplitterD}/fullhosts
	
	#remove start and end string markers from the list of whitelist domains
	/bin/sed -i -e "s/\$\+//g" ${sTmpHostSplitterD}/fullhosts
	
	current_count=$(wc -l < /${sTmpHostSplitterD}/fullhosts)
	 
	if [ "${current_count}" -lt "1" ]; then
      echo ".    ${current_count} blacklist entries found after processing whitelist. Something went wrong, was everything whitelisted? Aborting." | sendmsg
      cleanup
	  cleanupOthers
      exit 3
    fi
fi

if [ "$enableDebugging" = true ] ; then
	echo ".    Creating debugging file finalHosts..." | sendmsg
	cp ${sTmpHostSplitterD}/fullhosts ${debugDirectory}/finalHosts
	
	if [ -f ${whitelist} ]; then
		echo ".    Creating debugging file finalWhite..." | sendmsg
		cp ${sTmpWhiteHosts} ${debugDirectory}/finalWhite
	fi
fi


echo -e "Old count: ${old_count}" > ${messageFile};
echo ".    Old count: ${old_count}..." | sendmsg

if [ ! -f ${whitelist} ]; then
	echo -e "New count (not using a whitelist): ${current_count}" >> ${messageFile};
	echo ".    New count (not using a whitelist): ${current_count}..." | sendmsg
else
	echo -e "New count before whitelist processing: ${mathbeforewhite}" >> ${messageFile};
	echo ".    New count before whitelist processing: ${mathbeforewhite}..." | sendmsg
	echo -e "New count after whitelist processing: ${current_count}" >> ${messageFile};
	echo ".    New count after whitelist processing: ${current_count}..." | sendmsg
fi


mathold=${old_count}
mathnew=${current_count}
mathchange=$((mathnew-mathold))
if [ "${mathchange}" -gt "0" ]; then
	mathchange="+"${mathchange}
fi

echo -e "Old count to new count change: ${mathchange}" >> ${messageFile};
echo ".    Old count to new count change: ${mathchange}..." | sendmsg

if [ "$stopBeforeConfig" = true ] ; then
  cleanup
  cleanupOthers
  echo ".    " | sendmsg
  echo ".    Processing has ended... 'stopBeforeConfig' is set to true in the configuration file..." | sendmsg
  echo ".    The Blacklist Hosts have NOT been updated." | sendmsg
  echo ".    " | sendmsg
  endTime=`date +%s`
  runTimeSec=$((endTime-startTime))
  runTimeMin=$((runTimeSec/60))
  runTimeRemainder=$((runTimeSec-(runTimeMin*60)))
  runTime=$runTimeSec" seconds or "$runTimeMin" minutes "$runTimeRemainder" seconds"
  echo ".    Script execution time: $runTime" | sendmsg
  exit
fi


if [ "$recordHistory" = true ] ; then
	echo ".    Recording history count..." | sendmsg
	if [ -f ${historycountFile} ]; then
		echo -n "," >> ${historycountFile}
	fi
	echo ${current_count}| tr -d '\n' >> ${historycountFile}
fi

rm -rf ${sTmpExtracts}

cp ${sTmpHostSplitterD}/fullhosts ${listTargetPath}/fullhosts
rm -rf ${sTmpHostSplitterD}

if [ -f ${whitelist} ]; then
    cp ${sTmpWhiteHosts} ${listTargetPath}/whitehosts
fi

#Cleanup.
cleanup

# Update UDM source-list to use from now on (default is /run/utm/ads.list but we want our to be used now)
if [ -f "${listTargetPath}/fullhosts" ]; then
    /bin/sed -i "s|ADSDOMAINS=.*|ADSDOMAINS=\"${listTargetPath}/fullhosts\"|" ${dnsfilterfile} | sendmsg
    echo ".    Calling UDM script to repflect update immediately." | sendmsg

    # remove udm's ads.list marker-file first to simulate its first run
    if [ -f "/run/utm/ads.list.gz.ts" ]; then
        rm /run/utm/ads.list.gz.ts
    fi

    # do the actual run of the ad-blocker update in UDM
    ${dnsfilterfile}
fi

#Send Mail
endTime=`date +%s`
runTimeSec=$((endTime-startTime))
runTimeMin=$((runTimeSec/60))
runTimeRemainder=$((runTimeSec-(runTimeMin*60)))
runTime=$runTimeSec" seconds or "$runTimeMin" minutes "$runTimeRemainder" seconds"
echo ".    Script execution time: $runTime" | sendmsg
echo " " | sendmsg

if [ "$sendEmails" = true ] ; then
echo -e "To: ${emailtoaddr}\n\
From: ${emailfromname}<${emailfromaddr}>\n\
Subject: ${emailsubject}\n\
MIME-Version: 1.0\n\
Content-Type: text/html\n\
Content-Disposition: inline\n\
\n\
<html>\n\
<body>\n\
<pre style='font: monospace'>" > ${messageHeader};

echo -e "blacklisthosts updated at "$(date)"\n" >> ${messageHeader};
echo -e "Script execution time: $runTime\n" >> ${messageHeader};
fi

if [ "$sendEmails" = true ] ; then
	echo -e "\n" > ${messageFooter};
	echo -e "Log from this run:" >> ${messageFooter};
	cat ${logFile} >> ${messageFooter}
	echo -e "</pre></body></html>" >> ${messageFooter}
#	cat ${messageHeader} ${messageFile} ${messageFooter} | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | sed "s/\x0f//g" | /usr/sbin/ssmtp ${emailtoaddr};&
	cat ${messageHeader} ${messageFile} ${messageFooter} | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | sed "s/\x0f//g" | /usr/sbin/ssmtp ${emailtoaddr}&
fi

echo -e "\n" >> ${logFile};
cat ${messageFile} >> ${logFile}

# update the data file
/bin/sed -i '/current_count=/d' ${dataFile}
echo -e "current_count=\"$current_count\"" >> ${dataFile}
/bin/sed -i '/old_count=/d' ${dataFile}
echo -e "old_count=\"$old_count\"" >> ${dataFile}

if [ -t 1 ]; then
		echo -e " "
	    echo -e "getBlacklistHosts ${version} completed, these messages also recorded at ${logFile}."
		echo -e "Script execution time: $runTime" 
		echo -e " "
fi

cleanupOthers

exit 0
##END getBlacklistHosts
