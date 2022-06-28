#!/bin/sh

# MIT License
#
# (C) Copyright [2020] Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

echo "Run uai-util tests..."

# Stage a dummy pbs.conf to make sure it moves
mkdir /etc/pbs
echo "PBS_PUBLIC_HOST_NAME=ttl" > /etc/pbs/pbs.conf

echo "Run uai-ssh.sh tests..."
CMD=/usr/bin/uai-ssh.sh

echo "Checking for unset variable UAS_PASSWD..."
. ./test/test-env; UAS_PASSWD=''
if [ "$($CMD)" != "UAS_PASSWD not defined" ]; then
    echo "FAIL: Did not catch empty UAS_PASSWD"
    exit 1
fi

echo "Checking for unset variable UAS_PUBKEY..."
. ./test/test-env; UAS_PUBKEY=''
if [ "$($CMD)" != "UAS_PUBKEY not defined" ]; then
    echo "FAIL: Did not catch empty UAS_PUBKEY"
    exit 1
fi

echo "Checking for port 22 when using LoadBalancer..."
. ./test/test-env; HAL_IMAGE_SERVICE_PORT=22; export LB_TEST_MODE=true;
if [ "$($CMD)" != "LOADBALANCER Test: 30123" ]; then
    echo "FAIL: Did not catch UAS_PORT=30123 when using LoadBalancer"
    exit 1
fi

echo "Checking for port range too low..."
. ./test/test-env; HAL_IMAGE_SERVICE_PORT=1023
if [ "$($CMD)" != "UAS_PORT:1023 is not a valid user port" ]; then
    echo "FAIL: Did not catch UAS_PORT=1023"
    exit 1
fi

echo "Checking for port range too high..."
. ./test/test-env; HAL_IMAGE_SERVICE_PORT=65536
if [ "$($CMD)" != "UAS_PORT:65536 is not a valid user port" ]; then
    echo "FAIL: Did not catch UAS_PORT=65536"
    exit 1
fi

echo "Starting sshd..."
. ./test/test-env
$CMD &

echo "Checking that sshd started..."
for i in $(seq 1 10); do
    echo -n "."
    sleep 1; sshd_pid=$(pidof sshd)
    if [ ! -z "$sshd_pid" ]; then
        break
    fi
done
if [ -z $sshd_pid ]; then
    echo "FAIL: sshd not running"
    exit 1
fi

echo "Checking that hal has ssh access..."
UAS_SSH=/etc/uas/ssh
cp ./test/hal-id* $UAS_SSH
chown hal:9001 $UAS_SSH/hal-id*
chmod 0600 $UAS_SSH/hal-id_rsa
if [ "$(su hal -c 'ssh -q -oStrictHostKeyChecking=no -p $HAL_IMAGE_SERVICE_PORT -i /etc/uas/ssh/hal-id_rsa localhost whoami')" != "hal" ]; then
    echo "FAIL: ssh access for hal failed"
    exit 1
fi

echo "Checking that hal is allowed to add a second ssh public key..."
ssh-keygen -f $UAS_SSH/id_rsa -N ""
chown hal:9001 $UAS_SSH/id_rsa*
chmod 0600 $UAS_SSH/id_rsa*
su hal -c "cat $UAS_SSH/id_rsa.pub >> $UAS_SSH/authorized_keys"
if [ "$(su hal -c 'ssh -q -oStrictHostKeyChecking=no -p $HAL_IMAGE_SERVICE_PORT -i /etc/uas/ssh/id_rsa localhost whoami')" != "hal" ]; then
    echo "FAIL: ssh access for hal failed with second SSH key"
    exit 1
fi

echo "Check that the user has been added to groups"
for group in $UAS_GROUPS; do
    if ! id -nG hal | grep -qw $group; then
        echo "hal is not in group '$group'"
        exit 1
    fi
done

echo "Check that pbs.conf is in the correct location..."
if [ ! -f /etc/pbs.conf ]; then
    echo "FAIL: /etc/pbs.conf is missing"
    exit 1
fi

echo "Check that PBS_PUBLIC_HOST_NAME was removed from pbs.conf..."
if grep -q PBS_PUBLIC_HOST_NAME /etc/pbs.conf; then
    echo "FAIL: Found PBS_PUBLIC_HOST_NAME in /etc/pbs.conf"
    exit 1
fi

# SSH to the process and sleep long enough to go beyond the soft timeout.
# Once the SSH connection completes, check that sshd has gone away due to
# no active connections
echo "List of uai-ssh.sh and ssh processes..."
ps ax | egrep "uai|ssh" | grep -v "grep"

echo "Checking that the soft timeout works..."
su hal -c 'ssh -q -oStrictHostKeyChecking=no -p $HAL_IMAGE_SERVICE_PORT -i /etc/uas/ssh/id_rsa localhost sleep 15'
if [ "$?" -ne "0" ]; then
    echo "FAIL: soft timeout sleep command could not complete"
    exit 1
fi

# Wait to make sure uai-ssh.sh has had enough time to detect no actice connections
sleep 5
pidof sshd
if [ "$?" -ne "1" ]; then
    echo "FAIL: sshd is still running after a soft timeout..."
    exit 1
fi
echo "List of uai-ssh.sh and ssh processes after soft timeout..."
ps ax | egrep "uai|ssh" | grep -v "grep"

# To check the hard timeout, unset UAI_SOFT_TIMEOUT and use UAI_HARD_TIMEOUT
# Start a sleep process that goes beyond the hard timeout and make sure
# the command is terminated
echo "Starting sshd for hard timeout..."
. ./test/test-env; 
unset UAI_SOFT_TIMEOUT
export UAI_HARD_TIMEOUT=10
$CMD &

sleep 15
pidof sshd
if [ "$?" -ne "1" ]; then
    echo "FAIL: sshd is still running after a hard timeout..."
    exit 1
fi
echo "List of uai-ssh.sh and ssh processes after hard timeout..."
ps ax | egrep "uai|ssh" | grep -v "grep"

echo "All tests pass"
exit 0
