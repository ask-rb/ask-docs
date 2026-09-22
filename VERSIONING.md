# Versioning — ask-docs

This file is this repository's **canonical versioning policy**. When
anything else in the repo (README, RELEASE.md, commit messages) disagrees
with it, this file wins.

## Semantic Versioning

Versions are `MAJOR.MINOR.PATCH`, following
[Semantic Versioning 2.0.0](https://semver.org):

- **PATCH** — backwards-compatible bug fixes only.
- **MINOR** — backwards-compatible new functionality.
- **MAJOR** — breaking changes.

### Pre-1.0 (0.x.y)

While the major version is `0`, the public surface is not frozen:

- **0.x.PATCH** — bug fixes.
- **0.x.MINOR** — new functionality, *or* any change that would be breaking
  at 1.0 (removing/renaming public content or behavior, changing defaults).
  Pre-1.0, MINOR carries the breaking changes — there is no separate major
  bump until 1.0.0.
- **1.0.0** — first stable release; from here MAJOR/MINOR/PATCH mean exactly
  what SemVer says.

### Sequential one-step patch increments

Patch numbers advance by exactly one per release: `0.32.0` → `0.32.1` →
`0.32.2`. Never skip or jump patch numbers (`0.32.0` → `0.32.3` is wrong),
even when several fixes ship together — they ship as a single release with a
single patch number. The same one-step rule applies to minor and major.

## Changelog workflow (Unreleased)

- `CHANGELOG.md` keeps an `## [Unreleased]` section at the top.
- Every user-facing change lands under `Unreleased` in the same commit/PR
  that introduces it, using Keep a Changelog headings (`Added`, `Changed`,
  `Fixed`, `Removed`).
- At release time, rename `## [Unreleased]` to `## [X.Y.Z] — YYYY-MM-DD` and
  open a fresh empty `## [Unreleased]` above it.

## All releases go through gemchain

This is an `ask-*` repository, so **every** release runs through
**gemchain** from the workspace root — never `rake release`, never a
hand-run publish:

```bash
cd /Users/kaka/Code/ask-rb
gemchain guard ask-docs
gemchain update ask-docs <new-version> --dry-run
gemchain update ask-docs <new-version>
```

gemchain bumps the version, runs the checks, publishes, rewrites dependent
gems' constraints, and cascades their releases in topological order.

**gemchain itself** is not an `ask-*` gem, so the cascade cannot release it.
It follows the same release discipline manually: bump `VERSION`, update the
changelog, run tests, commit, `gem build` + `gem push`, `git tag`, push —
then `gem install gemchain` to refresh the installed binary.

## Dependency releases use the gemchain cascade

When a release changes a dependency constraint for other gems, gemchain
cascades: each dependent gets its constraint rewritten, its tests run, and a
cascade-level release published (patch by default, per `cascade.yml`), in
dependency order. Never release dependents by hand to "keep up."

## Clean tree required

A release starts from a clean tree. `git status --porcelain` must be empty
before `gemchain update` — commit or stash work-in-progress first. gemchain
commits the release's own changes (version, constraints, lockfile) as part
of the release. A release is only done when it is **published and its
commit is pushed**.

## Release checklist

1. Tree clean — `git status --porcelain` is empty.
2. Tests/build pass — the repo's test and build tasks succeed
   (`bundle exec rake test` / `bundle exec rake build`).
3. Changelog — `Unreleased` entries moved under the new `X.Y.Z` heading with
   the release date.
4. Version — bumped by gemchain, not by hand.
5. Commit — created (gemchain does this as part of the release).
6. Tag — `vX.Y.Z` created.
7. Publish — pushed inside gemchain.
8. Push — commit and tag pushed (`git push origin HEAD --tags`).
9. Verify — see "Version agreement" below.

## Version agreement

After every release these must all say the same thing:

| Source | Must equal |
|---|---|
| Published version | `X.Y.Z` |
| Version source of truth at HEAD | `X.Y.Z` |
| Git tag | `vX.Y.Z` |
| Source committed **and** pushed | yes |

If the published version and the committed source disagree, the release is
orphaned (published but never committed). Fix it by running the checks, then
committing and pushing the version/changelog changes.

## Examples

- Typo or link fix: `0.32.0` → `0.32.1`.
- Several doc fixes ship together: one release, `0.32.0` → `0.32.1` (never
  `0.32.3`).
- New documentation section: `0.32.1` → `0.33.0`.
- Restructure/removal that breaks existing links (breaking while pre-1.0):
  `0.33.0` → `0.34.0`, with a `Changed` / `Removed` changelog entry.
- First stable release: `0.9.x` → `1.0.0`.
- This repo bumped because a dependency released: patch only, e.g. `0.32.1` →
  `0.32.2`, via the gemchain cascade — never hand-published.
