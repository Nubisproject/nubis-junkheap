### Account opening scripts
Some helper scripts to help me during the account opening process

#### Pre-requisites
Here are some of the tools you will need to get this all working

1. jq
2. aws-vault
3. awscli
4. gnugpg

#### What do the scripts do
* create-encrypted-access-file  - Encrypts aws access key file for the nubis-bootstrap user
* create-mfa-token              - Creates an mfa otp uri and encrypts it
* post-open                     - Does a couple of post account opening steps which includes setting account alias, enforcing password policy and setting inline admin policy
* lib.sh                        - Just some generic functions this will be sourced in every script
