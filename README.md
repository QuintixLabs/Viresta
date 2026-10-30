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

After it finishes, reboot. SDDM will start and you can log into Plasma (Wayland).

## What it does

The install moves through these phases in order:

1. Preflight checks (Arch, x86_64, sudo, internet, VM detection).
2. Asks for your password **once** and adds a temporary `NOPASSWD` sudo rule so
   the install (including AUR builds) never asks again.
3. Updates the system and the keyring. Downloads are limited to one at a time
   so weak VMs do not stutter.
4. Installs the system/base tools.
5. Installs full KDE Plasma 6.
6. Installs everyday apps.
7. Builds `paru` and installs packages from `packages/aur.txt`.
8. Installs VM extras (repository tools + VM-only AUR packages).
9. Enables NetworkManager/SDDM, sets Plasma Wayland as the default session, and
   applies the Breeze Dark theme.

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

Logs:

- Install log: `/tmp/viresta-install.log`
- AUR build logs: `~/.local/state/viresta/`

## Layout

```
Viresta/
├── install.sh        # entrypoint: flow, steps, summary
├── lib/
│   ├── ui.sh         # colors, logging, prompts, cleanup registry
│   ├── system.sh     # checks, VM detection, sudo handling
│   └── packages.sh   # installs, paru/AUR, SDDM/session, dark theme
├── packages/
│   ├── base.txt
│   ├── kde.txt
│   ├── apps.txt
│   ├── aur.txt       # AUR packages for every system
│   └── vm.txt        # virt-type -> package (repo or AUR) -> service
└── .gitattributes    # forces LF line endings
```

## Roadmap

- Themes, wallpapers and dotfile deployment.
- GTK/Qt theming and custom Plasma widgets (QML).
- An uninstaller.

## Notes

- Package names follow current Arch repositories; verify after major Arch changes.
- Test in a VM before using on hardware you care about.
