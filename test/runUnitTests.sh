#!/bin/sh

echo "Run uas-img packaging tests..."

# Make sure there are no limits inherited from the base image
# which broke the ability to su $USER
echo "Checking for limits in /etc/security/limits.conf..."
if [ $(grep -v "#" /etc/security/limits.conf) ]; then
    echo "Limit found in /etc/security/limits.conf"
    exit 1
fi

# Check that packages.sles15 is sorted
echo "Checking that packages.sles15 is alphabetized..."
sort --check packages.sles15
if [ $? -ne 0 ]; then
    echo "FAIL: package.sles15 is not alphabetized"
    exit 1
fi

# When we support more distros we will need to resurrect the distro
# specific lists here
RPM_LIST=$(cat ../packages.sles15)
for rpm in $RPM_LIST; do
    echo "Checking for package $rpm..."
    rpm -q $rpm > /dev/null
    if [ $? -ne 0 ]; then
        echo "FAIL: Could not find $rpm"
        exit 1
    fi
done

# Check that commands are in PATH
CMD_LIST="kubectl cray"
for cmd in $CMD_LIST; do
    echo "Checking for command $cmd..."
    which $cmd > /dev/null
    if [ $? -ne 0 ]; then
        echo "FAIL: Could not find $cmd"
        exit 1
    fi
done

# Check that there is no password for root
echo "Check that there is no password for root..."
if [ "$(passwd -S root | awk '{print $2}')" != "NP" ]; then
    echo "FAIL: status of root password is not 'NP'"
    exit 1
fi

# Stage a dummy pbs.conf to make sure it moves
mkdir /etc/pbs
echo "PBS_PUBLIC_HOST_NAME=ttl" > /etc/pbs/pbs.conf

echo "Run uas-img entrypoint.sh tests..."
CMD=/app/entrypoint.sh

echo "Checking for unset variable UAS_PASSWD..."
. /app/test-env; UAS_PASSWD=''
if [ "$($CMD)" != "UAS_PASSWD not defined" ]; then
    echo "FAIL: Did not catch empty UAS_PASSWD"
    exit 1
fi

echo "Checking for unset variable UAS_PUBKEY..."
. /app/test-env; UAS_PUBKEY=''
if [ "$($CMD)" != "UAS_PUBKEY not defined" ]; then
    echo "FAIL: Did not catch empty UAS_PUBKEY"
    exit 1
fi

echo "Checking for port range too low..."
. /app/test-env; HAL_IMAGE_SERVICE_PORT=1023
if [ "$($CMD)" != "UAS_PORT:1023 is not a valid user port" ]; then
    echo "FAIL: Did not catch UAS_PORT=1023"
    exit 1
fi

echo "Checking for port range too high..."
. /app/test-env; HAL_IMAGE_SERVICE_PORT=65536
if [ "$($CMD)" != "UAS_PORT:65536 is not a valid user port" ]; then
    echo "FAIL: Did not catch UAS_PORT=65536"
    exit 1
fi

echo "Starting sshd as user hal..."
. /app/test-env
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
cp /app/hal-id* $UAS_SSH
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

echo "Check that X11 is configured..."
Xvfb :100 2> /dev/null &
sleep 2
export DISPLAY=:100
su hal -c -p 'ssh -q -X -oStrictHostKeyChecking=no -p $HAL_IMAGE_SERVICE_PORT -i /etc/uas/ssh/hal-id_rsa localhost xset -q'
if [ "$?" -ne "0" ]; then
    echo "FAIL: X11 not configured"
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

echo "All tests pass"
exit 0
