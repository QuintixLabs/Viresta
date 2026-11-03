# Viresta

A small, opinionated installer that turns a minimal Arch Linux install into a
clean, working KDE Plasma 6 desktop on Wayland.

It is built to be re-run safely. Every package install uses `--needed`, so
running it twice does not reinstall everything.

## Requirements

- A minimal Arch Linux install (base system, bootloader, a regular user).
- `sudo` available to that user.
- Working internet connection.
- x86_64 architecture.
- Run it as your **normal user**, never as root.

## Usage

```sh
git clone <your-repo-url> Viresta
cd Viresta
chmod +x install.sh
./install.sh
```

Run it with `bash` if you prefer:

```sh
bash ./install.sh
```

Do **not** run it with `sh` (POSIX mode breaks bash features used here).

Preview what it would do without changing anything:

```sh
./install.sh --dry-run
```

Skip the slow parts when testing:

```sh
./install.sh --fast      # same as --no-aur --no-vm
./install.sh --no-aur    # skip paru and packages/aur.txt
./install.sh --no-vm     # skip VM packages and services
```

Anything in `packages/aur.txt` will be missing after `--no-aur` or `--fast`,
unless it is already installed. That includes Panel Colorizer and Vicinae.

Before installing, a menu lets you turn off Vicinae and `rename_wallpapers.py`.
You can skip the question for either one with `--no-vicinae` and
`--no-rename-wallpapers`. Without Vicinae, whether by choice, with `--no-aur` or
`--fast`, or because its build failed, you get the normal KDE app launcher.

Your choices are saved in `~/.config/viresta/options`. The menu starts from them
next time, and `setup/setup.sh` follows them too.

After it finishes, reboot. SDDM will start and you can log into Plasma (Wayland).

## What it does

The install moves through these phases in order:

1. Checks your system (Arch, x86_64, sudo, internet, VM detection).
2. Asks for your password **once** and adds a temporary `NOPASSWD` sudo rule so
   the install (including AUR builds) never asks again.
3. Updates the system and the keyring. Downloads are limited to one at a time
   so weak VMs do not stutter.
4. Installs the system/base tools.
5. Installs full KDE Plasma 6.
6. Installs everyday apps.
7. Builds `paru` and installs packages from `packages/aur.txt`.
8. Installs VM extras (repository tools + VM-only AUR packages).
9. Enables NetworkManager/SDDM, sets Plasma Wayland as the default session,
   and puts the dots in place with Viresta Dark as the starting theme.

## AUR packages

Edit `packages/aur.txt` to add apps installed on every system. One package per
line:

```ini
vscodium-bin
```

AUR builds run quietly. Their output goes to `~/.local/state/viresta/aur-<pkg>.log`
so the installer stays readable.

## VM packages

`packages/vm.txt` lists what each VM type gets, one package per row:

```ini
# virt-type   package                     service
vmware        open-vm-tools-clipway       vmtoolsd.service
kvm           qemu-guest-agent            qemu-guest-agent.service
```

The installer checks each package silently: if it exists in the official
repositories it is installed with `pacman`, otherwise it is built from the AUR
with `paru`. Add more rows for more packages on the same VM type.

## VM support

- **VMware:** `open-vm-tools-clipway` (Wayland clipboard fix) from the AUR, plus
  `vmtoolsd`.
- **QEMU/KVM:** `qemu-guest-agent`.
- **VirtualBox:** `virtualbox-guest-utils`.

## Safety

The passwordless sudo rule lives in `/etc/sudoers.d/viresta-temp` and is removed
automatically on exit, including Ctrl+C. If a run is killed hard (power loss or
`kill -9`), the next run detects the leftover rule and removes it. The rule is
validated with `visudo` before being installed.

Downloads are serialized using a temporary pacman config; your real
`/etc/pacman.conf` is never modified.

## KDE configuration

With Vicinae, the panel pins, left to right: **Vicinae**, **Dolphin**, **Firefox**.
**Meta** (the Super/Windows key, by itself) opens Vicinae, so the key and the icon
run the same command. Without it, Kickoff is on the panel and Meta opens that.

The panel does not float: `floating=0` and `floatingApplets=0` on the panel
containment (Disabled, not "Applets only").

Do not uninstall `plasma-browser-integration` (plasma-meta depends on it) and do
not remove `plasma-integration` (that is the Qt platform theme).

