### Account opening scripts
Some helper scripts to help me during the account opening process

#### Pre-requisites
Here are some of the tools you will need to get this all working

1. jq
2. aws-vault
3. awscli
4. gnugpg

#### What do the scripts do
* create-account-aliases        - Creates an account alias, sets it to the account name and will also set the vanity url
* create-encrypted-access-file  - Encrypts aws access key file for the nubis-bootstrap user
* create-inline-admin-policy    - Creates an inline admin policy for nubis-bootstrap user (can't use a managed policy because terraform will wipe it)
* create-mfa-token              - Creates an mfa otp uri and encrypts it
* enforce-password-policy       - Sets password policy
* lib.sh                        - Just some generic functions this will be sourced in every script
