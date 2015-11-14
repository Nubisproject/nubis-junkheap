augeas { 'Duo Security SSH Configuration' :
    changes => [
        'set /files/etc/ssh/sshd_config/UsePAM yes',
        'set /files/etc/ssh/sshd_config/UseDNS no',
        'set /files/etc/ssh/sshd_config/ChallengeResponseAuthentication yes',
        'set /files/etc/ssh/sshd_config/AuthenticationMethods "publickey,keyboard-interactive"',
        'set /files/etc/ssh/sshd_config/PubkeyAuthentication yes',
        'set /files/etc/ssh/sshd_config/PasswordAuthentication no',
    ],
    notify  => Service['sshd'];
}

service { 'sshd':
    ensure  => running,
    enable  => true,
}
