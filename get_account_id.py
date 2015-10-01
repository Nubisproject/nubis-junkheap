#!/usr/bin/env python
# prints out aws account ID, thats about it

import boto
import argparse

def get_options():
    parser = argparse.ArgumentParser(description="Prints out account ID")
    parser.add_argument('--profile', '-p', default='default', help='Name of AWS profile, defaults to default')

    return parser.parse_args()

def get_account_id(args):
    try:
        return boto.connect_iam(profile_name=args.profile).get_user().arn.split(':')[4]
    except:
         return False

if __name__ == '__main__':
    args = get_options()
    print get_account_id(args)
