# Spec for ADVS for OpenSUSE/OBS

%global debug_package %{nil}

Name:           advs
Version:        1.2.3
Release:        1%{?dist}
Summary:        AriadnevShell - Material 3 inspired shell for Wayland compositors

License:        MIT
URL:            https://github.com/bavanchun/ariadnev-shell
Source0:        advs-source.tar.gz
Source1:        advs-distropkg-amd64.gz
Source2:        advs-distropkg-arm64.gz

BuildRequires:  gzip
BuildRequires:  systemd-rpm-macros

# Core requirements
Requires:       (quickshell or quickshell-git)
Requires:       accountsservice
Requires:       dgop

# Core utilities (Highly recommended for ADVS functionality)
Recommends:     cava
Recommends:     danksearch
Recommends:     matugen
Recommends:     NetworkManager
Recommends:     qt6-multimedia-imports
Suggests:       cups-pk-helper
Suggests:       qt6ct

%description
AriadnevShell (ADVS) is a modern Wayland desktop shell built with Quickshell
and optimized for niri, Hyprland, Sway, and other wlroots compositors. Features
notifications, app launcher, wallpaper customization, and plugin system.

Includes auto-theming for GTK/Qt apps with matugen, 20+ customizable widgets,
process monitoring, notification center, clipboard history, dock, control center,
lock screen, and comprehensive plugin system.

%prep
%setup -q -n AriadnevShell-%{version}

%ifarch x86_64
gunzip -c %{SOURCE1} > advs
%endif
%ifarch aarch64
gunzip -c %{SOURCE2} > advs
%endif
chmod +x advs

%build

%install
install -Dm755 advs %{buildroot}%{_bindir}/advs

install -d %{buildroot}%{_datadir}/bash-completion/completions
install -d %{buildroot}%{_datadir}/zsh/site-functions
install -d %{buildroot}%{_datadir}/fish/vendor_completions.d
./advs completion bash > %{buildroot}%{_datadir}/bash-completion/completions/advs || :
./advs completion zsh > %{buildroot}%{_datadir}/zsh/site-functions/_advs || :
./advs completion fish > %{buildroot}%{_datadir}/fish/vendor_completions.d/advs.fish || :

install -Dm644 assets/systemd/advs.service %{buildroot}%{_userunitdir}/advs.service

install -Dm644 assets/advs-open.desktop %{buildroot}%{_datadir}/applications/advs-open.desktop
install -Dm644 assets/dev.vchun.ariadnev.desktop %{buildroot}%{_datadir}/applications/dev.vchun.ariadnev.desktop
install -Dm644 assets/dev.vchun.ariadnev.notepad.desktop %{buildroot}%{_datadir}/applications/dev.vchun.ariadnev.notepad.desktop
install -Dm644 assets/advlogo.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/advlogo.svg

install -dm755 %{buildroot}%{_datadir}/quickshell/ariadnev
cp -r quickshell/* %{buildroot}%{_datadir}/quickshell/ariadnev/

rm -rf %{buildroot}%{_datadir}/quickshell/ariadnev/.git*
rm -f %{buildroot}%{_datadir}/quickshell/ariadnev/.gitignore
rm -rf %{buildroot}%{_datadir}/quickshell/ariadnev/.github
rm -rf %{buildroot}%{_datadir}/quickshell/ariadnev/distro
rm -rf %{buildroot}%{_datadir}/quickshell/ariadnev/core

echo "%{version}" > %{buildroot}%{_datadir}/quickshell/ariadnev/VERSION

%posttrans
# Signal running ADVS instances to reload
pkill -USR1 -x advs >/dev/null 2>&1 || :

%files
%license LICENSE
%doc CONTRIBUTING.md
%doc quickshell/README.md
%{_bindir}/advs
%dir %{_datadir}/fish
%dir %{_datadir}/fish/vendor_completions.d
%{_datadir}/fish/vendor_completions.d/advs.fish
%dir %{_datadir}/zsh
%dir %{_datadir}/zsh/site-functions
%{_datadir}/zsh/site-functions/_advs
%{_datadir}/bash-completion/completions/advs
%dir %{_datadir}/quickshell
%{_datadir}/quickshell/ariadnev/
%{_userunitdir}/advs.service
%{_datadir}/applications/advs-open.desktop
%{_datadir}/applications/dev.vchun.ariadnev.desktop
%{_datadir}/applications/dev.vchun.ariadnev.notepad.desktop
%dir %{_datadir}/icons/hicolor
%dir %{_datadir}/icons/hicolor/scalable
%dir %{_datadir}/icons/hicolor/scalable/apps
%{_datadir}/icons/hicolor/scalable/apps/advlogo.svg

%changelog
* Mon Dec 16 2025 Avenge Media <maintainer@avengemedia.com> - 1.0.3-1
- Update to stable v1.0.3 release

* Fri Dec 12 2025 Avenge Media <maintainer@avengemedia.com> - 1.0.2-1
- Update to stable v1.0.2 release
- Bug fixes and improvements

* Fri Nov 22 2025 Avenge Media <maintainer@avengemedia.com> - 0.6.2-1
- Stable release build with pre-built binaries
- Multi-arch support (x86_64, aarch64)
