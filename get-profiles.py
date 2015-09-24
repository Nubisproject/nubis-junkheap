#!/usr/bin/env python

import os
import ConfigParser

def get_profiles():

    credentials = os.environ['HOME'] + '/.aws/credentials'

    config = ConfigParser.ConfigParser()
    config.read(credentials)

    for profile in config.sections():
        print profile

if __name__ == '__main__':
    get_profiles()

