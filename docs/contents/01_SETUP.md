# Setup

Viresta changes your whole desktop, so test it in a virtual machine, not on your main PC.

It's recommended to take a snapshot of your VM before you test. An update leaves alone anything that belongs to the user, like the KDE configs and wallpaper, so to test changes to those, go back to the snapshot and run `./install.sh` again. It's also good to test this way once before opening a pull request, since that's what a new user gets.

## What you need

- A virtual machine with a minimal install of a [supported distro](../../README.md#-supported-distros) and no desktop
- A regular user with sudo
- Git and an internet connection

## Get the code

Fork Viresta on GitHub, then on the VM clone your fork and make a branch for your change:

```sh
git clone https://github.com/YOUR_NAME/Viresta.git
cd Viresta
git switch -c my-change
```

Stay on your branch. On `master`, `./install.sh` moves to the newest release instead of installing your work.

## Test your change

Install it and reboot:

```sh
./install.sh
sudo reboot
```

If you make your changes somewhere else, like your main PC, commit and push them to your branch. Then get them on the VM with:

```sh
./update.sh --dev
```

`--dev` is needed here. Without it, `./update.sh` only looks for new releases.

`./update.sh` stops if the Viresta folder has edits that aren't committed. If you edit on the VM, commit them first.

## If something goes wrong

To see everything on screen, add `--verbose`:

```sh
./install.sh --verbose
```

To list what failed in the last install:

```sh
./install.sh --logs
```

The full logs are in `~/.local/state/viresta/`. Include the useful parts when you open an issue.

## Testing uninstall

Plasma writes its configs back when it closes, so `./uninstall.sh` won't run while Plasma is open. Log out, press `Ctrl+Alt+F3`, log in, then run it from the Viresta folder.

---

#### [02. Commiting ➔](/docs/contents/02_COMMITING.md)
