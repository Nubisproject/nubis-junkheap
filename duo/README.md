Configuring duo on a nubis jumphost

#### Pre-req
1. Make sure that consul has all the k/v it needs to configure pam_duo. The k/v layout needs these keys (Naturally if its a prod subnet use jumphost-prod instead)
     ```bash
        jumphost-stage/stage/config/host
        jumphost-stage/stage/config/ikey
        jumphost-stage/stage/config/ldap-basedn
        jumphost-stage/stage/config/ldap-binddn
        jumphost-stage/stage/config/ldap-bindpassword
        jumphost-stage/stage/config/ldap-server
        jumphost-stage/stage/config/ldap-smartfail-domain
        jumphost-stage/stage/config/skey
    ```

2. Make sure that we have the latest AMI build that includes the duo package

3. Make sure you have an ssh connection open to the jumphost before configuring duo

### Configuring Duo on nubis-jumphost
Here are the steps to configure a nubis-jumphost to use duo:

1. Create user accounts you need. There is a helper script [here](https://github.com/nubisproject/nubis-junkheap/blob/master/create-users)

2. Run this script to create the user accounts and copy SSH keys, however you need to make sure that you have a gpg encrypted file that contains your LDAP password located in `~/.passwd/mozilla.gpg` and have `gpg-agent` connected. You will also need to be connected to the VPN

3. Once accounts are all create ssh to the jumphost and then run the following command
     ```bash
    # wget https://raw.githubusercontent.com/nubisproject/nubis-junkheap/master/duo/configure-duo
    # ./configure-duo
    ```

4. Test to see if duo works
