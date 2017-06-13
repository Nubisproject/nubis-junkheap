ULIST="_userlist"

#stderr colorizer
color()(set -o pipefail;"$@" 2>&1>&3|sed $'s,.*,\e[90m&\e[m,'>&2)3>&1

function fail() {
    echo $*
    exit 1
}

function safedelete()
{
    local prog
    if [[ -x $(which srm) ]]; then
        prog=$(which srm)
    else
        prog=$(which shred)
    fi
    [[ -z "${prog}" ]] && {
        fail "WARNING: Safe deletion of $1 failed, please manually wipe with srm or equivalent secure deletion program."
    }

    ${prog} $1 || {
        fail "WARNING: Safe deletion of $1 failed, please manually wipe with srm or equivalent secure deletion program."
    }
}

function verify_userlist() {
    local userlist=$1
    if [ -z "${userlist}" ]; then echo "Usage: ${FUNCNAME} <userlist file>"; exit 1; fi

    if [ ! -f "${userlist}.sig" ]; then
        fail "ERROR: could not find signature file"
    fi

    gpg --verify "${userlist}".sig
    rv=$?

    return $?
}

function encrypt() {
    local filename=$1
    if [ -z "${filename}" ]; then echo "Usage: ${FUNCNAME} <file to encrypt>"; exit 1; fi

    local flatulist=$(awk '{print $2}' ${ULIST}|tr '\n' ' '|sed 's/\ 0x/\ -r\ 0x/g')
    local users=$(awk '{print $1}' ${ULIST}|tr '\n' ' ')

    if [ -z "${flatulist}" ]; then
        echo "Empty fingerprint list, nothing to encrypt to"
        return 1
    fi

    echo "Encrypting ${filename} to ${users}..."
    gpg -r ${flatulist} -ae "${filename}"
    rv=$?

    return $rv
}
