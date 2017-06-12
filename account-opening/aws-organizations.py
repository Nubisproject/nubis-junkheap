#!/usr/bin/env python

import boto3
import sys
from optparse import OptionParser

def depaginate(function, resource_key, **kwargs):
    # Will depaginate results made to an aws client
    response = function(**kwargs)
    results = response[resource_key]
    while (response.get("NextToken", None) is not None):
        response = function(NextToken=response.get("NextToken"), **kwargs)
        results = results + response[resource_key]
    return results

def usage():
    print """
Usage: aws-organizations.py [options]

Options:
    -l | --list     List AWS accounts
    -e | --email    Email address to create AWS account with
    -a | --account  Name of AWS account, must use with -e
"""

if __name__ == "__main__":

    parser = OptionParser()
    parser.add_option("-e", "--email", dest="email_address", default='', help="Email address for AWS account")
    parser.add_option("-a", "--account", dest="account_name", default='', help="AWS Account name")
    parser.add_option("-l", "--list", dest="list_accounts", action="store_true", default=False, help="List AWS accounts")
    (options, args) = parser.parse_args()

    client = boto3.client('organizations')
    parent_obj = client.list_roots()['Roots'][0]

    child_accounts = depaginate(
        function=client.list_accounts_for_parent,
        resource_key='Accounts',
        ParentId=parent_obj["Id"]
    )

    if options.list_accounts:
        for index in child_accounts:
            if index['Status'] != 'SUSPENDED':
                print index['Id'] + ' - ' + index['Email'] + ' (' + index['Name'] + ')'
    elif (options.account_name != '') and (options.email_address != ''):
        if not any(index['Email'] == options.email_address for index in child_accounts):
            print "Email " + options.email_address + " does not exist, creating account"
            response = client.create_account(
                    Email=options.email_address,
                    AccountName=options_account_name
            )
            print response
    else:
        usage()
        sys.exit(1)
