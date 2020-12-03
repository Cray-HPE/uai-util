# Copyright 2020 Hewlett Packard Enterprise Development LP

FROM dtr.dev.cray.com/baseos/sles15sp1:latest

COPY uai-ssh.sh /usr/bin/uai-ssh.sh
RUN zypper update -y && \
    zypper install -y openssh \
                      glibc-locale-base \
                      vim

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8

ENTRYPOINT /usr/bin/uai-ssh.sh
