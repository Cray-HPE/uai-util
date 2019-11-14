#
# RPM spec file for uai-util
# Copyright 2019 Cray Inc. All Rights Reserved.
#
%define packagename uai-util
%define cmdname uai-ssh.sh

Requires: craycli

Name: cray-%{packagename}
License: Cray Software License Agreement
Summary: %{packagename}
Version: %(cat .version)
Release: %(echo ${BUILD_METADATA})
Source: %{name}-%{version}.tar.bz2
Vendor: Cray Inc.
Group: Productivity/Clustering/Computing

%description
This package provides the utilities and dependencies needed to run 
a UAI with cray-uas-mgr

%files
%dir %{_bindir}
%{_bindir}/%{cmdname}

%prep
%setup -q

%build

%install
%{__mkdir_p} %{buildroot}%{_bindir}

%{__install} -m 0755 %{cmdname} %{buildroot}%{_bindir}/%{cmdname}

%changelog
