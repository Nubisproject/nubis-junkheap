#### Installing duo package
In order to install you will need to run the `install-duo` script, the script takes one argument which is the jumphost hostname

Usage:

```bash
./install-duo <jumphost hostname>
```

What this does is installs a special version of `duo_unix` that is patched to talk to LDAP

#### Configuring duo

Once that is all done you will need to configure duo, the file that we care about is located in `/etc/duo/pam_duo.conf`
You will need an `ikey`, `skey` and `host` information all of which you can get from the duosecurity admin panel.

DO NOT GO PAST THIS POINT IF UNLESS YOU HAVE A ROOT CONSOLE TO THE HOST OPENED

#### Configuring SSHD
Edit `/etc/ssh/sshd_config` and add the following lines:

```bash
UsePAM yes
UseDNS no
ChallengeResponseAuthentication yes
AuthenticationMethods "publickey,keyboard-interactive"
PubkeyAuthentication yes
PasswordAuthentication no
```

#### Configuring Pam
Edit `/etc/pam.d/system-auth`, note you only need to add the auth line for duo and not delete anything.

Before:

    ```bash
    auth required    pam_env.so
    auth    sufficient  pam_unix.so nullok try_first_pass
    auth    requisite   pam_succeed_if.so uid >= 500 quiet
    auth    required    pam_deny.so
    ```

After:

    ```bash
    auth required    pam_env.so
    auth    requisite   pam_unix.so nullok try_first_pass
    auth    sufficient  pam_duo.so
    auth    requisite   pam_succeed_if.so uid >= 500 quiet
    auth    required    pam_deny.so
    ```

Edit `/etc/pam.d/sshd` and same as about just add the auth pam_duo.so line

Before:

    ```bash
    auth    required    pam_sepermit.so
    auth    substack    password-auth
    ```

After:

    ```bash
    auth    required    pam_sepermit.so
    auth    required    pam_duo.so
    ```

At this point you are done and you just need to restart sshd by running `service sshd restart` and try logging in from a seperate terminal to your account.
