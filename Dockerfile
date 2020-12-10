# Copyright 2020 Hewlett Packard Enterprise Development LP

FROM dtr.dev.cray.com/baseos/sles15sp1:latest

ARG SLURM_REPO=http://car.dev.cray.com/artifactory/wlm-slurm/RM/sle15_sp1_cn/x86_64/release/shasta-1.4/
ARG PBS_REPO=http://car.dev.cray.com/artifactory/wlm-pbs/RM/sle15_sp1_cn/x86_64/release/shasta-1.4/

COPY uai-ssh.sh /usr/bin/uai-ssh.sh

RUN zypper addrepo -G ${SLURM_REPO} slurm && \
    zypper addrepo -G ${PBS_REPO} pbs && \
    zypper update -y && \
    zypper install -y curl \
                      glibc-locale-base \
                      gzip \
                      iputils \
                      jq \
                      less \
                      openssh \
                      pbspro-client \
                      rsync \
                      slurm \
                      tar \
                      vim \
                      wget \
                      which

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8

ENTRYPOINT /usr/bin/uai-ssh.sh
