# CEF QA Implementation Plan

Derived from `jac-desktop/jac_desktop/native/cef/QA.md` gap analysis against the
current plugin state.  Changes are ordered by risk/leverage: correctness gaps first,
then CI coverage, then UX polish.

---

## Change 1 — Extract `cef_platform_bootstrap()` in `cef_dispatch.c`

**File:** `jac-desktop/jac_desktop/native/cef/cef_dispatch.c`

**Why:** The FONTCONFIG_FILE auto-set block (lines 330–336) is buried inside
`cef_dispatch_startup()`.  QA.md §3 requires a single named bootstrap applied
before any `cef_execute_process` call, visible to both the main binary and the
subprocess.  Extracting it also makes it trivial to audit in future.

**What to add:** A new `static void cef_platform_bootstrap(void)` near the top of
the file (after `dispatch_log`, before `on_before_close`).  It calls
`cef_dispatch_get_exe_dir()` internally so it needs no arguments.

```c
static void cef_platform_bootstrap(void) {
    const char* exe_dir = cef_dispatch_get_exe_dir();
    char fonts_conf[4096];
    /* FONTCONFIG_FILE: auto-point at the bundled minimal config to avoid the
     * Arch 48-guessfamily.conf stall inside cef_initialize.  Set before the
     * first cef_execute_process / cef_initialize call. */
    if (!getenv("FONTCONFIG_FILE") && exe_dir[0]) {
        snprintf(fonts_conf, sizeof(fonts_conf), "%s/minimal-fonts.conf",
                 exe_dir);
        if (access(fonts_conf, R_OK) == 0) {
            setenv("FONTCONFIG_FILE", fonts_conf, 0);
            dispatch_log("bootstrap: set FONTCONFIG_FILE");
        }
    }
}
```

**What to change:**
- Replace the inline block in `cef_dispatch_startup()` (lines 330–336) with a
  call to `cef_platform_bootstrap()`.
- Call `cef_platform_bootstrap()` at the top of `cef_dispatch_execute_process()`
  (line 296) as well — before the `cef_execute_process` call — so the env is
  ready even if a caller invokes `execute_process` without `startup` (unlikely
  today, but the ordering contract becomes explicit).

**Resulting call order in main process:**
```
cef_dispatch_execute_process()
  → cef_platform_bootstrap()   ← NEW: env set here
  → cef_execute_process()      ← returns -1 (main process), continues

cef_dispatch_startup()
  → cef_platform_bootstrap()   ← idempotent; already set, no-op
  → cef_initialize()           ← forks subprocess workers; they inherit env
```

---

## Change 2 — Add bootstrap to `cef_subprocess.c`

**File:** `jac-desktop/jac_desktop/native/cef/cef_subprocess.c`

**Why:** The subprocess binary currently has zero bootstrap (lines 21–36).  While
CEF normally spawns it from inside `cef_initialize()` (so it inherits the parent's
env), running the binary from an unset environment (CI container, wrong shell,
manual invocation) silently skips FONTCONFIG_FILE, causing a fontconfig scan stall
in the renderer process that looks like a hang rather than a missing file.

**No new link dependency needed** — duplicate only the ~12 lines of C that matter
(`readlink`, `access`, `setenv`).  `cef_subprocess.c` already has `<unistd.h>`;
add `<stdlib.h>` for `setenv`.

**What to add** (insert before `int main(...)`):

```c
#include <stdlib.h>   /* add to existing includes */

static void subprocess_bootstrap(void) {
    char buf[4096];
    char fonts[4096];
    ssize_t n = readlink("/proc/self/exe", buf, sizeof(buf) - 1);
    if (n <= 0) return;
    buf[n] = '\0';
    char* slash = strrchr(buf, '/');
    if (!slash) return;
    *slash = '\0';  /* buf is now exe_dir */
    if (!getenv("FONTCONFIG_FILE")) {
        snprintf(fonts, sizeof(fonts), "%s/minimal-fonts.conf", buf);
        if (access(fonts, R_OK) == 0)
            setenv("FONTCONFIG_FILE", fonts, 0);
    }
}
```

**What to change in `main()`:** Call `subprocess_bootstrap()` as the very first
statement, before `memset(&g_app, ...)`:

```c
int main(int argc, char** argv) {
    subprocess_bootstrap();   /* ← add this */
    cef_main_args_t args;
    ...
```

---

## Change 3 — Actionable error messages in `cef_dispatch.c`

**File:** `jac-desktop/jac_desktop/native/cef/cef_dispatch.c`

**Why:** QA.md §7 calls for `missing libcef.so` and
`cef_initialize timed out — try JAC_CEF_DISABLE_GPU=1` messages.  Currently a
missing `libcef.so` produces a cryptic dynamic-linker error at binary load time,
and an `cef_initialize` hang produces nothing — the process just hangs silently.

### 3a — Startup watchdog thread

Add a watchdog that fires if `cef_initialize` has not returned within 30 seconds.
This catches fontconfig stalls and GPU hangs before the user gives up.

