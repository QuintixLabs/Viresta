# Committing

Try to stick to Conventional Commits:

- `type: short summary`
- or `type(scope): short summary`

#### Common types:

- `feat:` → new features
- `fix:` → bug fixes
- `docs:` → documentation changes
- `refactor:` → internal cleanup (no behavior change)
- `chore:` → for small project updates
- `test:` → tests

Keep it short and clear. Don't overthink it.

If it helps, include the issue number:

- `fix(menu): keep long descriptions lined up (#6)`

#### Examples:

- `feat(drivers): add a new VM package`
- `fix(update): keep user settings when merging configs`
- `docs: clarify the VM setup`


## Before pushing

- Make sure it works locally
- Keep commits focused (don't mix unrelated stuff)
- Push with a clear message

## Your commits are public

Your commit messages end up on the Releases page, sorted under headings by their type, so write them for the people using Viresta. For example, `fix: show the version in the prompt instead of HEAD` tells a user what changed, while `fix: stuff` doesn't.

#### [03. Releasing ➔](/docs/contents/03_RELEASING.md)