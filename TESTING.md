# Testing

This file records the manual test run done before the first public release on GitHub
(2026-11-14). There are no automated tests in the repository. The tests ran in Docker
containers with a small test harness kept outside the repository.

## Setup

- **Images.** The behaviour depends on the sources format, not on the distribution name. So
  the tests use one image per format and family, plus the real Kali image:

  | Image | Sources format |
  |---|---|
  | `ubuntu:22.04` | one-line `sources.list` |
  | `ubuntu:26.04` | deb822 `ubuntu.sources` |
  | `debian:11` | one-line `sources.list` |
  | `debian:12` | deb822 `debian.sources` |
  | `kalilinux/kali-rolling` (2026.3) | deb822 `kali.sources` (`http.kali.org`) |

  Linux Mint was not run as an image. Every container got a realistic copy of Linux Mint 22's
  `/etc/apt/sources.list.d/official-package-repositories.list` instead (written by hand, not
  taken from a Mint image).
- **Stub mirror.** A small HTTP server answers `GET /-/ping` with `{}` and everything else with
  404. It is used for reachability and, with `--no-update`, for every file transformation check.
- **Reverse-proxy mirror.** A Node.js server (built-in modules only) maps `/ubuntu`,
  `/ubuntu-security`, `/debian` and `/debian-security` to the real upstream archives. It is used
  for the real `apt-get update` / `apt-get install curl` cycle on `ubuntu:26.04`.
- **Other servers.** A file server serves `install.sh`, `apt-registry` and the completion file
  under `<base>/main/` for `APT_REGISTRY_BASE`, and returns 404 for any other ref. A
  "wrong answer" server answers `/-/ping` with an HTML page.
- Containers ran as root without sudo. Users `tester` (passwordless sudo) and `plain` (no
  sudo rights) were created for check 11.

## Checks

| # | Check |
|---|---|
| 1 | `make lint` is clean (run once, on the host, with shellcheck 0.11.0). |
| 2 | `install.sh` served from a local HTTP server, run under `dash`, three times: with apt-helper only (no curl, no wget), with only wget, with curl. A wrong `APT_REGISTRY_REF` fails cleanly. |
| 3 | `set --dry-run` prints a diff on stdout and writes nothing (sha256, owner and mode of every source file, and the state directory, compared before and after). |
| 4 | `set --no-update`, then `unset --no-update`: every source file is byte-identical with the same owner and mode, including a file owned by `4321:4322` with mode `0664`. |
| 5 | A Docker `.list` with `[arch=amd64 signed-by=…]`, a `.sources` file with a multi-URI `URIs:` field and a continuation line, and a CRLF file without a final newline are rewritten exactly as expected; everything else is preserved. |
| 6 | Running `set` twice is a no-op (files and state unchanged). Switching to a second URL works, and no source mentions the first URL afterwards. |
| 7 | A rewritten file edited between `set` and `unset`: the edit survives, and every line gets its own original URI back. |
| 8 | Unknown upstreams (a PPA, `http.kali.org`, `packages.linuxmint.com`) are reported as direct by `set` and `status` and stay byte-identical. The Mint copy: Ubuntu lines go through the mirror, `packages.linuxmint.com` stays direct. Real Kali: `kali.sources` stays byte-identical, and `set` reports that nothing matched, exits 0 and creates no state. |
| 9 | `deb.debian.org/debian-security` and `security.debian.org/debian-security` map to `/debian-security`. |
| 10 | Unreachable mirror (connection refused, no answer, wrong answer) exits 2 and changes nothing; the no-answer case gives up after about 5 seconds. `apt-get update` failing through the mirror rolls back and exits 3 with identical files. A broken repository that does not go through the mirror does not cause a rollback. |
| 11 | Root without sudo works. A normal user with sudo re-executes through sudo. A normal user can run `get`, `status`, `upstreams`, `set --dry-run` and `unset --dry-run` without sudo, also when a source file is readable only by root. A normal user without sudo gets exit 1 with a clear message. |
| 12 | Three concurrent loops of `set` / switch / `unset` (54 runs): a reader that hashes every source file in a loop never sees a half-written or unexpected file; no temporary files or staging directories are left; the final files match the final state. A held lock makes `set` wait 10 seconds and exit 4. |
| 13 | `make deb`, `apt install ./dist/*.deb`, `apt-registry version`, then `apt remove` while a mirror is active: only a warning, sources and state untouched. `apt purge` keeps the state while a mirror is active and removes it otherwise. |
| 14 | Every command, option and exit code in `apt-registry help`: no arguments, `help`/`--help`/`-h`, `version`/`--version`/`-V`, unknown command or option, invalid URLs, two URLs, `APT_REGISTRY_URL` as default, URL normalisation, `get` with nothing active (exit 1), `unset` with nothing active (exit 5), `--force`, `--dry-run` with an unreachable mirror, `unset --dry-run`, `upstreams` with a valid and an invalid `/etc/apt-registry/upstreams`. |
| F | Full cycle on `ubuntu:26.04`: `set` through the reverse-proxy mirror (with `apt-get update`), `apt-get install -y curl` through the mirror, `unset`. |

## Results

Final run with the fixed code. PASS means every assertion of that check passed on that
image. PARTIAL and NOT DONE are explained below the table.

