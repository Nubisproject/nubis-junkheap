#!/bin/bash

DEFAULT_USERLIST="_userlist"

# gpg key for limed@mozilla.com
DEFAULT_KEY="0xED9FE91E7309D2E8"
GPG="gpg --default-key ${DEFAULT_KEY}"

[[ -n "$USERLIST" ]] || USERLIST=$DEFAULT_USERLIST

echo "Before signing '$USERLIST':"
ls -ald ${USERLIST}
ls -ald ${USERLIST}.sig
echo

$GPG -v --detach-sign ${USERLIST}
$GPG --verify ${USERLIST}.sig ${USERLIST}

if [[ "$?" == 0 ]]; then
    echo
    echo "Signing '$USERLIST' appears to have succeeded. Commit both files below when ready."
    echo
else
    echo
    echo "Signing '$USERLIST' failed!"
    echo
fi

ls -ald ${USERLIST}.sig ${USERLIST}
echo
