#!/bin/bash
# Search ldap for ssh keys and spits them out

if [[ $# -lt 1 ]]; then
    echo "This script will query ldap for an ssh key"
    echo "Usage: $0 <ldap email>"
    exit 1
fi

# Gets ldap password from gpg file
function get_ldap_passwd() {
    gpg --use-agent --batch -q -d ~/.passwd/mozilla.gpg
}

# config
ldap_server=""
bind_dn=""
search_base="dc=mozilla"
bind_password="$(get_ldap_passwd)"

[ -z "${ldap_server}" ] && { echo "LDAP server setting not set"; exit 1; }
[ -z "${bind_dn}" ] && { echo "Bind DN setting not set"; exit 1; }
[ -z "${bind_password}" ] && { echo "Bind password setting not set"; exit 1; }

ldapsearch -LLL -x -D "${bind_dn}" -w "${bind_password}" -h ${ldap_server} -b ${search_base} -o ldif-wrap=no mail=${1} sshPublicKey | sed -n 's/^[ \t]*sshPublicKey:[ \t]*\(.*\)/\1/p'