| Check | `ubuntu:22.04` | `ubuntu:26.04` | `debian:11` | `debian:12` | `kali-rolling` |
|---|---|---|---|---|---|
| 1 lint | PASS (host) | PASS (host) | PASS (host) | PASS (host) | PASS (host) |
| 2 install.sh | PASS | PASS | PASS | PASS | PASS |
| 3 dry run | PASS | PASS | PASS | PASS | PASS |
| 4 set/unset byte-identical | PASS | PASS | PASS | PASS | PASS |
| 5 .list and .sources rewriting | PASS | PASS | PASS | PASS | PASS |
| 6 idempotent, switch URL | PASS | PASS | PASS | PASS | PASS |
| 7 edit between set and unset | PASS | PASS | PASS | PASS | PASS |
| 8 unknown upstreams, Mint copy, Kali | PASS | PASS | PASS | PASS | PASS |
| 9 debian-security mapping | PASS | PASS | PASS | PASS | PASS |
| 10 unreachable, rollback | PASS | PARTIAL (a) | PASS | PASS | PASS |
| 11 root, sudo, normal user | PASS | PASS | PARTIAL (b) | PASS | PASS |
| 12 concurrency, lock | PASS | PASS | PASS | PASS | PASS |
| 13 .deb package | PASS | PASS | PASS | PARTIAL (c) | PASS |
| 14 help, options, exit codes | PASS | PASS | PASS | PASS | PASS |
| F full apt-get cycle | not run | NOT DONE (d) | not run | not run | not run |

(a) In the final run, the "unrelated broken repository" case on `ubuntu:26.04` hit a failed
fetch through the mirror as well, so `apt-registry` correctly rolled back (exit 3) instead of
keeping the mirror. All three assertions of that case passed in the previous run with the same
code. Every other part of check 10 passed.

(b) The parts that need sudo installed were not run: downloading the `sudo` package timed out.
Root without sudo and every normal-user check without sudo passed. The sudo re-exec passed on
the four other images.

(c) `make deb` passed. `apt install ./dist/*.deb` was refused by apt because a test fixture
(`sec.list`, which names `deb.debian.org/debian-security` without `Signed-By`) conflicts with
the image's own `debian.sources`. This is a problem of the test setup, not of the package.
The package checks passed on the four other images.

(d) The full cycle was tried three times and never completed, because downloads from the
upstream archives through the test proxy failed: once with a `Hash Sum mismatch`, once with
upstream timeouts that cut files short, and once with failed fetches. Each time `apt-registry`
did what it should: it rolled back, exited 3, and the source files were byte-identical
afterwards. The `apt-get update` part through the mirror did work (all `InRelease` files and
most `Packages` files were fetched through it), but `apt-get install -y curl` through the
mirror has not been shown end to end.

## Environment limitations

- **Debian 11 security archive.** Debian 11 is end-of-life upstream. During the test,
  `deb.debian.org/debian-security` listed `bullseye-security` packages whose files returned
  404, also in a clean `debian:11` container without `apt-registry`. Helper packages for the
  tests (curl, wget, sudo, make) were installed from the base `bullseye` suite instead.
- **Slow network.** Downloads from the upstream archives ran at about 130 kB/s at times, with
  timeouts. This limited the full `apt-get` cycle (note d) and made one package download fail
  (note b).
- **Linux Mint** was covered by a hand-written copy of its sources file, not by a Mint image.
- **Formats instead of every release.** Ubuntu 20.04 and Debian 11 share the one-line format
  with Ubuntu 22.04. Ubuntu 24.04 and Debian 13 share the deb822 format with Ubuntu 26.04 and
  Debian 12. They were not run as separate images.

## Bugs found and fixed

The same checks were first run against the original code. Failures caused by mistakes in the
test harness itself were fixed in the harness and are not listed here. These are the bugs in
`apt-registry`:

1. **`unset` gave edited files the wrong original URIs.** When a file was edited after `set`,
   `unset` turned every mirror URI back into the *first* original URI that mapped to the same
   mirror path. Check 7 failed on all five images. For example, in one file
   `http://de.archive.ubuntu.com/ubuntu/` and `http://archive.ubuntu.com/ubuntu` both became
   `http://de.archive.ubuntu.com/ubuntu/`, and `deb.debian.org/debian-security/` became
   `security.debian.org/debian-security`. A trailing slash was also lost
   (`https://download.docker.com/linux/ubuntu/` became `…/linux/ubuntu`). So after `unset`,
   apt could use a different upstream server than before.

   **Fix:** `set` now also saves the file as it wrote it (`files/<n>/after` in the state). For
   an edited file, `unset` lines up that saved copy with the current file using `diff`. Lines
   that were not edited come back byte for byte from the original copy. Only edited or new
   lines go through the URI mapping. State written by older versions (without `after`) still
   uses the old mapping.

2. **`set --dry-run` crashed for a normal user when a source file was readable only by root.**
   It stopped with a raw bash error (`…/private.list: Permission denied`, exit 1). `status`
   had the same problem in its fallback path.

   **Fix:** source files the current user cannot read are skipped with a warning that names the
   file and says to run as root to include it.

3. **An unrelated broken repository made `set` roll back.** If any repository failed during
   `apt-get update`, for example an old PPA that does not go through the mirror, `set` rolled
   back and blamed the mirror ("apt-get update failed through <mirror>"), even when everything
   through the mirror worked. A system with one broken third-party repository could never use
   a mirror.

   **Fix:** `set` rolls back when a failure line names the mirror, or when `apt-get update`
   fails without naming any repository (for example a lock error). When every failure line
   names other repositories only, the mirror stays active, the failures are printed as a
   warning, and `set` exits 0.

Fix 1 is verified by check 7 and fix 2 by check 11 in the final run, on all five images.
Fix 3 is verified by the "unrelated broken repository" case of check 10, which passed on
`ubuntu:26.04` in the run before the final one (see note a). All three are listed in
`CHANGELOG.md` under "Unreleased".
