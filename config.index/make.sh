#!/bin/bash

# this was set in the Build.all script. will switch directories if script is not being run locally
if [ ! -z "$DEVBASEDIR" ]; then
	cd $DEVBASEDIR/config.index
fi

# the php files below should be in the same directory

if [ -a create_conf_array.php ]; then
	php -q create_conf_array.php > /tmp/conf_array.php
fi

if [ -a dump_config.php ]; then
	php -q dump_config.php > /tmp/MailScanner.conf.index.html
fi
