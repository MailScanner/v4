#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ai ts=4 sts=4 et sw=4
# Baruwa - Web 2.0 MailScanner front-end.
# Copyright (C) 2010-2012  Andrew Colin Kissa <andrew@topdog.za.net>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
"""Converts apple strings format files to MailScanner translation
files
"""

import re
import os
import sys
import codecs

from optparse import OptionParser

COMMENTS_RE = re.compile(r'/\*\s+(#.*)\s+\*/', re.U)
TRANSLATION_RE = re.compile(r'"(.+)"\s+=\s+"(.+)";', re.U)
COMMENT_RE = re.compile(r'\\"')
WRAPPED_STDOUT = codecs.getwriter('UTF-8')(sys.stdout)


if __name__ == '__main__':
    # Run tings mon
    usage = "usage: %prog strings file"
    parser = OptionParser(usage)
    _, arguments = parser.parse_args()

    if len(arguments) != 1:
        parser.error("Please apple strings file to process")

    filename = arguments[0]

    if not os.path.exists(filename):
        parser.error("Strings file: %s does not exist" % filename)

    sys.stdout = WRAPPED_STDOUT
    with codecs.open(filename, 'r', 'utf-16') as infile:
        for line in infile:
            if line.startswith('/*'):
                matches = COMMENTS_RE.match(line.strip())
                print matches.groups()[0]
            if '=' in line:
                matches = TRANSLATION_RE.match(line.strip())
                if matches:
                    opt, trans = matches.groups()
                    print u'%s = %s' % (opt,
                                        COMMENT_RE.sub('"', trans))