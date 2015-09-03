#!/usr/bin/python
# Script to create user and generate access key
# This script assumes a bunch of things and is by no way
# perfect

import boto.iam
import boto.exception

import os
import sys
import argparse

home_path = os.getenv("HOME")
cfg_files = [ home_path + "/.boto", home_path + "/.aws/credentials", "/etc/boto.cfg" ]

for cfg in cfg_files:
    if os.path.isfile(cfg):
        try:
            # If the file exist we just assume it will load the config
            # doesn't do any sanity check to see if file is legit
            pass
        except:
            print ("Failed to load config, please configure boto")
            print ("More information on configuring boto here: http://boto.readthedocs.org/en/latest/getting_started.html")
            sys.exit(1)

try:
    cfn = boto.connect_iam()
except Exception, e:
    print e
    sys.exit(1)

# Assume you have made a connection
def is_user(aws_user):
    users = cfn.get_all_users('/')['list_users_response']['list_users_result']['users']
    for user in users:
        if user['user_name'] == aws_user:
            return True
    return False

def create_user(aws_user, group):
    try:
        response = cfn.create_user(aws_user)
        user = response.user
        #print user
        response = cfn.add_user_to_group(group, aws_user)
    except boto.exception.BotoClientError, e:
        print ("Error creating user %s: %s" % (aws_user, e))
        sys.exit(1)

def generate_keys(aws_user):
    try:
        response = cfn.create_access_key(aws_user)
        print ("Access key: %s" % response.access_key_id)
        print ("Secret key: %s" % response.secret_access_key)
    except boto.exceptionBotoClientError, e:
        print("Error generating keys for user %s: %s" % (aws_user,e))
        sys.exit(1)

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Create an IAM user and generates access key")
    parser.add_argument('--region', '-r', help="Region to add user")
    parser.add_argument('--group', '-g', default='Admin', help="Group to add user to, defaults to admin")
    parser.add_argument('username', help="Username to add")
    args = parser.parse_args()

    username    = args.username
    group       = args.group

    if not is_user(username):
        print ("Creating IAM user: %s" % username)
        create_user(username, group)
        generate_keys(username)
    else:
        print ("IAM user %s already exist, not doing anything" % username)
        sys.exit(0)
