# Releasing

This page is for maintainers. If you're contributing, you don't need any of this.

## How it works

There are two places the code lives:

| | Forgejo | GitHub |
|---|---|---|
| **For** | Testing | Users |
| **Commits** | Anything, messy is fine | Only finished work |
| **Main branch** | `dev` | `master` |
| **Tags** | Never | Created by publishing a release |

Forgejo must never have version tags. Without them, VMs cloned from it follow your latest commit instead of the newest release.

To set this up once, with `origin` pointing to Forgejo:

```sh
git remote add github https://github.com/QuintixLabs/Viresta.git
git switch -c dev
git push -u origin dev
```

## Rules

- Never run `git push --tags` or `git push --mirror` to Forgejo.
- Never push `dev` to GitHub. Only `master` goes there.
- Never make a version tag by hand. Publishing a release creates it.

## Testing your own changes

Commit on `dev` and push to Forgejo:

```sh
git switch dev
git commit -am "test thing"
git push origin dev
```

On the VM, clone it once:

```sh
git clone -b dev https://git.fr0st.xyz/fr0st/Viresta.git
cd Viresta
./install.sh
```

After that, get your new commits with:

```sh
./update.sh --dev
```

## Moving finished work to GitHub

When it works, turn it into one clean commit:

```sh
git switch master
git merge --squash dev
git commit -m "feat: add the thing"
git push github master
git push origin master
```

See [Committing](02_COMMITING.md) for how to write the message, because it appears as written in the release notes.

Then reset `dev` so it's ready for next time:

```sh
git switch dev
git reset --hard master
git push --force origin dev
```

## Testing a pull request

Copy it to Forgejo, using the pull request's number:

```sh
git fetch github pull/123/head:pr-123
git push origin pr-123
```

On the VM:

```sh
git clone -b pr-123 https://git.fr0st.xyz/fr0st/Viresta.git
cd Viresta
./install.sh
```

Nothing on GitHub changes. When you're done, delete the copy:

```sh
git branch -D pr-123
git push origin --delete pr-123
```

## Merging a pull request

Use **Squash and merge** on GitHub, so it lands as one clean commit. Then bring it to your PC and Forgejo:

```sh
git switch master
git pull github master
git push origin master
```

## Publishing a release

Make sure everything for the release is already on GitHub's `master`, because the draft is tied to the commit that changes the version.

1. Change the number in `VERSION`, like `1.1.0`, with no `v`.
2. Commit and push it to GitHub:

   ```sh
   git switch master
   git add VERSION
   git commit -m "chore: release 1.1.0"
   git push github master
   git push origin master
   ```

3. On GitHub, open **Releases**. The workflow has made a draft called `v1.1.0`, with the commits and contributors listed. Users get nothing yet.
4. Edit the notes. Remove anything that doesn't matter to users.
5. Click **Publish release**. This creates the tag, and users can now update.

Then check it on a clean VM cloned from GitHub:

```sh
git clone https://github.com/QuintixLabs/Viresta.git
cd Viresta
./install.sh
git describe --tags
```

The last command should print `v1.1.0`.

## Version numbers

- **Bug fixes:** `1.0.0` to `1.0.1`
- **New features:** `1.0.1` to `1.1.0`
- **Big changes that break things for users:** `1.1.0` to `2.0.0`

If the workflow fails, a draft isn't made and nothing reaches users. Fix it, then push a new number.
