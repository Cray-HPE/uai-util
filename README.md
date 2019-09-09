# uan-img

## Overview
uan-img creates a container that a user may ssh to. The Dockerfile
will copy entrypoint.sh to /app/entrypoint.sh and install sshd.

/app/entrypoint.sh requires UAS_PASSWD and UAS_PUBKEY be set to
the users passwd entry and ssh public key.

## Requirements
The base container must include sshd and ssh-keygen. Additionally,
UAS_PASSWD and UAS_PUBKEY must be set as environment variables
inside the container.

## Build uan-img
From this directory run the docker build command.
```
docker build -t uan-img:latest .
```

## Usage
Create a file with the appropriate environment variables set.
```
echo "UAS_PASSWD=$(getent passwd $USER)" | sed 's/ /\\ /g' >> envfile
echo "UAS_PUBKEY=$(cat ~/.ssh/id_rsa.pub)" | sed 's/ /\\ /g' >> envfile
echo "API_GATEWAY_SERVICE_HOST=<sms_url>" >> envfile
```

Run the container and pass in the environment variable file.
```
docker run -p 30123:30123 --env-file envs uan-img:latest
```

ssh should now work to the container by using the correct port number
and along with the user's ssh key.
```
ssh -o StrictHostKeyChecking=no -p 30123 -i ~/.ssh/id_rsa localhost
```
