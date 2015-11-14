# PAM changes
$duo_pam_module             = '/lib64/security/pam_duo.so'
$aug_system_auth_pam_path   = '/files/etc/pam.d/system-auth'
$aug_system_auth_match      = "${aug_system_auth_pam_path}/*/module[. = '${duo_pam_module}']"
$aug_sshd_pam_path          = '/files/etc/pam.d/sshd'
$aug_sshd_match             = "${aug_sshd_pam_path}/*/module[. = '${duo_pam_module}']"

augeas { 'PAM system-auth Configuration':
    changes => [
        "set ${aug_system_auth_pam_path}/2/control requisite",
        "ins 100 after ${aug_system_auth_pam_path}/2",
        "set ${aug_system_auth_pam_path}/100/type auth",
        "set ${aug_system_auth_pam_path}/100/control    sufficient",
        "set ${aug_system_auth_pam_path}/100/module ${duo_pam_module}"
    ],
    onlyif => "match ${aug_system_auth_match} size == 0",
    notify => Service['sshd'],
} ->
augeas { 'PAM sshd configuration':
    changes => [
        "ins 100 after ${aug_sshd_pam_path}/1",
        "set ${aug_sshd_pam_path}/100/type auth",
        "set ${aug_sshd_pam_path}/100/control   required",
        "set ${aug_sshd_pam_path}/100/module ${duo_pam_module}"
    ],
    onlyif => "match ${aug_sshd_match} size == 0",
    notify => Service['sshd'],
}

service { 'sshd':
    ensure => running,
    enable => true,
}
