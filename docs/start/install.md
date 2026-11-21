---
description: Installing a jac release with the installer, its options, where it puts things, checking that it works, uninstalling, and installing the reference design in its place.
keywords: installer, install.sh, uninstall, --reference
---
# Install

One command installs the latest release on Linux (x86_64 or arm64) and on macOS (Apple Silicon):

```sh
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jac/main/scripts/install.sh | bash
```

Then check it:

```sh
jac --version
echo 'with entry { print("hello from jac"); }' > hello.jac
jac build hello.jac -o hello
./hello
```

```text
hello from jac
```

`jac --version` prints `jac <version> (<platform>, <commit>)`. A jac that was built from a checkout instead of installed from a release prints `jac, built from source (<platform>)`.

The documentation came with it. `jac docs` prints the map of its pages, and `jac docs <word>` the page that defines a word, an error code or a command; see [docs and skills](../toolchain/docs.md) (`jac docs toolchain/docs`).

## What the installer does

1. Works out the platform from `uname`: `linux-x86_64`, `linux-aarch64` or `macos-aarch64`.
2. Lists the releases of `jaseci-labs/jac` and takes the newest of jac's that has an archive for the platform, unless `--version` names one. jac's releases are the ones tagged `jac-v<version>`; the repository also holds the reference design's ([below](#the-reference-design)).
3. Downloads `jac-<version>-<platform>.tar.gz` and its `.sha256`, and stops unless the archive matches the checksum. On a terminal it shows the download's progress.
4. Unpacks the archive as `~/.jac/<version>/`, replacing a copy of the same version.
5. Points the link `~/.jac/current` at that version, and the link `~/.local/bin/jac` at `~/.jac/current/bin/jac`.
6. Builds and runs a one-line program with the installed compiler, started by its name as you will start it. If that fails, the installer says so and exits with status 1; the release stays unpacked.
7. If `~/.local/bin` is not on `PATH`, prints the line to add to your shell's profile.

It needs `curl`, `tar`, and `sha256sum` or `shasum`. Nothing else is installed and nothing outside those two directories is written.

jac finds its runtime (`rt/`), its documentation (`docs/`) and its toolchain (`lib/`) from where its own executable is, through the links. It reads no configuration file and needs no environment variable.

## Options

Options go after `bash -s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jac/main/scripts/install.sh | bash -s -- --version 0.1.1
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jac/main/scripts/install.sh | bash -s -- --uninstall
```

| Option | What it does |
|---|---|
| `--version <V>` | Install release `V` (`0.70.0`) instead of the newest |
| `--reference` | Install the reference design instead of jac ([below](#the-reference-design)) |
| `--uninstall` | Remove whichever is installed (below) |
| `--help`, `-h` | Print the installer's usage |

| Environment variable | What it changes | Default |
|---|---|---|
| `JAC_HOME` | Where releases are unpacked | `~/.jac` |
| `JAC_BIN_DIR` | Where the `jac` link goes | `~/.local/bin` |
| `GITHUB_TOKEN`, `GH_TOKEN` | Sent with the request for the releases, so the request is not held to GitHub's unauthenticated rate limit | none |
| `JAC_RELEASES_API`, `JAC_RELEASES_DOWNLOAD` | Where the releases are listed and downloaded from, for a mirror | `jaseci-labs/jac` on GitHub |

These are read by the installer only. jac itself reads none of them.

## Where things are

```text
~/.local/bin/jac -> ~/.jac/current/bin/jac
~/.jac/current   -> ~/.jac/<version>
~/.jac/<version>/
    bin/jac
    rt/
    docs/
    lib/
    README.md
    VERSION
```

Installing another version adds a directory beside the first and moves the two links; the older version stays until you delete its directory or uninstall.

Two more places are written when jac runs, not when it is installed:

- The build cache, in your per-user cache directory (`~/Library/Caches/jac` on macOS, `$XDG_CACHE_HOME/jac` or `~/.cache/jac` on Linux). See [The build cache](../toolchain/cache.md).
- A `.jac/` directory in each project you build or test. See [Projects](../toolchain/projects.md).

## Uninstalling

`--uninstall` removes the link `$JAC_BIN_DIR/jac` and every version unpacked under `$JAC_HOME`. It leaves the build cache and your projects' `.jac/` directories; delete those yourself.

## The reference design

The repository jac is released from also holds the language's open-source reference design, the compiler Jac was first released as, in `jac-reference/`. It is released there at its own versions, and the same script installs it:

```sh
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jac/main/scripts/install.sh | bash -s -- --reference
```

- It is one binary, put at `~/.local/bin/jac`.
- Both are the command `jac`, so a machine has one or the other: installing one where the other is replaces it, and says so. `jac version` says which is there.
- `--version` names a version of the kind being installed, and `--uninstall` removes whichever is there.
- [Coming from the reference design](coming-from-the-reference-design.md) lists where the two differ as languages.

## Platforms the installer does not cover

| Platform | What to do |
|---|---|
| Windows | Each release has `jac-<version>-windows-x86_64.zip`, built on Linux and not yet tested on Windows. The installer refuses to run under MSYS, MinGW or Cygwin and points at the zip; under WSL2 it installs the Linux release |
| macOS on Intel | No release. A jac on another platform builds programs for it: `--target macos-x86_64` |
| Anything else | The installer stops with `Unsupported operating system` or `Unsupported architecture` |

## What goes wrong

| Message | Cause |
|---|---|
| `Required command not found: curl` (or `tar`) | Install the command and run the installer again |
| `Could not read the releases from ...` | No connection, or GitHub's rate limit: set `GITHUB_TOKEN` |
| `There is no release <V> of jac` | No release is tagged `jac-v<V>`. Where the reference design has a release of that number, the message gives the command that installs it |
| `No release of jac has a build for <platform>` | Where the reference design has one, the message gives its command |
| `Failed to download ...` | A network problem or an outage: the release lists the file |
| `Checksum verification failed.` | The download does not match the release's `.sha256`. Nothing is installed |
| `... could not compile and run a test program on this machine.` | The release was unpacked but cannot build a program here |

After installing, continue with [A first program](first-program.md) (`jac docs first-program`).