Add at the top of `cef_dispatch.c` (after existing `#include`s):
```c
#include <pthread.h>
#include <time.h>

static void* startup_watchdog(void* arg) {
    (void)arg;
    struct timespec ts = {30, 0};
    nanosleep(&ts, NULL);
    fprintf(stderr,
        "[cef] cef_initialize timed out after 30s.\n"
        "[cef]   hints: try JAC_CEF_DISABLE_GPU=1, or check FONTCONFIG_FILE\n"
        "[cef]          ldd <binary> | grep 'not found'\n");
    fflush(stderr);
    abort();
    return NULL;
}
```

In `cef_dispatch_startup()`, start the watchdog thread before `cef_initialize` and
cancel/join it after:

```c
/* in cef_dispatch_startup(), replace the bare cef_initialize call: */
pthread_t wdog;
pthread_create(&wdog, NULL, startup_watchdog, NULL);
rc = cef_initialize(...);
pthread_cancel(wdog);
pthread_join(wdog, NULL);
```

Update `build_cef_dispatch.sh` to add `-lpthread` to the link line.

### 3b — Missing `libcef.so` diagnostic

Add a `__attribute__((constructor))` function in `cef_dispatch.c` that uses
`dlopen(NULL, ...)` to check if `cef_initialize` is resolvable, and prints a
clear message if not.  This fires at `.so` load time, before any Jac code runs:

```c
__attribute__((constructor))
static void check_libcef_loaded(void) {
    void* sym = dlsym(RTLD_DEFAULT, "cef_initialize");
    if (!sym) {
        fprintf(stderr,
            "[cef] libcef.so not loaded — is it next to the binary?\n"
            "[cef]   run: ldd <binary> | grep cef\n");
        fflush(stderr);
        /* Do not abort here — let the subsequent NULL-dereference produce a
         * clear crash with the message above already on stderr. */
    }
}
```

`dlsym` is already used in the file (`#include <dlfcn.h>` present, line 16).  No
new includes needed.

---

## Change 4 — CI build + bundle audit job

**File:** `.github/workflows/test-jaseci.yml`

**Why:** QA.md §2 requires a CI gate.  Downloading the full 1.4 GB CEF distribution
on every PR is expensive; split into two tiers:

- **Tier 1 (every PR, cheap):** compile the dispatch shim + subprocess binary from
  source, run `ldd` and file-existence checks.  No CEF runtime download.
- **Tier 2 (nightly / manual, expensive):** download CEF, build the full cef-smoke
  app, run headless with Xvfb + timeout.  Catches init hangs and missing PAK files.

### Tier 1 — compile + ldd audit (add to `test-jaseci.yml`)

Add a new job after `test-desktop-native`:

```yaml
test-desktop-cef-build:
  runs-on: blacksmith-4vcpu-ubuntu-2404
  steps:
  - uses: actions/checkout@v5
    with:
      submodules: true

  - name: Set up Python 3.12
    uses: actions/setup-python@v5
    with:
      python-version: 3.12

  - name: Install toolchain
    run: |
      python -m pip install --upgrade pip
      pip install -e jac
      pip install -e jac-desktop

  - name: Install C build deps
    run: sudo apt-get install -y gcc libpthread-stubs0-dev

  - name: Download CEF headers only (no runtime)
    working-directory: jac-desktop/jac_desktop/native/cef
    run: |
      # fetch_libcef.sh downloads the full dist; for the build-only audit we
      # only need the headers.  The script checks for cef_headers/ first.
      bash fetch_libcef.sh --headers-only 2>/dev/null || bash fetch_libcef.sh
      test -d cef_headers/include/capi

  - name: Build dispatch shim and subprocess binary
    working-directory: jac-desktop/jac_desktop/native/cef
    run: |
      bash build_cef_dispatch.sh
      bash build_cef_subprocess.sh

  - name: Verify shared-object exports
    working-directory: jac-desktop/jac_desktop/native/cef
    run: |
      # Check the symbols CI cares about exist
      nm -D libcef_dispatch.so | grep -q cef_dispatch_startup
      nm -D libcef_dispatch.so | grep -q cef_dispatch_execute_process
      nm -D libcef_dispatch.so | grep -q cef_platform_bootstrap  # new export

  - name: Check RPATH
    working-directory: jac-desktop/jac_desktop/native/cef
    run: |
      readelf -d libcef_dispatch.so | grep -q 'RPATH.*\$ORIGIN'
      readelf -d cef-subprocess     | grep -q 'RPATH.*\$ORIGIN'

  - name: ldd audit (no missing deps against libc + libcef stub)
    working-directory: jac-desktop/jac_desktop/native/cef
    run: |
      # With libcef.so absent, ldd will report it missing — that is expected.
      # The audit checks that no *other* unexpected dep is missing.
      ldd libcef_dispatch.so 2>&1 | grep 'not found' | grep -v libcef || true
      MISSING=$(ldd libcef_dispatch.so 2>&1 | grep 'not found' | grep -v libcef)
      [ -z "$MISSING" ] || (echo "Unexpected missing deps: $MISSING" && exit 1)
```

