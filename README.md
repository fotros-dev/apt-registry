# apt-registry

[![lint](https://github.com/fotros-dev/apt-registry/actions/workflows/lint.yml/badge.svg)](https://github.com/fotros-dev/apt-registry/actions/workflows/lint.yml)
[![Latest release](https://img.shields.io/github/v/release/fotros-dev/apt-registry)](https://github.com/fotros-dev/apt-registry/releases/latest)

Switch your apt sources to a mirror with one command, and back with another.

## Contents

1. [What it does](#what-it-does)
2. [Before you start](#before-you-start)
3. [Install](#install)
4. [Quick start](#quick-start)
5. [Commands](#commands)
6. [Use it in Docker](#use-it-in-docker)
7. [Use it in CI](#use-it-in-ci)
8. [Add your own mirror mapping](#add-your-own-mirror-mapping)
9. [Troubleshooting](#troubleshooting)
10. [Uninstall](#uninstall)
11. [How it works](#how-it-works)
12. [Contributing](#contributing)
13. [License](#license)

## What it does

`apt-registry` is a small Bash script for Debian, Ubuntu and other systems that use apt.

- It changes the addresses in your apt sources so that apt downloads packages through a
  mirror. A mirror is a server that keeps copies of the official package repositories.
- It only changes the addresses of repositories it knows (Ubuntu, Debian, Docker,
  NodeSource). Everything else stays as it is.
- It keeps an exact copy of every file it changes. `apt-registry unset` puts the files back.
- It checks that the mirror works. If `apt-get update` fails through the mirror, it switches
  back by itself.

If you know npm, it works like the npm registry setting:

| npm | apt-registry |
|---|---|
| `npm config set registry <url>` | `apt-registry set <url>` |
| `npm config get registry` | `apt-registry get` |
| `npm config delete registry` | `apt-registry unset` |

## Before you start

You need three things:

- A system that uses apt, for example Debian or Ubuntu.
- Root access: either `sudo`, or a root shell (for example inside a Docker container).
- The URL of a compatible mirror, for example `http://mirror.example.com:3142`.

A compatible mirror serves each upstream repository under a fixed path, and answers
`GET /-/ping` with `{}`. For example, the mirror serves `http://archive.ubuntu.com/ubuntu` at
`<mirror-url>/ubuntu`. These are the paths `apt-registry` uses:

| Upstream repository | Path on the mirror |
|---|---|
| `archive.ubuntu.com/ubuntu` and country mirrors such as `de.archive.ubuntu.com/ubuntu` | `/ubuntu` |
| `security.ubuntu.com/ubuntu` | `/ubuntu-security` |
| `ports.ubuntu.com/ubuntu-ports` | `/ubuntu-ports` |
| `deb.debian.org/debian` | `/debian` |
| `deb.debian.org/debian-security` and `security.debian.org/debian-security` | `/debian-security` |
| `download.docker.com/linux/ubuntu` | `/docker-ubuntu` |
| `download.docker.com/linux/debian` | `/docker-debian` |
| `deb.nodesource.com/node_22.x` | `/nodesource` |

You can add more paths yourself. See [Add your own mirror mapping](#add-your-own-mirror-mapping).

### Supported systems

apt has two formats for source files. The one-line format is used in `sources.list` and
`*.list` files. The newer deb822 format is used in `*.sources` files. `apt-registry` handles
both, so what matters is the format, not the name of the system.

| System | Sources format | Tested | What goes through the mirror |
|---|---|---|---|
| Ubuntu 22.04 | one-line | Directly, in the `ubuntu:22.04` image | Ubuntu and Ubuntu security |
| Ubuntu 26.04 | deb822 | Directly, in the `ubuntu:26.04` image, including a real `apt-get install` through a mirror | Ubuntu and Ubuntu security |
| Debian 11 | one-line | Directly, in the `debian:11` image | Debian and Debian security |
| Debian 12 | deb822 | Directly, in the `debian:12` image | Debian and Debian security |
| Kali rolling | deb822 | Directly, in the `kalilinux/kali-rolling` image | Nothing. `http.kali.org` is not in the list, so it stays direct. |
| Ubuntu 20.04 | one-line | Covered by format (same as Ubuntu 22.04) | Ubuntu and Ubuntu security |
| Ubuntu 24.04 | deb822 | Covered by format (same as Ubuntu 26.04) | Ubuntu and Ubuntu security |
| Debian 13 | deb822 | Covered by format (same as Debian 12) | Debian and Debian security |
| Linux Mint 22 | one-line | Covered by format. A copy of Mint's sources file was tested. | Ubuntu repositories. `packages.linuxmint.com` stays direct. |

Docker and NodeSource repositories go through the mirror on every system. Other apt-based
systems should work too.

`apt-registry` uses only programs that every apt system already has: `bash`, `coreutils`,
`sed`, `grep`, `awk`, `diff`, `flock` and `apt`. It does not need `curl` or `wget`.

## Install

Pick one.

### Option A: one command (recommended)

With curl:

```sh
curl -fsSL https://raw.githubusercontent.com/fotros-dev/apt-registry/main/install.sh | sh
```

Or with wget:

```sh
wget -qO- https://raw.githubusercontent.com/fotros-dev/apt-registry/main/install.sh | sh
```

The installer asks for your sudo password if you are not root. You should see:

```text
apt-registry install: downloaded from https://raw.githubusercontent.com/fotros-dev/apt-registry/main with curl
apt-registry install: installed /usr/local/bin/apt-registry (apt-registry 0.1.0)
apt-registry install: installed /usr/share/bash-completion/completions/apt-registry
```

Check it worked:

```sh
apt-registry version
```

You should see `apt-registry 0.1.0` (or a newer version).

### Option B: .deb package

Download the newest package:

```sh
curl -fLO https://github.com/fotros-dev/apt-registry/releases/latest/download/apt-registry_all.deb
```

Install it:

```sh
sudo apt install ./apt-registry_all.deb
```

Check it worked:

```sh
apt-registry version
```

### Option C: from source

You need `git` and `make`.

```sh
git clone https://github.com/fotros-dev/apt-registry.git
cd apt-registry
sudo make install
```

Check it worked:

```sh
apt-registry version
```

## Quick start

In these steps, replace `http://mirror.example.com:3142` with the URL of your mirror.

1. Point apt at your mirror:

   ```sh
   apt-registry set http://mirror.example.com:3142
   ```

   It asks for your sudo password, checks the mirror, changes the sources and runs
   `apt-get update`. You should see something like this. This sample is from Ubuntu 24.04 with
   a Docker repository, run with `--no-update`. Without `--no-update`, the `apt-get update`
   output appears after the first line, and the last line is missing.

   ```text
   Mirror http://mirror.example.com:3142 is reachable.
   Source files:
     /etc/apt/sources.list.d/docker.list
     /etc/apt/sources.list.d/ubuntu.sources
   Through the mirror:
     https://download.docker.com/linux/ubuntu -> http://mirror.example.com:3142/docker-ubuntu
     http://archive.ubuntu.com/ubuntu/ -> http://mirror.example.com:3142/ubuntu
     http://security.ubuntu.com/ubuntu/ -> http://mirror.example.com:3142/ubuntu-security
   Mirror http://mirror.example.com:3142 is active.
   apt-get update was not run (--no-update); run it to fetch the package lists through the mirror.
   ```

   If a repository is not in the list, it appears under `Left direct (not rewritten):`.
   apt keeps using it as before.

2. Check it:

   ```sh
   apt-registry status
   ```

   You should see the mirror, and each source marked `mirror` or `direct`:

   ```text
   mirror:     http://mirror.example.com:3142
   set at:     2026-11-14T15:20:04Z (apt-registry 0.1.0)
   reachable:  yes

   sources apt uses:
     mirror  http://mirror.example.com:3142/docker-ubuntu
     mirror  http://mirror.example.com:3142/ubuntu
     mirror  http://mirror.example.com:3142/ubuntu-security
   ```

3. Use apt as usual:

   ```sh
   sudo apt install <package>
   ```

   Nothing else changes. apt now downloads through the mirror.

4. Go back to normal:

   ```sh
   apt-registry unset
   ```

   You should see `apt now uses the upstream repositories directly.`

## Commands

| Command | What it does | Needs sudo? |
|---|---|---|
| `apt-registry set [<mirror-url>]` | Point apt at the mirror. Without a URL it uses `$APT_REGISTRY_URL`. | Yes |
| `apt-registry get` | Print the active mirror URL. Prints nothing and exits 1 when no mirror is active. | No |
| `apt-registry unset` | Put the original sources back. | Yes |
| `apt-registry status` | Show the active mirror, whether it answers, and every source apt uses. | No |
| `apt-registry upstreams` | Print the list of known repositories and their mirror paths. | No |
| `apt-registry version` | Print the version. | No |
| `apt-registry help` | Print the help. | No |

When a command needs sudo and you are not root, `apt-registry` runs itself again with
`sudo`. You don't have to type `sudo apt-registry` yourself, but you can.

Options:

| Option | Works with | What it does |
|---|---|---|
| `--dry-run` | `set`, `unset` | Show the changes as a diff and change nothing. Works without sudo. |
| `--no-update` | `set`, `unset` | Don't run `apt-get update` afterwards. Without the update there is no automatic switch back. |
| `--force` | `set` | Switch even when the mirror does not answer the check. |

Exit codes (the number a command returns, which you can read with `echo $?`):

| Code | Meaning |
|---|---|
| 0 | Success. |
| 1 | Usage error, for example an unknown option or an invalid URL. Also: `get` when no mirror is active. |
| 2 | The mirror did not answer. Nothing was changed. |
| 3 | `apt-get update` failed through the mirror. The change was undone. |
| 4 | Another `apt-registry` command was running for more than 10 seconds. |
| 5 | `unset` found no active mirror. Nothing to restore. |

## Use it in Docker

Ubuntu:

```dockerfile
FROM ubuntu:24.04
ARG APT_REGISTRY_URL=http://mirror.example.com:3142
ADD --chmod=0755 https://raw.githubusercontent.com/fotros-dev/apt-registry/v0.1.0/apt-registry /usr/local/bin/apt-registry
RUN apt-registry set "$APT_REGISTRY_URL" --no-update \
 && apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && apt-registry unset --no-update \
 && rm -rf /var/lib/apt/lists/*
```

- `FROM ubuntu:24.04` starts from the official Ubuntu image.
- `ARG APT_REGISTRY_URL=...` sets the mirror URL. You can change it with
  `docker build --build-arg APT_REGISTRY_URL=http://other-mirror:3142 .`
- `ADD --chmod=0755 ...` downloads `apt-registry` version 0.1.0 into the image and makes it
  executable. The image has no curl, so Docker downloads it for you.
- `apt-registry set "$APT_REGISTRY_URL" --no-update` points apt at the mirror. It runs as root,
  so no sudo is needed. `--no-update` skips the update because the next line does it.
- `apt-get update` downloads the package lists through the mirror.
- `apt-get install -y --no-install-recommends curl` installs your packages through the mirror.
- `apt-registry unset --no-update` puts the original sources back, so the finished image also
  works without the mirror.
- `rm -rf /var/lib/apt/lists/*` deletes the package lists to keep the image small.

Debian:

```dockerfile
FROM debian:12-slim
ARG APT_REGISTRY_URL=http://mirror.example.com:3142
ADD --chmod=0755 https://raw.githubusercontent.com/fotros-dev/apt-registry/v0.1.0/apt-registry /usr/local/bin/apt-registry
RUN apt-registry set "$APT_REGISTRY_URL" --no-update \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && apt-registry unset --no-update \
 && rm -rf /var/lib/apt/lists/*
```

- `FROM debian:12-slim` starts from the small official Debian 12 image.
- `ARG`, `ADD` and `apt-registry set` work the same way as in the Ubuntu example.
- `apt-get update` downloads the Debian package lists through the mirror.
- `apt-get install -y --no-install-recommends ca-certificates curl` installs your packages
  through the mirror.
- `apt-registry unset --no-update` puts the original sources back.
- `rm -rf /var/lib/apt/lists/*` deletes the package lists to keep the image small.

`ADD --chmod` needs BuildKit, which is the default builder since Docker 23.

## Use it in CI

This GitHub Actions step points the runner's apt at your mirror before you install packages.
Store the mirror URL as a repository variable named `APT_MIRROR_URL`
(**Settings > Secrets and variables > Actions > Variables**).

```yaml
- name: Use the apt mirror
  run: |
    curl -fsSL https://raw.githubusercontent.com/fotros-dev/apt-registry/v0.1.0/install.sh | APT_REGISTRY_REF=v0.1.0 sh
    apt-registry set "${{ vars.APT_MIRROR_URL }}"
    sudo apt-get install -y --no-install-recommends shellcheck
```

- The first line installs `apt-registry` version 0.1.0.
- The second line points apt at the mirror and runs `apt-get update` through it. The runner
  has passwordless sudo, so this needs no password.
- The third line installs a package through the mirror.

The runner must be able to reach your mirror. GitHub-hosted runners can only reach public
mirrors. For a mirror on a private network, use a self-hosted runner.

## Add your own mirror mapping

You can teach `apt-registry` about more repositories. Put one line per repository in
`/etc/apt-registry/upstreams`:

```text
<upstream address without http://> <path on the mirror>
```

Example: your mirror also serves the PostgreSQL repository `https://apt.postgresql.org/pub/repos/apt`
under `/postgresql`, and your sources use a country mirror of Ubuntu.

1. Create the file:

   ```sh
   sudo mkdir -p /etc/apt-registry
   sudo tee /etc/apt-registry/upstreams <<'EOF'
   # PostgreSQL repository
   apt.postgresql.org/pub/repos/apt    /postgresql
   # Our country mirror of Ubuntu
   mirror.example.net/ubuntu           /ubuntu
   EOF
   ```

2. Check it:

   ```sh
   apt-registry upstreams
   ```

   You should see your two lines at the end of the list:

   ```text
   ...
   deb.nodesource.com/node_22.x             /nodesource
   apt.postgresql.org/pub/repos/apt         /postgresql
   mirror.example.net/ubuntu                /ubuntu
   ```

3. If a mirror is already active, switch back and set it again, so the new lines are used:

   ```sh
   apt-registry unset --no-update
   apt-registry set http://mirror.example.com:3142
   ```

Rules for the file:

- The address has no `http://` or `https://` and no `/` at the end.
- An address that starts with `*.` matches every subdomain. For example,
  `*.archive.ubuntu.com/ubuntu` matches `de.archive.ubuntu.com/ubuntu`.
- The path starts with `/` and has no `/` at the end.
- Lines that start with `#` are comments. Empty lines are ignored.
- A line with the same address as a built-in line replaces it.

If a line is wrong, `apt-registry upstreams` tells you the line number, for example:

```text
error: /etc/apt-registry/upstreams:2: mirror path must start with / and have no trailing slash: postgresql
```

## Troubleshooting

### The mirror is unreachable

- **What you see**: `error: mirror is not reachable: ... Nothing was changed. Use --force to switch anyway.`
  The command returns exit code 2.
- **Why**: `apt-registry` asked `<mirror-url>/-/ping` and got no answer within 5 seconds, or
  the answer was not `{}`. The URL may be wrong, the mirror may be down, or a firewall or VPN
  blocks it.
- **Fix**: test the same request yourself:

  ```sh
  /usr/lib/apt/apt-helper download-file http://mirror.example.com:3142/-/ping /tmp/ping && cat /tmp/ping
  ```

  You should see `{}`. Fix the URL or the network, then run `apt-registry set` again. If you
  know the mirror will work later (for example, you build an image for another network), add
  `--force`.

### apt-get update was rolled back

- **What you see**: `warning: apt-get update failed through http://mirror.example.com:3142; rolling back`,
  and at the end `error: apt-get update failed through ...; the change was rolled back`.
  The command returns exit code 3.
- **Why**: the mirror answered the check, but at least one repository failed through it.
  Often the mirror does not serve that path, or does not have that release.
- **Fix**: your sources are already back to normal. Read the `Err:`, `E:` and `W:` lines
  printed before the warning. They show which address failed. Fix the mirror, or add that
  repository's mapping, then run `apt-registry set` again.

  Errors from repositories that don't go through the mirror (for example an old PPA) don't
  undo the change. You see
  `warning: apt-get update failed only for repositories that do not go through the mirror; the mirror stays active:`
  followed by those errors, and the command returns 0. Fix or remove those repositories
  separately.

### Hash Sum mismatch

- **What you see**: `E: Failed to fetch ... Hash Sum mismatch`.
- **Why**: a file from the mirror does not match the checksum apt expected. Usually the mirror
  was in the middle of an update, or a proxy changed the file. `apt-registry` never changes
  package files.
- **Fix**: wait a minute and try again. If it still fails, delete the cached lists and update:

  ```sh
  sudo rm -rf /var/lib/apt/lists/*
  sudo apt-get update
  ```

  If it still fails, tell the people who run the mirror, and use `apt-registry unset` until
  it is fixed.

### NO_PUBKEY

- **What you see**: `The following signatures couldn't be verified because the public key is not available: NO_PUBKEY ...`
- **Why**: the signing key (the file apt uses to check that packages are genuine) for that
  repository is missing on your computer. The mirror is not the cause: it passes signed files
  through unchanged, and `apt-registry` never changes keys.
- **Fix**: install the repository's key as its website describes. To confirm, run
  `apt-registry unset` and `sudo apt-get update`. You see the same error without the mirror.

### apt proxy warning

- **What you see**: `apt-registry status` prints
  `warning: apt is configured to use a proxy, so traffic to the mirror goes through it:`.
- **Why**: your apt configuration has a proxy setting (`Acquire::http::Proxy`). apt sends the
  mirror traffic through that proxy too. This can make it slow, or fail.
- **Fix**: tell apt to reach the mirror directly. Replace `mirror.example.com` with your
  mirror's host name:

  ```sh
  echo 'Acquire::http::Proxy::mirror.example.com "DIRECT";' | sudo tee /etc/apt/apt.conf.d/99apt-registry-no-proxy
  ```

  Run `apt-registry status` again. The warning is gone.

### I edited my sources while the mirror was on

- **What you see**: `apt-registry unset` prints
  `Reverted mirror URIs in /etc/apt/... (it was edited after set; the edits were kept)`.
- **Why**: the file changed after `apt-registry set`, so it is not replaced with the old copy.
  Only the mirror addresses are changed back.
- **Fix**: nothing to fix. Your edits are kept. Lines you did not touch are exactly as before.
  Check the file with `cat` if you want to be sure.

  Note: new lines you add while the mirror is on do not go through the mirror. To include
  them, run `apt-registry unset --no-update` and then `apt-registry set` again.

## Uninstall

Always switch back first, because `apt-registry` is needed to restore your sources:

```sh
apt-registry unset
```

If you installed with Option A (one command):

```sh
sudo rm -f /usr/local/bin/apt-registry /usr/share/bash-completion/completions/apt-registry
sudo rm -rf /var/lib/apt-registry /etc/apt-registry
```

If you installed with Option B (.deb package):

```sh
sudo apt purge apt-registry
```

If you installed with Option C (from source), run this inside the cloned folder:

```sh
sudo make uninstall
sudo rm -rf /var/lib/apt-registry /etc/apt-registry
```

If you remove the package while a mirror is still active, it only prints a warning and leaves
your sources as they are.

## How it works

This part is for the curious. You don't need it to use the tool.

**Files it reads.** `/etc/apt/sources.list`, and every `*.list` and `*.sources` file in
`/etc/apt/sources.list.d/`. These are the files that tell apt where to download from.

**What it changes.** Only the repository addresses. Comments, options such as
`[arch=amd64 signed-by=...]`, spacing and line endings stay exactly as they were.

A `.list` file, before `apt-registry set http://mirror.example.com:3142`:

```text
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable
```

After:

```text
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] http://mirror.example.com:3142/docker-ubuntu noble stable
```

A `.sources` file, before:

```text
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

After:

```text
Types: deb
URIs: http://mirror.example.com:3142/ubuntu
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

**Where it keeps its backup.** In `/var/lib/apt-registry/`. For each changed file it keeps the
original copy, the file as `set` wrote it, and the list of replaced addresses. `unset` puts the
original back if you did not touch the file. If you edited it, `unset` keeps your edits and
only changes the mirror addresses back. Files are replaced in one step, so apt never sees a
half-written file. A lock stops two `apt-registry` commands from running at the same time.

**Why keys don't change.** Each repository signs its file lists with its own key. The mirror
passes these signed files through unchanged. apt checks the signature with the same key as
before, and then checks every package against the signed checksums. So it does not matter that
the files come from a different server, and the `signed-by` options stay as they are.

## Contributing

Bug reports are welcome. Please use the
[bug report template](https://github.com/fotros-dev/apt-registry/issues/new?template=bug_report.md).
It asks for your system, the command you ran and its output.

Pull requests are welcome too. The rules:

- `apt-registry` stays one Bash script.
- No new dependencies. Only programs that every apt system already has.
- No comments in the code. Clear names explain the code, and this README explains the rest.
- The code must pass `shellcheck` with no findings.

Check your change before you open a pull request. You need `make` and `shellcheck`
(`sudo apt install make shellcheck`):

```sh
make lint
```

It prints nothing but the commands it runs when everything is fine. GitHub Actions runs the
same check on every push and pull request.

To release version `X.Y.Z` (maintainers):

1. Set `VERSION` to `X.Y.Z`, and `readonly APT_REGISTRY_VERSION="X.Y.Z"` in `apt-registry`.
   `make lint` fails if the two differ.
2. Add a `## [X.Y.Z] - YYYY-MM-DD` section to `CHANGELOG.md`.
3. Commit, tag and push:

   ```sh
   git commit -am "Release X.Y.Z"
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```

The release workflow checks that the tag matches `VERSION`, builds the `.deb`, and creates a
GitHub release with `apt-registry_X.Y.Z_all.deb` and `apt-registry_all.deb` attached.

## License

MIT. See [LICENSE](LICENSE).
