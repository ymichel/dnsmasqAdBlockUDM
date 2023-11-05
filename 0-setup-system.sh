#!/bin/bash
# This script re-installs packages if they are not installed (after a system update). 
# it should be copied to /data/on_boot.d/0-setup-system.sh

if ! dpkg -l ssmtp | grep ii >/dev/null; then
	    apt -y install ssmtp
fi
if ! dpkg -l mosh | grep ii >/dev/null; then
	    apt -y install mosh
fi
if [ `locale -a | grep -c en_US.utf8` -eq 0 ]; then 
	    locale-gen en_US.UTF-8
fi
