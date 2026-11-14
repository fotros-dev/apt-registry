# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [0.1.0]

### Changed

- The project moved to GitHub: `install.sh` downloads from `raw.githubusercontent.com`, releases
  are GitHub Releases with `apt-registry_<version>_all.deb` and `apt-registry_all.deb` attached,
  and CI runs on GitHub Actions.
- `set` no longer rolls back when `apt-get update` fails only for repositories that do not go
  through the mirror. It prints those errors as a warning and keeps the mirror active.

### Fixed

- `unset` on a file that was edited after `set` gave every line the first original URI that mapped
  to the same mirror path. For example, `de.archive.ubuntu.com/ubuntu/` and
  `archive.ubuntu.com/ubuntu` in one file both came back as the first one. Lines that were not
  edited now come back byte for byte from the saved copy.
- `set --dry-run` as a normal user stopped with a raw `Permission denied` error when a source
  file was readable only by root. The file is now skipped with a warning. The same applies to
  `status` when it falls back to reading the source files itself.

## [0.1.0] - 2026-11-14

### Added

- `apt-registry set`, `get`, `unset`, `status`, `upstreams`, `version` and `help`.
- Token-level rewriting of one-line (`.list`, `sources.list`) and deb822 (`.sources`) files that keeps every other byte.
- Built-in upstream map for Ubuntu, Ubuntu security and ports, Debian, Debian security, Docker and NodeSource.
- User upstream map in `/etc/apt-registry/upstreams`.
- Reachability check through `apt-helper`, automatic rollback when `apt-get update` fails, and a lock against concurrent runs.
- State in `/var/lib/apt-registry` that restores files byte for byte and keeps edits made while the mirror was active.
- `install.sh`, bash completion and `.deb` packaging.
