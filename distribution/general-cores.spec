# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileCopyrightText: 2019 CERN

%define project_name general-cores

Summary: General Cores Drivers
Name: dkms-%{project_name}
Version: %{?_build_version}
License: GPL-2.0
Release: 1%{?dist}
URL: https://www.ohwr.org/projects/general-cores/

BuildRequires: make, gcc, git
Requires: dkms

Source0: %{project_name}-%{version}.tar.gz
Source1: CHANGELOG

%description
This package installs all general-cores drivers

%prep
%autosetup -n %{project_name}-%{version}

%build

%install
make -C software PREFIX=%{buildroot}/ -f dkms.mk dkms_install

%post
dkms add -m %{project_name} -v %{version} --rpm_safe_upgrade
dkms build -m %{project_name} -v %{version} --rpm_safe_upgrade
dkms install -m %{project_name} -v %{version} --rpm_safe_upgrade

%preun
dkms remove -m %{project_name} -v %{version} --rpm_safe_upgrade --all ||:

%files
%license LICENSES/CC0-1.0.txt
%license LICENSES/GPL-2.0.txt
/usr/src/%{project_name}-%{version}/*


%changelog
%include %{SOURCE1}
