# Managed build toolchains

Jac provisions external build tools through `jaclang.toolchains`. Normal native
builds request their dependencies automatically. Provision tools ahead of time
without creating a project:

```bash
jac setup --toolchain android
jac setup --toolchain ios
jac setup --toolchain desktop
jac setup --toolchain cef
```

For a workspace app, `jac setup mobile --platform android` provisions the native
toolchain and synchronizes the Expo project. `jac build mobile --platform android`
then builds the APK. Gradle reports progress while installing the platform, build
tools, NDK, and CMake versions requested by the generated project.

## Installation and storage

Large downloads and tool installations are shared between projects under Jac's
platform cache root (`~/.cache/jac/toolchains` on Linux). Set
`JAC_TOOLCHAIN_DIR=/path/to/cache` to relocate them; a project-local `.jac/toolchains`
path works for isolated builds. Generated app projects remain under `.jac/`.

Downloads report the tool, version, platform, bytes received, and percentage when
the server supplies a length. Jac verifies checksums before publishing downloads,
extracts into temporary directories, and serializes concurrent installations.
SDK Manager, Gradle, CocoaPods, and system package managers display their own
installation progress. Toolchain versions and checksums are pinned in source;
Jac does not silently select the latest JDK or Android command-line tools.

Set `JAC_TOOLCHAIN_USE_SYSTEM=0` to force pinned managed tools, useful for CI and
reproducible setup. By default, compatible `JAVA_HOME` / PATH JDK 21 installations
are reused. An incompatible JDK
is left intact while Jac selects its managed JDK. `ANDROID_HOME` (or
`ANDROID_SDK_ROOT`) selects an existing SDK; otherwise Jac creates a managed SDK.
Selected build paths are passed to child processes rather than changing the
shell's environment. Bun remains bundled with Jac and handles JavaScript package installation.
Native build subprocesses receive managed Node.js 22: Expo autolinking uses Node
argument semantics that a renamed Bun executable does not reproduce.

## Android licenses

Review the [Android SDK terms](https://developer.android.com/studio/terms).
Interactive setup launches SDK Manager's license prompts when licenses are absent.
For unattended provisioning, after accepting these terms, set
`JAC_ACCEPT_ANDROID_LICENSES=1`. Without acceptance, a noninteractive build stops
with instructions rather than hanging at an invisible prompt.

## Platform boundaries

- Android provisioning supports Linux x86-64, macOS Intel/ARM, and Windows x86-64.
  JDK availability alone does not imply Android native tool support on another host.
- iOS requires macOS and a working Xcode installation selected with `xcode-select`.
  Jac installs pinned portable Ruby and CocoaPods into its cache when CocoaPods
  is missing; a separate Ruby or Homebrew installation is not required. Apple installation, signing
  identities, provisioning profiles, and account credentials remain user supplied.
- The current desktop native and CEF build recipes support Linux x86-64/ARM64.
  Native WebKitGTK dependencies install through apt, dnf, or pacman when missing;
  administrator access is required. An unattended process needs root or working
  noninteractive sudo. Jac does not disable operating-system authentication.
- CEF archives use the existing pinned upstream SHA-1 digests. Other managed
  artifacts use SHA-256. Desktop source assets are copied into a versioned writable
  cache; builds no longer write into the installed Jac package.

Building a release artifact does not configure a signing identity or publish it.

## Offline builds

First provision the toolchain and perform a successful online build to populate
package-manager caches. Set `JAC_OFFLINE=1` for cached managed artifacts and Android
Gradle builds. Missing tools fail without starting a download. JavaScript dependency
reuse requires an unchanged manifest/lockfile and installed packages; otherwise
setup fails with instructions to synchronize online.

Tool setup alone cannot prefetch every project's Gradle/Maven dependency. iOS and
EAS rely on their own dependency managers; prepare their dependencies separately
before attempting disconnected builds.

## Development

`store.jac` owns verification, transfer progress, locking, safe extraction, and
atomic installation. Adapters own platform requirements and invocation. Package
managers continue to resolve their own dependency graphs. The standalone Jac
launcher's embedded-runtime bootstrap stays independent of this package so it can
start before Jac modules are importable.
