# Tests

These check that Viresta keeps working when something changes. They run on a fake system in a throwaway folder, so nothing on your PC is installed or changed.

They don't replace testing on a VM. They can't tell if the desktop looks right or if a real graphics card works. They catch the "I changed one thing and it broke another" kind of problem.

## Running them

You need Linux or WSL, with Bash, Git, `jq` and `script` (part of `util-linux`). Fish is optional, and its tests are skipped without it.

From the Viresta folder:

```sh
bash tests/run.sh
```

To run only some of them, name a folder or a file:

```sh
bash tests/run.sh updates
bash tests/run.sh lifecycle/uninstall.sh
```

All the tests run at the same time, and each one shows how long it took. The `lifecycle` tests run the real scripts and wait for them like a person typing, so they take up to about a minute. The rest take a few seconds.

On GitHub, they run on every pull request and before every release draft. A version that fails them doesn't become a draft. To test a branch like `dev` by hand, open **Actions**, then **Tests**, then **Run workflow**.

## What's where

The folders match the code they test:

| Folder | What it checks |
|---|---|
| `lifecycle` | `install.sh`, `update.sh` and `uninstall.sh` from start to finish |
| `updates` | Releases, the update alerts and `update --check` |
| `command` | The `viresta` command and its Tab completion |
| `drivers` | Finding the hardware and installing its drivers |
| `installers` | Changes to pacman's settings, like turning on multilib |
| `shell` | The Bash and Fish setup |
| `ui` | The banner, the install menu, saved options and help screens |

`shared/helpers.sh` has what every test uses, like the fake system and the `is` and `has` checks. Nothing in `shared` is run as a test.

## Adding a test

Each check is one line: a name, what came out, and what should have:

```sh
is "the version is shown" "$(viresta --version)" "Viresta 1.1.0"
has "it says why" "local edits" "$OUT"
missing "the file is gone" "$HOME/.blerc"
```

Start a new file from one next to it, and end it with `finish`. When you change how something works on purpose, update the test for it in the same commit.