### Tier 2 — headless runtime smoke (new file `.github/workflows/test-cef-smoke.yml`)

Create a separate workflow triggered `on: [workflow_dispatch, schedule]`
(nightly at 03:00 UTC) so it does not block PRs:

```yaml
name: CEF headless smoke
on:
  schedule:
    - cron: '0 3 * * *'
  workflow_dispatch:

jobs:
  smoke:
    runs-on: blacksmith-4vcpu-ubuntu-2404
    steps:
    - uses: actions/checkout@v5
      with:
        submodules: true

    - name: Set up Python 3.12
      uses: actions/setup-python@v5
      with:
        python-version: 3.12

    - name: Install toolchain + display deps
      run: |
        sudo apt-get update
        sudo apt-get install -y xvfb libnss3 libatk1.0-0 libatk-bridge2.0-0 \
          libcups2 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 \
          libasound2
        python -m pip install --upgrade pip
        pip install -e jac -e jac-client -e jac-desktop

    - name: Build cef-smoke example
      run: |
        cd jac-client/jac_client/examples/cef-smoke
        jac build --client desktop-cef

    - name: Bundle existence audit
      working-directory: jac-client/jac_client/examples/cef-smoke
      run: |
        BUNDLE=.jac/client/desktop-cef/cef-smoke
        test -f $BUNDLE/libcef.so
        test -f $BUNDLE/cef-subprocess
        test -f $BUNDLE/minimal-fonts.conf
        test -f $BUNDLE/icudtl.dat
        test -d $BUNDLE/locales
        ldd $BUNDLE/cef-smoke | grep 'not found' && exit 1 || true

    - name: Headless smoke with timeout (X11)
      working-directory: jac-client/jac_client/examples/cef-smoke/.jac/client/desktop-cef/cef-smoke
      run: |
        Xvfb :99 -screen 0 1280x720x24 &
        XVFB_PID=$!
        DISPLAY=:99 \
        FONTCONFIG_FILE=$PWD/minimal-fonts.conf \
        JAC_CEF_DISABLE_GPU=1 \
        OZONE_PLATFORM=x11 \
        timeout 30s ./cef-smoke 2>&1 | tee /tmp/cef-smoke.log &
        SMOKE_PID=$!
        sleep 10
        # Assert cef_initialize succeeded
        grep -q "startup: cef_initialize ok" /tmp/cef-smoke.log \
          || (cat /tmp/cef-smoke.log && exit 1)
        kill $SMOKE_PID $XVFB_PID 2>/dev/null || true

    - name: Upload logs on failure
      if: failure()
      uses: actions/upload-artifact@v4
      with:
        name: cef-smoke-logs
        path: /tmp/cef-smoke.log
```

**Note on the grep pattern:** The actual message in `cef_dispatch.c` line 345 is
`"startup: cef_initialize ok"` (not `"cef_initialize ok"` as shown in QA.md).
The CI grep above uses the correct string.

---

## Change 5 — `fetch_libcef.sh` `--headers-only` flag (optional, supports Change 4)

**File:** `jac-desktop/jac_desktop/native/cef/fetch_libcef.sh`

**Why:** Tier 1 CI only needs the CEF C headers to compile the shim.  The full
distribution is ~800 MB.  Adding a `--headers-only` flag that downloads and unpacks
only `cef_headers/` saves ~5 minutes of CI bandwidth.

This is optional — the Tier 1 job can fall back to a full download if the flag
doesn't exist yet.  Implement after Changes 1–4 are merged.

---

## Summary table

| # | File(s) changed | What | Why |
|---|---|---|---|
| 1 | `cef_dispatch.c` | Extract `cef_platform_bootstrap()` static fn; call from both `execute_process` and `startup` | Centralizes env bootstrap; makes ordering auditable |
| 2 | `cef_subprocess.c` | Add inline `subprocess_bootstrap()` before `cef_execute_process` | Robust in containers / manual invocations where parent env is unset |
| 3a | `cef_dispatch.c`, `build_cef_dispatch.sh` | Startup watchdog pthread; emits GPU hint on 30s timeout | Catches cef_initialize hangs in CI and user reports |
| 3b | `cef_dispatch.c` | `__attribute__((constructor))` checks `cef_initialize` symbol at load | Turns cryptic linker crash into `missing libcef.so` message |
| 4 | `test-jaseci.yml` | New `test-desktop-cef-build` job: compile + symbol check + ldd audit | Catches shim regressions on every PR without CEF download |
| 4 | `.github/workflows/test-cef-smoke.yml` | New nightly headless smoke: build + bundle audit + Xvfb + timeout | Catches init hangs and missing PAK files before releases |
| 5 | `fetch_libcef.sh` | `--headers-only` flag | CI build tier can skip 800 MB download |

**Implementation order:** 1 → 2 → 3a → 3b → 4 → 5
Changes 1 and 2 are pure correctness; 3a/3b are independent of each other and of
1/2; 4 depends on 1–3 being merged first so the CI checks the improved binary.
