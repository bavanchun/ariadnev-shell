# Feodra spec for ADVS stable releases

%global debug_package %{nil}
%global version VERSION_PLACEHOLDER
%global pkg_summary AriadnevShell - Material 3 inspired shell for Wayland compositors

Name:           advs
Version:        %{version}
Release:        RELEASE_PLACEHOLDER%{?dist}
Summary:        %{pkg_summary}

License:        MIT
URL:            https://github.com/bavanchun/ariadnev-shell

Source0:        advs-qml.tar.gz

BuildRequires:  gzip
BuildRequires:  wget
BuildRequires:  systemd-rpm-macros

Requires:       (quickshell or quickshell-git)
Requires:       accountsservice
Requires:       advs-cli = %{version}-%{release}
Requires:       dgop

Recommends:     cava
Recommends:     danksearch
Recommends:     matugen
Recommends:     NetworkManager
Recommends:     qt6-qtmultimedia
Suggests:       cups-pk-helper
Suggests:       qt6ct

%description
AriadnevShell (ADVS) is a modern Wayland desktop shell built with Quickshell
and optimized for the niri and hyprland compositors. Features notifications,
app launcher, wallpaper customization, and fully customizable with plugins.

Includes auto-theming for GTK/Qt apps with matugen, 20+ customizable widgets,
process monitoring, notification center, clipboard history, dock, control center,
lock screen, and comprehensive plugin system.

%package -n advs-cli
Summary:        AriadnevShell CLI tool
License:        MIT
URL:            https://github.com/bavanchun/ariadnev-shell

%description -n advs-cli
Command-line interface for AriadnevShell configuration and management.
Provides native DBus bindings, NetworkManager integration, and system utilities.

%prep
%setup -q -c -n advs-qml

case "%{_arch}" in
  x86_64)
    ARCH_SUFFIX="amd64"
    ;;
  aarch64)
    ARCH_SUFFIX="arm64"
    ;;
  *)
    echo "Unsupported architecture: %{_arch}"
    exit 1
    ;;
esac

# Download advs-cli for target architecture
wget -O %{_builddir}/advs-cli.gz "https://github.com/bavanchun/ariadnev-shell/releases/latest/download/advs-distropkg-${ARCH_SUFFIX}.gz" || {
  echo "Failed to download advs-cli for architecture %{_arch}"
  exit 1
}
gunzip -c %{_builddir}/advs-cli.gz > %{_builddir}/advs-cli
chmod +x %{_builddir}/advs-cli

%build

%install
install -Dm755 %{_builddir}/advs-cli %{buildroot}%{_bindir}/advs

# Shell completions
install -d %{buildroot}%{_datadir}/bash-completion/completions
install -d %{buildroot}%{_datadir}/zsh/site-functions
install -d %{buildroot}%{_datadir}/fish/vendor_completions.d
%{_builddir}/advs-cli completion bash > %{buildroot}%{_datadir}/bash-completion/completions/advs || :
%{_builddir}/advs-cli completion zsh > %{buildroot}%{_datadir}/zsh/site-functions/_advs || :
%{_builddir}/advs-cli completion fish > %{buildroot}%{_datadir}/fish/vendor_completions.d/advs.fish || :

install -Dm644 %{_builddir}/advs-qml/assets/systemd/advs.service %{buildroot}%{_userunitdir}/advs.service

install -Dm644 %{_builddir}/advs-qml/assets/advs-open.desktop %{buildroot}%{_datadir}/applications/advs-open.desktop
install -Dm644 %{_builddir}/advs-qml/assets/dev.vchun.ariadnev.desktop %{buildroot}%{_datadir}/applications/dev.vchun.ariadnev.desktop
install -Dm644 %{_builddir}/advs-qml/assets/dev.vchun.ariadnev.notepad.desktop %{buildroot}%{_datadir}/applications/dev.vchun.ariadnev.notepad.desktop
install -Dm644 %{_builddir}/advs-qml/assets/advlogo.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/advlogo.svg

install -dm755 %{buildroot}%{_datadir}/quickshell/ariadnev
cp -r %{_builddir}/advs-qml/* %{buildroot}%{_datadir}/quickshell/ariadnev/

rm -rf %{buildroot}%{_datadir}/quickshell/ariadnev/.git*
rm -f %{buildroot}%{_datadir}/quickshell/ariadnev/.gitignore
rm -rf %{buildroot}%{_datadir}/quickshell/ariadnev/.github
rm -rf %{buildroot}%{_datadir}/quickshell/ariadnev/distro

echo "%{version}" > %{buildroot}%{_datadir}/quickshell/ariadnev/VERSION

%posttrans
# Signal running ADVS instances to reload
pkill -USR1 -x advs >/dev/null 2>&1 || :

%files
%license LICENSE
%doc README.md CONTRIBUTING.md
%{_datadir}/quickshell/ariadnev/
%{_userunitdir}/advs.service
%{_datadir}/applications/advs-open.desktop
%{_datadir}/applications/dev.vchun.ariadnev.desktop
%{_datadir}/applications/dev.vchun.ariadnev.notepad.desktop
%{_datadir}/icons/hicolor/scalable/apps/advlogo.svg

%files -n advs-cli
%{_bindir}/advs
%{_datadir}/bash-completion/completions/advs
%{_datadir}/zsh/site-functions/_advs
%{_datadir}/fish/vendor_completions.d/advs.fish

%changelog
* CHANGELOG_DATE_PLACEHOLDER Avenge Media <contact@avengemedia.com> - VERSION_PLACEHOLDER-RELEASE_PLACEHOLDER
- Stable release VERSION_PLACEHOLDER
- Built from GitHub release