To put the dots in place again without reinstalling packages:

```sh
bash setup/setup.sh
```

## Themes

Viresta installs two global themes, **Viresta Dark** and **Viresta Light**, next
to Breeze Light and Breeze Dark. Apply one in System Settings > Colors & Themes >
Global Theme, or with:

```sh
plasma-apply-lookandfeel -a org.viresta.light.desktop
```

| Part | How it follows the theme |
|---|---|
| Colors, icons, cursor, window borders | The global theme |
| Panel | The Panel Colorizer preset uses system colors |
| Vicinae | `theme.light` and `theme.dark` in its settings. Light mode uses `YAMIS-Light`, a dark-icon copy of YAMIS made at install |
| Kitty | `light-theme.auto.conf` and `dark-theme.auto.conf` |
| VSCodium | `window.autoDetectColorScheme` |
| Desktop, lock and login wallpaper, login screen colors, profile picture | `viresta-theme-sync`, a user service that reads the wallpaper and color scheme from the theme's `contents/defaults`, and the picture from its `contents/profile.png` |

Breeze themes keep whatever wallpaper is currently set.

A profile picture you choose yourself, in System Settings or as `~/.face.icon`, is
never replaced, by a theme change or by reinstalling. To get the Viresta pictures
back, remove your picture in Settings or delete `~/.face.icon`, then switch theme.

Each Viresta theme has its own Plasma style and its own "Desktop and window
layout", generated from `config/themes/org.kde.plasma.desktop-layout.js`. Ticking
that option rebuilds the Viresta panel. Change the panel there as well as in the
tracked appletsrc.

Application style and window decoration stay on Breeze, which draws with the
Viresta colors.

Air, Breeze Twilight, Oxygen and Plastik are removed, along with the Oxygen and
Breeze Classic color schemes and the Oxygen icons and cursors. A pacman hook,
`/etc/pacman.d/hooks/viresta-remove-themes.hook`, removes them again after updates.
Fusion, MS Windows 9x and Union are only hidden from System Settings.

The login screen gets its cursor from the system default in
`/usr/share/icons/default/index.theme`, which Viresta sets to Bibata. A second
hook, `/etc/pacman.d/hooks/viresta-default-cursor.hook`, sets it again after updates.

## Logs

The installer only shows its steps and what went wrong. Add `--verbose` to see
everything on screen.

- What failed in the last install: `./install.sh --logs`
- Install log: `~/.local/state/viresta/install.log`
- AUR build logs: `~/.local/state/viresta/`

## Layout

```
Viresta/
├── install.sh           # entrypoint: flow, steps, summary
├── lib/                 # installs the system and packages
│   ├── ui/
│   │   ├── messages.sh  # colors, banner, messages, cleanup
│   │   ├── steps.sh     # steps, spinner, time
│   │   ├── menu.sh      # the menu for choosing what to install
│   │   └── failures.sh  # what install.sh --logs shows
│   ├── system/
│   │   ├── checks.sh    # checks the system can run the install
│   │   ├── sudo.sh      # password and temporary sudo rule
│   │   └── services.sh  # system services, runs setup/setup.sh
│   └── installers/
│       ├── pacman.sh    # pacman config and package list installs
│       ├── aur.sh       # paru and AUR packages
│       └── vm.sh        # VM detection, packages and services
├── setup/               # puts the dots in place
│   ├── setup.sh         # runs the parts below in order
│   ├── variables.sh     # paths and names shared by the parts
│   ├── desktop/
│   │   ├── plasma.sh    # KDE configs, panel, activity, Panel Colorizer
│   │   ├── themes.sh    # global themes, styles, theme switching, removed themes
│   │   ├── wallpapers.sh
│   │   └── icons.sh     # icons and cursors
│   ├── login/
│   │   └── sddm.sh
│   └── apps/
│       ├── vicinae.sh
│       └── firefox.sh
├── config/              # the files that get installed
├── packages/
│   ├── base.txt
│   ├── kde.txt
│   ├── apps.txt
│   ├── aur.txt          # AUR packages for every system
│   └── vm.txt           # virt-type -> package (repo or AUR) -> service
├── wallpapers/
└── .gitattributes       # forces LF line endings
```

## Roadmap

- An uninstaller.

## Notes

- Package names follow current Arch repositories; verify after major Arch changes.
- Test in a VM before using on hardware you care about.
