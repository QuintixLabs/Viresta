# Releasing

This page is for maintainers. If you're contributing, you don't need any of this.

## How it works

| Branch | For | Commits |
|---|---|---|
| `dev` | Testing | Anything, messy is fine |
| `master` | Users | Only finished work |

Users only get what you publish as a release. Pushing to `dev` or `master` doesn't reach them.

Never make a version tag by hand. Publishing a release creates it, and `update.sh` follows tags.

`dev` is public, so don't commit anything private to it.

## Testing on dev

Commit your changes and push them:

```sh
git switch dev
git add -A
git commit -m "test thing"
git push origin dev
```

On a VM, clone `dev` once and install it:

```sh
git clone -b dev https://github.com/QuintixLabs/Viresta.git
cd Viresta
./install.sh
```

After that, get your new commits with:

```sh
./update.sh --dev
```

## Moving finished work to master

When it works, turn it into one clean commit:

```sh
git switch master
git merge --squash dev
git commit -m "feat: add the thing"
git push origin master
```

See [Committing](/docs/contents/02_COMMITING.md) for how to write the message, because it appears as written in the release notes.

## Testing a pull request

On a VM, using the pull request's number:

```sh
git clone https://github.com/QuintixLabs/Viresta.git
cd Viresta
git fetch origin pull/123/head:pr-123
git switch pr-123
./install.sh
```

## Merging a pull request

Use **Squash and merge** on GitHub, so it lands as one clean commit. Then bring it to your PC:

```sh
git switch master
git pull origin master
```

## Publishing a release

Test everything on `dev` first, and make sure it's on `master`, because the draft is tied to the commit that changes the version.

1. Change the number in `VERSION`, like `1.1.0`, with no `v`.
2. Commit and push it:

   ```sh
   git switch master
   git add VERSION
   git commit -m "chore: release 1.1.0"
   git push origin master
   ```

3. On GitHub, open **Releases**. The workflow runs ShellCheck and the tests first, then makes a draft called `v1.1.0`, with the commits and contributors listed. This takes a few minutes. Users get nothing yet.
4. Edit the notes. Remove anything that doesn't matter to users.
5. Click **Publish release**. This creates the tag, and users can now update.

Publishing also resets `dev` to `master` by itself, so it's ready for next time. Anything that was only being tested on `dev`, like a pull request that wasn't merged, is dropped from it. Put it on `dev` again to keep testing.

Bring your own copy of `dev` along:

```sh
git switch dev
git fetch origin
git reset --hard origin/dev
```

VMs on `dev` need the same two last lines if the reset dropped something, since `./update.sh --dev` can't update them normally then. You can also go back to a clean snapshot and clone again.

Then check it on a clean VM:

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

If ShellCheck, the tests or the workflow fail, a draft isn't made and nothing reaches users. **Actions** shows what failed. Fix it and push the fix to `master`, then open **Actions**, then **Draft release**, and click **Run workflow** to try again with the same number.

Before moving `dev` to `master`, you can also test it by hand: open **Actions**, then **Tests**, then **Run workflow**, and pick `dev`.
