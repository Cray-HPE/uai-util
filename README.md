# uai-util

## Overview
The uai-util package installs /usr/bin/uai-ssh.sh which may be
used to start a non-privileged sshd for use in an User Access
Instance.

/usr/bin/uai-ssh.sh should only be run in a container as it will
make modifications to /etc/passwd which may be undesirable.

/usr/bin/uai-ssh.sh requires UAS_PASSWD and UAS_PUBKEY be set to
the user's passwd entry and ssh public key.

## Requirements
The base container must include sshd and ssh-keygen. Additionally,
UAS_PASSWD and UAS_PUBKEY must be set as environment variables
inside the container.

## Usage
This package should be installed in a docker image that is intended
to be launched by cray-uas-mgr. Other uses of this package are not
currently supported.
