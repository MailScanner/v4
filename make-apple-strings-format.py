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
"""Converts MailScanner translation files to apple strings format for
upload to Transfex
"""
import os
import re

from optparse import OptionParser


TRANSLATION_RE = re.compile(r'^(.+)\s+=\s+(.+)$', re.U)
COMMENT_RE = re.compile(r'["]')


if __name__ == '__main__':
    # Run tings mon
    usage = "usage: %prog language file"
    parser = OptionParser(usage)
    _, arguments = parser.parse_args()

    if len(arguments) != 1:
        parser.error("Please specify the mailscanner language file to process")

    filename = arguments[0]

    if not os.path.exists(filename):
        parser.error("Strings file: %s does not exist" % filename)

    with open(filename, 'r') as infile:
        for line in infile:
            if line.startswith('#'):
                print '/* %s */' % line.strip()
            if TRANSLATION_RE.match(line.strip()):
                opt, trans = TRANSLATION_RE.match(line.strip()).groups()
                print '"%s" = "%s";' % (opt, COMMENT_RE.sub(r'\"', trans))