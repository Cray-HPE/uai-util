#!/bin/sh

echo "Installing uai-util rpm..."
zypper --no-gpg-checks --non-interactive addrepo \
       http://car.dev.cray.com/artifactory/shasta-premium/CLOUD/sle15_ncn/x86_64/dev/master/ \
       cloud
zypper --no-gpg-checks install -y /workspace/src/stash.us.cray.com/uas/uai-util/RPMS/cray-uai-util-*.rpm

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

echo "Starting sshd as user hal..."
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

echo "Check that sshd is running as hal..."
if [ "$(ps -o user= -p $sshd_pid)" != "hal" ]; then
    echo "FAIL: Could not find sshd running as hal"
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

echo "Check that Cray CLI was initialized..."
if [ ! -f ~hal/.config/cray/configurations/default ]; then
    echo "FAIL: Cray CLI was not initialized"
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

# End the uai-ssh.sh process so the test pipeline may continue
pkill --uid hal sshd

echo "All tests pass"
exit 0
