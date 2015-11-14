These 2 puppet modules will configure `pam` and `sshd_config` to work with Duo, in order for this to work you will need to copy this to the server you want to MFA.

Before you do anything else first, make sure that you have a existing connection to the server just in case and that you have also configured duo at `/etc/duo/pam_duo.conf`.
Once you have copied everything run the following commands:

```bash
puppet apply /tmp/01_configure_sshd.pp
puppet apply /tmp/02_configure_pam.pp
```
