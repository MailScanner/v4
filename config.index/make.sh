#!/bin/bash

set -x

cd /root/v4/NEWSTABLE/config.index
php -q create_conf_array.php > conf_array.php
php -q dump_config.php > ../www/MailScanner.conf.index.html

