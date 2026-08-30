# Void Linux packaging

XBPS templates for AriadnevShell on [Void Linux](https://voidlinux.org).

| Package | Source repo | Template |
| --- | --- | --- |
| `advs` | AriadnevShell | [`srcpkgs/advs/template`](srcpkgs/advs/template) |
| `dgop` | bavanchun/dgop | maintained in the **ariadnev** repo (`distro/void/srcpkgs/dgop`) |
| `danksearch` | AvengeMedia/danksearch | maintained in the **ariadnev** repo (`distro/void/srcpkgs/danksearch`) |

All build from source.

## Distribution

This is a ADVS maintained repo for VoidLinux until these packages are officially merged upstream in the Void Linux repositories, you can install them from our self-hosted custom XBPS repositories served via GitHub Pages.

### Using the Self-Hosted Repositories

We serve both stable release and development packages from Cloudflare R2 at
`void.ariadnev.vchun.dev`.

> **Repository migration:** the former GitHub Pages repositories will be
> frozen for 14 days at cutover. Their retirement date will be announced when
> the snapshots are frozen. Replace any existing `bavanchun.github.io`
> entries with the URLs below.

#### 1. Add Repository Configurations

Create configuration files in `/etc/xbps.d/` pointing to our repositories (needed for both stable and git/nightly variants):

```sh
echo "repository=https://void.ariadnev.vchun.dev/advs/current" | sudo tee /etc/xbps.d/advs.conf
echo "repository=https://void.ariadnev.vchun.dev/ariadnev/current" | sudo tee /etc/xbps.d/ariadnev.conf
```

#### 2. Install ADVS

Synchronize repositories and install the package:

* For the **stable** variant:

    ```sh
    sudo xbps-install -S advs
    ```

* For the **git/nightly** variant (this will conflict with and replace the stable package):

    ```sh
    sudo xbps-install -S advs-git
    ```

*Note: On the first sync, `xbps-install` will output our signing key fingerprint and ask you to type `y` to trust and import it. Verify that the key matches our official signing fingerprint.*

The templates here are the source of truth: copy each into a void-packages
checkout at `srcpkgs/<pkg>/template` to build or submit it.

## Dependencies

Installing `advs` automatically pulls in `quickshell`, `accountsservice`, `dgop`,
`matugen` (which drives the Material You theming), `dbus`, `elogind`, and
`mesa-dri` (GL drivers, required for compositors to render).
The rest are optional, install whichever features you want:

| Package | Enables |
| --- | --- |
| `danksearch` | launcher / filesystem search |
| `cava` | audio visualiser widget |
| `qt6-multimedia` | system sound feedback |
| `qt6ct` | Qt app theming |
| `power-profiles-daemon` | power profile control |
| `cups-pk-helper` | printer management |
| `NetworkManager` | network control |
| `i2c-tools` | external-monitor brightness (DDC) |
| `niri` / `hyprland` / `sway` | a Wayland compositor (niri is the team's choice) |

## Building & testing

Inside a `void-packages` checkout (symlink or copy these `srcpkgs/<pkg>` dirs in):

```sh
# build the dependency packages first (advs requires dgop)
./xbps-src pkg dgop
./xbps-src pkg danksearch
./xbps-src pkg advs

# lint (xlint ships in the xtools package)
xlint srcpkgs/advs/template

# install the built packages
sudo xbps-install --repository=hostdir/binpkgs advs dgop
```

`advs` requires Go ≥ 1.26 in the build environment (per `core/go.mod`).

## Running the shell

ADVS is a user-level Wayland shell with **no system service** — start it from your
compositor's autostart, e.g. niri:

```kdl
spawn-at-startup "advs" "run"
```

or Hyprland: `exec-once = advs run`.

From a TTY on Void without a greeter, start your compositor through a D-Bus
session:

```sh
dbus-run-session niri
dbus-run-session Hyprland
dbus-run-session mango
```

The `mangowc` package provides the `mango` command.

For power menu actions to work on runit systems, make sure the system D-Bus and
elogind services are enabled:

```sh
sudo ln -sf /etc/sv/dbus /var/service/dbus
sudo ln -sf /etc/sv/elogind /var/service/elogind
```

The `advinstall` Void path enables both services after installing packages.
