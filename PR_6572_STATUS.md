# PR #6572 — CEF desktop target: review & cleanup status

_Branch: `worktree-probe` · last updated 2026-06-14_

## Verdict

A **working prototype carrying real hacks**, not a clean long-term fix. The CEF
binding itself is mostly necessary FFI glue; the problems are what it leaked into
the **shared native compiler/linker**, all traceable to one root cause: **clib
(C-FFI) import declarations are skipped by the type checker**
(`type_checker_pass.impl.jac:549`, `if nd.clib_decls { return; }`), so their
annotations reach native codegen untyped and every downstream fallback exists to
paper over that.

---

## Done — cleanup applied to the working tree

Net **−305 / +131** across 8 files (plus a staged file delete + add). None of
this changes compiler *behavior*; it removes dead code and corrects packaging/docs.

### Dead-code removal (orphaned CRT-injection path, abandoned mid-PR)
- `nacompile.impl.jac` — removed the `JAC_CRT_OBJECTS` / `JAC_EMIT_OBJECT_PATH`
  env-var hooks (both read but **set nowhere** in the repo) and the hardcoded
  `close`-export + `libdl.so.2` append.
- `elf_linker.jac` / `elf_linker.impl.jac` — removed the `crt_objects` param and
  the entire 184-line `_merge_crt_object` function (no remaining callers).
- `close_preload.c` — deleted (staged); its replacement is `cef_dispatch.na.jac`
  + the DT_NEEDED ordering. Updated the stale lineage comment in
  `cef_dispatch.na.jac`.
- **Kept** the genuinely-general `_find_patch_target` fix (`linker_common`) and
  the no-op-when-empty `exec_exports` block.

### Packaging / docs
- `jac.toml` — fixed a real packaging bug: the manifest shipped the nonexistent
  `cef_dispatch.c` and the dead `close_preload.c`, and was missing
  `cef_dispatch.na.jac`, `cef_subprocess.na.jac`, `build_cef_subprocess.sh`.
  A pip-installed `desktop-cef` build would have failed.
- `.gitignore` — added the real build artifacts (`cef_dispatch.so`, `*_noclose.so`,
  `libcef_shim.so`, `cef-subprocess`, `DawnCache/`, `GPUCache/`).
- `minimal-fonts.conf` — was shipped-but-untracked; now tracked (staged add) so
  the wheel build doesn't break.
- `README.md` — full rewrite; it documented the *removed* `cef_shim.c`
  architecture. Now describes the actual `libcef.so` + `libcef_dispatch.so` +
  `cef-subprocess` pipeline and the `close()`/RTLD_NEXT-via-NEEDED-ordering
  mechanism.

### Observability fix (cosmetic, not a behavior change)
- `na_ir_gen_pass.impl/types.impl.jac` — the `_lower_type` docstring falsely
  claimed a missing `.type` is a hard E9002 ICE; the code actually defaults to
  i64 silently. Rewrote the docstring to describe the real behavior and the
  soundness hole, and **restored the debug breadcrumb** the PR had deleted at
  both silent-i64 fallbacks. **No control-flow change** — an unrecognized clib
  type still becomes i64; it is now just honest in the docs and visible in logs.

---

## Filed upstream — NOT implemented

These are the substantive compiler fixes. They were filed rather than done,
because they are type-checker surgery (explicitly scoped out earlier) and cannot
be runtime-verified in this worktree.

| Issue | What | Status |
|-------|------|--------|
| **#6676** | clib import decls bypass the type checker → unstamped C-FFI types silently default to signed i64 (root cause; fixing it retires the `_resolve_primitive_name` / i64-catch-all / signedness-guessing chain) | filed, not implemented |
| **#6353** (comment addendum) | integer comparisons are unconditionally signed (`sext` + `icmp_signed`); unsigned C operands mis-widen and mis-order. **Not blocking** CEF — latent. Depends on #6676. | filed, not implemented |

---

## Flagged for maintainer decision — deliberately NOT changed

Shared-compiler behavior changes the PR makes to **all** native binaries:

1. **Silent i64 type fallback (#1)** — see #6676. The PR also deleted the debug
   log (now restored). Behavior unchanged pending the type-checker fix.
2. **DT_NEEDED reorder (#6)** — `nacompile.impl.jac:468-478` forces libc/libm
   last for every Linux native binary so libcef's `.init_array`
   `dlsym(RTLD_NEXT,"close")` resolves. Correct mechanism (replaced an uglier
   LD_PRELOAD hack) but global and unscoped, with no test asserting the order.
   Left as-is.
3. **Unconditional `sext` in comparisons (#7)** — see #6353 addendum. Necessary
   width-harmonization, but signed-only. Latent, not blocking. Left as-is.

These were left untouched per the earlier "flag for maintainer decision" scope.

---

## CEF-local follow-ups (not addressed)

- **CEF-version landmine:** hand-coded struct offsets (`javascript@204`,
  `local_storage@236`, 440-byte settings) in `cef.na.jac` / `cef_dispatch.na.jac`
  with no build-time `offsetof`/`sizeof` check → silent corruption on a CEF bump.
- **Triplicated, divergent glue:** the two `_on_before_cmdline` policies in
  `cef.na.jac` vs `cef_dispatch.na.jac` disagree (zygote/sandbox/ozone).
- **`fetch_libcef.sh`** is a major-version floor, not an exact pin; TOFU SHA-1.
- **CI coverage:** the CEF build/smoke tests are nightly-only, not on PRs.
- **PR description** still references the removed `cef_shim.c` / `libcef_shim.so`.
- **`QA.md`** is linked from the README but untracked — decide whether to commit
  it or drop the link.

---

## Verification caveat

The active local `jac` resolves jaclang to `/home/jac/repos/jac-svelte`, **not
this worktree**, so the `.jac` compiler edits cannot be runtime-tested locally.
The applied edits are dead-code removal + doc/log only (low risk), but **CI is
the gate** — run the native suite + `desktop-cef` build/smoke jobs before merge.

## Nothing committed

All changes are working-tree / staged only. No commit or push has been made.
