# Changelog

All notable changes. Versions follow [semver](https://semver.org): a scene that builds clean keeps building clean within a major version.

## [Unreleased]

### Fixed
- `motion shot f.html 99` silently showed the last step; out-of-range steps now fail with the valid range.
- Shot paths no longer contain `//` when `TMPDIR` ends in a slash.

## [1.1.1] - 2026-10-07

Found by an independent verification pass.

### Fixed
- Scenes with Windows (CRLF) line endings failed with a misleading CSP error. The build now hashes the text the browser sees.
- `motion new some/dir/name` failed with a raw bash error when the folder did not exist; it now creates it.
- A missing Chrome printed two errors, the second with wrong advice; now one message that points at `motion doctor`.
- `test/run.sh` stops early with a clear message when `node` or `python3` is missing.
- Docs no longer assume the git-clone path for `motion doctor` and the voice setup; plugin installs are covered.

## [1.1.0] - 2026-10-07

### Added
- `motion new <name> [template]`: start a scene from a two-box starter or from an example (`architecture`, `algorithm`, `idea`, `story`). Never overwrites.
- `motion doctor`: checks Chrome, `openssl`, an end-to-end build and the optional voice setup, with a fix line for each failure.
- `motion --version` and a `VERSION` file.
- Install as a Claude Code plugin: `/plugin marketplace add 4lxn/motion-explainer`.
- `MOTION_CHROME` to point at any Chrome or Chromium; Linux paths are found automatically.
- `MOTION_SCALE=2` for retina-resolution `motion shot` PNGs.
- CI on Ubuntu and macOS; issue templates; CONTRIBUTING.md.

### Changed
- Lint errors suggest the closest valid name: `unknown type 'bxo'. Did you mean 'box'?` (types, verbs, ids, arrow endpoints, icons, eases).
- JavaScript errors in a scene report `<scene>.scene.js:<line>` instead of a line in the built HTML.
- `motion`, `motion help` and `--help` print usage on stdout and exit 0; an unknown command is named and exits 2.
- SKILL.md finds its files through `${CLAUDE_SKILL_DIR}`, so it works from any install location, and starts scenes with `motion new`.

### Fixed
- `motion open file.html 12` opened a 12x12 window; sizes must be `WIDTHxHEIGHT`.
- Built pages requested `/favicon.ico` (a 404 on most hosts).
- A scene with no steps crashed the player at boot; it now says what is missing.

## [1.0.0] - 2026-10-07

First public release: scene engine and player, `motion build / check / shot / open / voice`, four examples, tests.

[Unreleased]: https://github.com/4lxn/motion-explainer/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/4lxn/motion-explainer/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/4lxn/motion-explainer/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/4lxn/motion-explainer/releases/tag/v1.0.0
