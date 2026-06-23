# CEF desktop target: proactive QA

You cannot enumerate every issue upfront: Chromium on Linux is a combinatorial
mess. This guide maps **categories** of failure, **automates the predictable
ones**, and defines a **small test matrix** so most failures surface in CI
before users hit them.

See also: `jac/examples/notes-app/README.md` for smoke-test
troubleshooting (fontconfig, GPU, libpython).

---

## 1. Failure-mode checklist (categories, not individual bugs)

Maintain this table as a living doc. New bugs usually land in one bucket; the
checklist tells you **where to look**, not every specific bug.

| Category | Examples already seen in this repo |
|----------|-----------------------------------|
| **Process model** | subprocess binary missing, wrong `browser_subprocess_path`, init order |
| **Dynamic linking** | `libcef.so`, `libpython` version mismatch, wrong rpath |
| **Linux fonts** | Fontconfig stall/hang (Arch `48-guessfamily.conf`) |
| **Display / GPU** | Wayland vs X11, headless hang in `cef_initialize`, software GL |
| **Sandbox** | `chrome-sandbox` setuid, `--no-sandbox` fallback |
| **CEF bundle completeness** | missing `.pak`, `icudtl.dat`, locales, `cef-subprocess` |
| **Security / CSP** | stricter than WebKit; breaks OAuth or inline scripts |
| **Engine differences** | WebGL, `localStorage`, cookies, service workers vs native webview |
| **Packaging** | ~1.4 GB staging, path assumptions, cwd at launch |
| **Platform** | macOS gatekeeper; Windows WebView2 (native target only, not CEF) |

When triaging a report, ask: which row is it?

---

## 2. Automate what you can in CI

Compile-only validation is not enough. Push toward runtime smoke with timeouts.

### Build-time gates

```bash
# Staged bundle audit (run from staged app dir)
test -f libcef.so && test -f cef-subprocess && test -f minimal-fonts.conf
ldd ./notes-app | grep 'not found' && exit 1
```

### Runtime smoke (headless, with timeout)

```bash
FONTCONFIG_FILE=$PWD/minimal-fonts.conf \
JAC_CEF_DISABLE_GPU=1 \
OZONE_PLATFORM=x11 \
timeout 30s ./notes-app
# Assert stderr contains "cef_initialize ok" within N seconds
```

If init **hangs**, `timeout` kills the process and CI fails; that catches
fontconfig/GPU stalls before users report them.

### CI matrix (small matrix pays off)

| Runner / condition | Why |
|--------------------|-----|
| `ubuntu-latest` + Xvfb | baseline headless Linux |
| Arch or image with broken fontconfig | font scan stalls |
| `OZONE_PLATFORM=x11` vs `wayland` | display stack differences |

### Existing harnesses

Run in CI, not only locally:

- `test_cef_init.c`
- `test_cef_args.c`
- `jac/examples/notes-app/`

---

## 3. Upstream boot-requirements audit (one-time, then maintain)

Do not clone Electron as a submodule. One-time grep audit; output a maintained
**platform bootstrap spec** (`cef_platform_bootstrap()`): env vars and flags
applied **before any** `cef_execute_process`, in the main binary **and**
`cef-subprocess`.

| Source | Grep for |
|--------|----------|
| Electron `shell/` | `FONTCONFIG`, `OZONE`, `setenv`, `disable-gpu`, `no-sandbox` |
| CEF `cefsimple` / `cefclient` | init order, `cef_execute_process`, settings |
| Chromium `chrome_switches.cc` | Linux-specific switches |
| `cef_dispatch.c` | compare what we set vs upstream |

Electron is a **checklist of what packaged Chromium expects on Linux**, not a
template for CEF + `nacompile` integration.

### Bootstrap must cover

- `FONTCONFIG_FILE` → bundled `minimal-fonts.conf` (before first CEF call)
- `OZONE_PLATFORM` / Wayland vs X11 when auto-detect fails
- GPU fallbacks: `JAC_CEF_DISABLE_GPU`, `LIBGL_ALWAYS_SOFTWARE`, `GALLIUM_DRIVER`
- Sandbox: `chrome-sandbox` setuid or explicit `--no-sandbox` for dev

Apply the same bootstrap in:

1. Main host (`cef_dispatch_execute_process` / earliest entry)
2. `cef_subprocess.c` (before `cef_execute_process`)
3. `CefDesktopTarget.start()` env when launching via `jac start`

---

## 4. Compare against a known-good baseline

Use **CEF's `cefsimple`** (same pinned CEF version) on the same machine:

```text
cefsimple works, notes-app fails  → our integration (init order, subprocess, env)
both fail                           → environment / GPU / font issue
```

Same CEF version is critical. Diff init order, subprocess path, and env, not
random Chromium docs.

---

## 5. Pre-ship manual matrix (~15 minutes)

Run before a release or any large CEF version bump. Log pass/fail and time-to-window.
Slow init (>10s) is a bug even when it does not hang.

| Scenario | Command / condition |
|----------|---------------------|
| Clean launch | default, from staged bundle dir |
| No `FONTCONFIG_FILE` | omit env (Arch fontconfig path) |
| Wayland session | `OZONE_PLATFORM=wayland` |
| X11 | `OZONE_PLATFORM=x11` |
| No GPU / VM | `JAC_CEF_DISABLE_GPU=1`, software GL env |
| Wrong cwd | run from parent dir, not bundle dir |
| Fresh build | delete `.jac/client/desktop-cef/<app>`, rebuild |
| Python mismatch | build vs run on different `libpython` versions |

---

## 6. Native vs CEF parity tests

Users pick `engine = "cef"` for **consistency**. Test the same SPA on both targets:

- OAuth flow (`/__jac/oauth/*`)
- `localStorage` persistence (stable port)
- `window.__JAC_DESKTOP__`, `window.__JAC_BROKER__`
- One WebGL or CSS feature the product cares about

Document intentional differences. Gaps here are product bugs, not environment bugs.

---

## 7. What you will not catch in advance

- Random GPU driver bugs
- Exotic distros and corporate TLS interception
- Users who run the binary without the full staged bundle beside it

Mitigation: good `[cef]` stderr logging, this doc, and actionable errors
(`missing libcef.so`, `cef_initialize timed out; try JAC_CEF_DISABLE_GPU=1`).

---

## Minimal stack (priority order)

1. **This checklist**: category table above; extend when new bugs appear
2. **CI**: build + `timeout 30s` headless smoke + `ldd` audit
3. **`cef_platform_bootstrap()`**: single early init, main + subprocess
4. **Release manual matrix**: section 5 before tagging
5. **cefsimple sanity**: same CEF version when debugging weird Linux init

Highest leverage next steps for the repo:

- CI headless smoke with timeout
- Bootstrap env applied before the first `cef_execute_process` in both binaries
