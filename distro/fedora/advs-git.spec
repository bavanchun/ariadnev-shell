# Spec for ADVS - uses rpkg macros for git builds

%global debug_package %{nil}
%global version {{{
set -e
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
    git fetch --unshallow --quiet
fi
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
    echo "clone is still shallow; refusing a truncated commit count" >&2
    exit 1
fi
printf '0.0.git.%s.%s\n' \
    "$(git rev-list --count HEAD)" \
    "$(git rev-parse --short=8 HEAD)"
}}}
%global pkg_summary AriadnevShell - Material 3 inspired shell for Wayland compositors
%global go_toolchain_version 1.26.5

Name:           advs
Epoch:          2
Version:        %{version}
Release:        1%{?dist}
Summary:        %{pkg_summary}

License:        MIT
URL:            https://github.com/bavanchun/ariadnev-shell
VCS:            {{{ git_repo_vcs }}}
Source0:        {{{ git_repo_pack }}}
Source1:        https://go.dev/dl/go%{go_toolchain_version}.linux-amd64.tar.gz
Source2:        https://go.dev/dl/go%{go_toolchain_version}.linux-arm64.tar.gz
# git_repo_pack archives skip submodule content, so pack ariadnev-qml-common separately
Source3:        {{{ git_pack path=$GIT_ROOT/ariadnev-qml-common dir_name=ariadnev-qml-common source_name=ariadnev-qml-common.tar.gz }}}

BuildRequires:  git-core
BuildRequires:  gzip
BuildRequires:  make
BuildRequires:  systemd-rpm-macros

# Core requirements
Requires:       (quickshell-git or quickshell)
Requires:       accountsservice
Requires:       advs-cli = %{epoch}:%{version}-%{release}

# Core utilities (Recommended for ADVS functionality)
Recommends:     cava
Recommends:     danksearch
Recommends:     matugen
Recommends:     quickshell-git

# Recommended system packages
Recommends:     NetworkManager
Recommends:     qt6-qtmultimedia
Suggests:       cups-pk-helper
Suggests:       qt6ct

%description
AriadnevShell (ADVS) is a modern Wayland desktop shell built with Quickshell
and optimized for the niri, hyprland, sway, and dwl (MangoWC) compositors. Features notifications,
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
{{{ git_repo_setup_macro }}}
rm -rf ariadnev-qml-common
tar -xzf %{SOURCE3}
test -e quickshell/AdvCommon/Widgets/AdvIcon.qml || { echo "AdvCommon missing after submodule unpack"; exit 1; }

%build
# Build ADVS CLI from source (core/subdirectory)
VERSION="%{version}"
COMMIT=$(echo "%{version}" | grep -oP '[a-f0-9]{7,}' | head -n1 || echo "unknown")

# Use pinned bundled Go toolchain (deterministic across chroots)
case "%{_arch}" in
  x86_64)
    GO_TARBALL="%{_sourcedir}/go%{go_toolchain_version}.linux-amd64.tar.gz"
    ;;
  aarch64)
    GO_TARBALL="%{_sourcedir}/go%{go_toolchain_version}.linux-arm64.tar.gz"
    ;;
  *)
    echo "Unsupported architecture for bundled Go: %{_arch}"
    exit 1
    ;;
esac

rm -rf .go
tar -xzf "$GO_TARBALL"
mv go .go
export GOROOT="$PWD/.go"
export PATH="$GOROOT/bin:$PATH"
export GOTOOLCHAIN=local
go version

cd core
make dist VERSION="$VERSION" COMMIT="$COMMIT"

%install
# Install advs-cli binary (built from source)
case "%{_arch}" in
  x86_64)
    ADVS_BINARY="advs-linux-amd64"
    ;;
  aarch64)
    ADVS_BINARY="advs-linux-arm64"
    ;;
  *)
    echo "Unsupported architecture: %{_arch}"
    exit 1
    ;;
esac

install -Dm755 core/bin/${ADVS_BINARY} %{buildroot}%{_bindir}/advs

# Shell completions
install -d %{buildroot}%{_datadir}/bash-completion/completions
install -d %{buildroot}%{_datadir}/zsh/site-functions
install -d %{buildroot}%{_datadir}/fish/vendor_completions.d
core/bin/${ADVS_BINARY} completion bash > %{buildroot}%{_datadir}/bash-completion/completions/advs || :
core/bin/${ADVS_BINARY} completion zsh > %{buildroot}%{_datadir}/zsh/site-functions/_advs || :
core/bin/${ADVS_BINARY} completion fish > %{buildroot}%{_datadir}/fish/vendor_completions.d/advs.fish || :

# Install systemd user service
install -Dm644 assets/systemd/advs.service %{buildroot}%{_userunitdir}/advs.service

install -Dm644 assets/advs-open.desktop %{buildroot}%{_datadir}/applications/advs-open.desktop
install -Dm644 assets/dev.vchun.ariadnev.desktop %{buildroot}%{_datadir}/applications/dev.vchun.ariadnev.desktop
install -Dm644 assets/dev.vchun.ariadnev.notepad.desktop %{buildroot}%{_datadir}/applications/dev.vchun.ariadnev.notepad.desktop
install -Dm644 assets/advlogo.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/advlogo.svg

%posttrans
# Signal running ADVS instances to reload
pkill -USR1 -x advs >/dev/null 2>&1 || :

%files
%license LICENSE
%doc CONTRIBUTING.md
%doc quickshell/README.md
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
{{{ git_repo_changelog }}}
