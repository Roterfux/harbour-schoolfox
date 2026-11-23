Name:       harbour-schoolfox
Version:    0.4.2
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
BuildRequires: pkgconfig(Qt5DBus)
BuildRequires: pkgconfig(keepalive)
BuildRequires: pkgconfig(nemonotifications-qt5)
BuildRequires: qt5-qttools-linguist
BuildRequires: desktop-file-utils

%description
Unofficial native client that checks SchoolFox for new messages
and shows them as Sailfish OS notifications, also when the app is closed.

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
mkdir -p %{buildroot}/usr/lib/systemd/user/post-user-session.target.wants
ln -s ../harbour-schoolfox-daemon.service \
    %{buildroot}/usr/lib/systemd/user/post-user-session.target.wants/harbour-schoolfox-daemon.service

%post
systemctl-user daemon-reload || :
systemctl-user restart harbour-schoolfox-daemon.service || :

%preun
if [ $1 -eq 0 ]; then
    systemctl-user stop harbour-schoolfox-daemon.service || :
fi

%postun
systemctl-user daemon-reload || :

%files
%{_bindir}/%{name}
%{_datadir}/%{name}/
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%{_datadir}/dbus-1/services/org.roterfux.harbour-schoolfox.service
/usr/lib/systemd/user/harbour-schoolfox-daemon.service
/usr/lib/systemd/user/post-user-session.target.wants/harbour-schoolfox-daemon.service
