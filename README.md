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
git clone https://github.com/QuintixLabs/Viresta.git
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

Skip the VM packages and services:

```sh
./install.sh --no-vm
```

Before installing, a menu lets you turn off Vicinae and `rename_wallpapers.py`.
Without Vicinae, whether by choice or because its build failed, you get the normal
KDE app launcher.

Your choices are saved in `~/.config/viresta/options`. The menu starts from them
next time, and `setup/setup.sh` follows them too.

After it finishes, reboot. SDDM will start and you can log into Plasma (Wayland).

If configs Viresta would replace already exist, the installer offers to back them
up first. `uninstall.sh` puts them back.

## Updating

```sh
./update.sh
```

It downloads the latest Viresta and stops without changing anything if this folder
has local edits.

| Part | On update |
|---|---|
| Viresta themes, color schemes, icons, cursors, `viresta-theme-sync`, services, pacman hooks, login screen and Firefox settings | Always replaced |
| Kitty, VSCodium, Vicinae and Fastfetch configs | What you changed stays, and everything else can update |
| Wallpaper, theme, panel, shortcuts and other KDE settings, profile picture, notification volume, menu choices | Never touched |

For the second group, Viresta keeps a copy of each config as it installed it, in
`~/.local/state/viresta/base`, and compares it with your file and the new version.
If you and Viresta changed the same setting, yours stays and the update tells you.
If a file cannot be merged safely, it stays as it is and the new version is saved
next to it as `<name>.viresta-new`.

Only packages newly added to the lists get installed, so an app you removed does not
come back. The update does not run a full system update unless a new package needs
one, and then it asks first. Rows added to `packages/vm.txt` are not installed by
updates.

An install from before `update.sh` existed has no copies to compare with, so the first
update keeps any config that differs and saves the `.viresta-new` next to it.

Running `install.sh` or `setup/setup.sh` again replaces your configs. Use `update.sh`
to keep them.

## Uninstalling

Log out first, because Plasma writes its configs back when it closes. Then press
Ctrl+Alt+F3, log in, and run:

```sh
./uninstall.sh --dry-run   # shows what would be removed
./uninstall.sh
```

This removes Viresta and resets KDE to its defaults. Config files Viresta installed
are deleted, **including any changes you made to them**, and it asks before starting.

- Your configs from before Viresta come back, if you made the backup.
- Vicinae and Panel Colorizer are removed. It asks whether to remove the main apps too.
- Dolphin, `paru` and anything you had before Viresta stay. KDE itself stays.
- Konsole is installed if Kitty is removed, so you still have a terminal.
- Your own files stay, including a profile picture or notification volume you chose.
- The themes Viresta removed are brought back by reinstalling their packages.

## What it does

The install moves through these phases in order:

1. Checks your system (Arch, x86_64, sudo, internet, VM detection).
2. Asks for your password **once** and adds a temporary `NOPASSWD` sudo rule so
   the install (including AUR builds) never asks again.
3. Updates the system and the keyring, downloading 5 packages at a time.
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

During the install, builds use one job per CPU core, limited to one per GB of RAM.
Your `makepkg.conf` is not changed, and a `MAKEFLAGS` set there takes priority.

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

The install uses a temporary pacman config for its download setting; your real
`/etc/pacman.conf` is never modified.

## KDE configuration

With Vicinae, the panel pins, left to right: **Vicinae**, **Dolphin**, **Firefox**.
**Meta** (the Super/Windows key, by itself) opens Vicinae, so the key and the icon
run the same command. Without it, Kickoff is on the panel and Meta opens that.

The Vicinae server starts at login, so the first press opens the window. If you
press Meta before the server is ready, it waits up to 5 seconds for it. To stop it
starting at login, run `systemctl --user disable vicinae.service`.

The panel does not float: `floating=0` and `floatingApplets=0` on the panel
containment (Disabled, not "Applets only").

Do not uninstall `plasma-browser-integration` (plasma-meta depends on it) and do
not remove `plasma-integration` (that is the Qt platform theme).

Notification sounds start at 75%. A volume you have already set is kept.

Power settings depend on the machine. It asks the system what it is, and only checks
for a battery if the system cannot say. VMs count as desktops. To choose yourself, run
`bash setup/setup.sh --power-profile=laptop` (or `desktop`), which also replaces your
configs. Updates do not change these settings.

| Setting | Desktop | Laptop, plugged in | Laptop, on battery | Laptop, low battery |
|---|---|---|---|---|
| Dim screen | Never | 10 min | 5 min | 2 min |
| Turn off screen | Never | 20 min | 10 min | 5 min |
| Turn off screen when locked | Never | 1 min | 1 min | 1 min |
| Sleep when inactive | Never | Never | 20 min | 10 min |
| Physical power button | Shut down | Logout screen | Logout screen | Logout screen |
| Lid closed | | Sleep | Sleep | Sleep |

With an external monitor connected, closing the lid does nothing. Laptops also lock
after 20 idle minutes and when waking from sleep. Desktops do not lock by themselves.

To put the dots in place again without reinstalling packages, replacing your configs:

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
| Fastfetch logo | `viresta-theme-sync` copies the theme's logo over `~/.config/fastfetch/logo.png` |
| OBS | `viresta-theme-sync` switches between Yami Acri and Yami Light in `~/.config/obs-studio/user.ini`. A theme you picked in OBS stays, and an open OBS shows the change after a restart |

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
Breeze Classic color schemes, the Oxygen icons and cursors, and the Air and Horos
wallpapers. A pacman hook,
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
├── update.sh            # updates Viresta and keeps your changes
├── uninstall.sh         # removes Viresta and leaves plain KDE
├── lib/                 # installs the system and packages
│   ├── load.sh          # loads what the three scripts all use
│   ├── update/
│   │   ├── download.sh  # git pull and its safety checks
│   │   └── install-pkgs.sh  # installs only new packages
│   ├── uninstall/
│   │   ├── files.sh     # deletes what Viresta installed
│   │   └── remove-pkgs.sh   # removes packages, brings back KDE's themes
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
│   ├── shared/
│   │   ├── variables.sh # paths and names shared by the parts
│   │   └── tracking.sh  # the list of installed files, backups, config merging
│   ├── desktop/
│   │   ├── plasma.sh    # KDE configs, panel, activity, Panel Colorizer
│   │   ├── themes.sh    # global themes, styles, theme switching, removed themes
│   │   ├── wallpapers.sh
│   │   ├── icons.sh     # icons and cursors
│   │   ├── sound.sh     # starting notification volume
│   │   └── power.sh     # laptop or desktop power settings
│   ├── login/
│   │   └── sddm.sh
│   └── apps/
│       ├── vicinae.sh
│       ├── firefox.sh
│       ├── fastfetch.sh
│       └── obs.sh
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

## Notes

- Package names follow current Arch repositories; verify after major Arch changes.
- Test in a VM before using on hardware you care about.
