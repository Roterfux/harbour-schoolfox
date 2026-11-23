Name:       harbour-schoolfox
Version:    0.2.0
Release:    1
Summary:    SchoolFox notifications for Sailfish OS
License:    BSD
URL:        https://github.com/Roterfux/harbour-schoolfox
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
BuildRequires: pkgconfig(sailfishapp) >= 1.0.2
BuildRequires: pkgconfig(Qt5Core)
BuildRequires: pkgconfig(Qt5Qml)
BuildRequires: pkgconfig(Qt5Quick)
BuildRequires: pkgconfig(Qt5Network)
BuildRequires: desktop-file-utils

%description
Unofficial native client that polls SchoolFox for new messages
and shows them as Sailfish OS notifications.

%prep
%autosetup

%build
%qmake5 %{name}.pro
%make_build

%install
%qmake5_install
desktop-file-install --delete-original \
    --dir %{buildroot}%{_datadir}/applications \
    %{buildroot}%{_datadir}/applications/*.desktop

%files
%{_bindir}/%{name}
%{_datadir}/%{name}/
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
