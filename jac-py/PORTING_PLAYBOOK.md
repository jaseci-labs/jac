# jac-py module porting playbook (P2 + P3 gates)

Short loop for staging CPython `Modules/*.c` leaf ports under `jac-py/Modules/`.
Object-core conformance (P3) uses a separate Layer-0 replay ratchet; see **§P3** below.

## Loop

1. **Pick a leaf** - prefer header-free or stub-include extracts (see `tools/p1_corpus/includes/`).
2. **Lift** - `jac tool c2jac path/to/module.c -o jac-py/Modules/module.jac` (add `-I` for stubs).
3. **Stage** - keep paired `module.c` + `module.jac` in `jac-py/Modules/`.
4. **Oracle** - add a differential test in `jac-py/tests/` (`cc` on `.c` vs `jac run` on fresh lift; int-line protocol in `lift_oracle.jac`).
5. **Tier-B queue** - `python jac-py/tools/t8_tier_b_queue.py jac-py/Modules/_lifted/.../project.c2jac.report.json`
6. **Burn down** - fix Tier-B sites (idiom pack or hand edit); accept only if oracle/libtest/conformance green and `tier_b_total` drops.
7. **Ratchet** - corpus baseline in `tools/p2_corpus/baseline/`; CI blocks regressions.

## Corpus waves

| Wave | Manifest | Modules | Gate |
|------|-----------|---------|------|
| P1 | `tools/p1_corpus/manifest.json` | 6 (c2jac proving) | `test_p1_corpus_gate.py` |
| P2 | `tools/p2_corpus/manifest.json` | 10 (P1 six + four Python/*.c extracts) | `test_p2_corpus_gate.py` |
| P2 wave 2 | `tools/p2_corpus_wave2/manifest.json` | 4 (`_stat`, `_opcode`, `math_gcd`, `pystrnicmp`) | `test_p2_corpus_waves_gate.py` |
| P2 wave 3 | `tools/p2_corpus_wave3/manifest.json` | 4 (`math_count_bits`, `math_lcm_long`, `strhex_byte`, `pyctype_digit`) | `test_p2_corpus_waves_gate.py` |
| P2 wave 4 | `tools/p2_corpus_wave4/manifest.json` | 4 (`pystricmp`, `pyctype_space`, `pyctype_alpha`, `math_factorial_small`) | `test_p2_corpus_waves_gate.py` |
| P2 wave 5 | `tools/p2_corpus_wave5/manifest.json` | 4 (`pyctype_xdigit`, `pyctype_alnum`, `pyctype_lower`, `math_isqrt_small`) | `test_p2_corpus_waves_gate.py` |
| P2 wave 6 | `tools/p2_corpus_wave6/manifest.json` | 4 (`pyctype_upper`, `pyctype_print`, `pyctype_punct`, `math_pow2_check`) | `test_p2_corpus_waves_gate.py` |
| P2 wave 7 | `tools/p2_corpus_wave7/manifest.json` | 4 (`pyctype_graph`, `pyctype_cntrl`, `pyctype_blank`, `math_ilog2_small`) | `test_p2_corpus_waves_gate.py` |
| P2 wave 8 | `tools/p2_corpus_wave8/manifest.json` | 4 (`math_ctz_small`, `math_clz32_small`, `math_abs_diff`, `math_min_u`) | `test_p2_corpus_waves_gate.py` |
| P2 wave 9 | `tools/p2_corpus_wave9/manifest.json` | 4 (`math_max_u`, `pystr_len_c`, `pystr_find_char`, `pystr_count_char`) | `test_p2_corpus_waves_gate.py` |
| P2 wave 10 | `tools/p2_corpus_wave10/manifest.json` | 4 (`math_gcd_iter`, `math_lcm_u`, `pystr_startswith_c`, `pystr_endswith_c`) | `test_p2_corpus_waves_gate.py` |
| P2 wave 11 | `tools/p2_corpus_wave11/manifest.json` | 4 (`math_pow_mod`, `math_popcount_u`, `pystr_contains_c`, `pystr_cmp_c`) | `test_p2_corpus_waves_gate.py` |

Lift a wave: `python jac-py/tools/lift_p2_corpus.py` (wave 1) or `python jac-py/tools/lift_p2_corpus_wave.py --wave <N>` (waves 2-11). Conformance manifests are gated by `p2_conformance_waves_gate.py`.

## Staged modules (P2 wave 1)

Ten files in `jac-py/Modules/`:

- `rotatingtree`, `pystrcmp`, `mysnprintf`, `getbuildinfo`, `_bisectmodule`, `_heapqmodule` (from P1 fixtures)
- `getplatform`, `getcompiler`, `getcopyright`, `pyfpe` (P2 header-free extracts)

**Wave 2** (four leaf extracts in `jac-py/Modules/`):

- `_stat` (S_IMODE/S_IFMT), `_opcode` (is_valid/has_arg), `math_gcd` (gcd core), `pystrnicmp` (PyOS_mystrnicmp)

**Wave 3** (four leaf extracts in `jac-py/Modules/`):

- `math_count_bits` (popcount), `math_lcm_long` (lcm on long), `strhex_byte` (hex pack), `pyctype_digit` (Py_ISDIGIT-style)

**Wave 4** (four leaf extracts in `jac-py/Modules/`):

- `pystricmp` (PyOS_mystricmp), `pyctype_space` (isspace), `pyctype_alpha` (isalpha), `math_factorial_small` (small n! core)

**Wave 5** (four leaf extracts in `jac-py/Modules/`):

- `pyctype_xdigit` (isxdigit), `pyctype_alnum` (isalnum), `pyctype_lower` (islower), `math_isqrt_small` (unsigned isqrt)

**Wave 6** (four leaf extracts in `jac-py/Modules/`):

- `pyctype_upper` (isupper), `pyctype_print` (isprint), `pyctype_punct` (ispunct), `math_pow2_check` (power-of-two)

**Wave 7** (four leaf extracts in `jac-py/Modules/`):

- `pyctype_graph` (isgraph), `pyctype_cntrl` (iscntrl), `pyctype_blank` (isblank), `math_ilog2_small` (floor log2)

**Wave 8** (four leaf extracts in `jac-py/Modules/`):

- `math_ctz_small` (trailing zeros), `math_clz32_small` (leading zeros), `math_abs_diff`, `math_min_u`

**Wave 9** (four leaf extracts in `jac-py/Modules/`):

- `math_max_u`, `pystr_len_c`, `pystr_find_char`, `pystr_count_char`

**Wave 10** (four leaf extracts in `jac-py/Modules/`):

- `math_gcd_iter`, `math_lcm_u`, `pystr_startswith_c`, `pystr_endswith_c`

**Wave 11** (four leaf extracts in `jac-py/Modules/`):

- `math_pow_mod`, `math_popcount_u`, `pystr_contains_c`, `pystr_cmp_c`

Differential oracles: `test_rotatingtree_oracle.jac`, `test_p2_module_oracles.jac` (wave 1), `test_p2_wave2_module_oracles.jac` (wave 2), `test_p2_wave3_module_oracles.jac` (wave 3), `test_p2_wave4_module_oracles.jac` (wave 4), `test_p2_wave5_module_oracles.jac` (wave 5), `test_p2_wave6_module_oracles.jac` (wave 6), `test_p2_wave7_module_oracles.jac` (wave 7), `test_p2_wave8_module_oracles.jac` (wave 8), `test_p2_wave9_module_oracles.jac` (wave 9), `test_p2_wave10_module_oracles.jac` (wave 10), `test_p2_wave11_module_oracles.jac` (wave 11).

## Dual pipeline - staged oracle vs lifted corpus

Two trees hold `.jac` for the same ten modules:

| Tree | Path | Role |
|------|------|------|
| **Staged oracle** | `jac-py/Modules/{stem}.jac` | Runtime + differential-test truth; may include hand edits and PyObj stubs |
| **Lifted corpus** | `jac-py/Modules/_lifted/p2_corpus_wave1/{stem}.jac` | Fresh c2jac output + T8 tier-B metrics input |

Policy is recorded in `tools/p2_staged_manifest.json` (wave 1), `tools/p2_staged_manifest_wave2.json` (wave 2), `tools/p2_staged_manifest_wave3.json` (wave 3), `tools/p2_staged_manifest_wave4.json` (wave 4), `tools/p2_staged_manifest_wave5.json` (wave 5), `tools/p2_staged_manifest_wave6.json` (wave 6), or `tools/p2_staged_manifest_wave7.json` (wave 7), or `tools/p2_staged_manifest_wave8.json` (wave 8), or `tools/p2_staged_manifest_wave9.json` (wave 9), or `tools/p2_staged_manifest_wave10.json` (wave 10), or `tools/p2_staged_manifest_wave11.json` (wave 11) (`staging`: `lift` | `hand`):

- **`lift`** - staged file must match committed `_lifted` byte-for-byte. Drift means re-lift (`lift_p2_corpus.py`) or accidental edit.
- **`hand`** - staged oracle intentionally differs from fresh lift (`getbuildinfo`, `_bisectmodule`, `_heapqmodule`, `mysnprintf`). Exempt from equality gate; manifest `note` documents sync after burn-down.

**Fresh-lift unsafe path (`getbuildinfo`):** A naive c2jac lift of `getbuildinfo.c` still emits Tier-B sites (e.g. W4201 `char` casts) and lacks hand fixes (`_uchar`, byte-buffer `c_strcpy`/`c_strcat`) needed for correct differential behavior. Until the idiom pack absorbs those patterns, treat **`jac-py/Modules/getbuildinfo.jac` (hand-staged oracle) as canonical** for oracle tests and runtime truth, not the fresh `_lifted` output. T8 burn-down and density metrics run on `_lifted`; after staged oracle edits pass tests, sync with `sync_staged_to_lifted.py` before re-measuring. Do not point `assert_lift_matches_c` at fresh lift for this module (see `test_p2_module_oracles.jac`: staged oracle only).

**Drift gate:** `jac test jac-py/tests/test_p2_staged_sync.jac`

**Sync hand oracle → lifted** (after tier-B burn-down on staged file, before density re-measure):

```bash
python jac-py/tools/sync_staged_to_lifted.py          # wave 1 hand modules
python jac-py/tools/sync_staged_to_lifted.py --wave wave2
python jac-py/tools/sync_staged_to_lifted.py --wave wave3
python jac-py/tools/sync_staged_to_lifted.py --wave wave4
python jac-py/tools/sync_staged_to_lifted.py --wave wave5
python jac-py/tools/sync_staged_to_lifted.py --wave wave6
python jac-py/tools/sync_staged_to_lifted.py --wave wave7
python jac-py/tools/sync_staged_to_lifted.py --wave wave8
python jac-py/tools/sync_staged_to_lifted.py --wave wave9
python jac-py/tools/sync_staged_to_lifted.py --wave wave10
python jac-py/tools/sync_staged_to_lifted.py --wave wave11
python jac-py/tools/sync_staged_to_lifted.py --stem getbuildinfo
python jac-py/tools/sync_staged_to_lifted.py --dry-run
```

Wave 2 is fully lift-staged: `pystrnicmp` via W4201 byte-trunc/int-widen idioms; `_stat` via C octal parsing (W4210) and preserving-integral cast elision (W4201); `_opcode` via sparse designated array init (W4209). Wave 3 is fully lift-staged after the c2jac string-table idiom (char lookup tables → `list[int]` ord values).

Workflow: edit staged oracle → oracle tests green → tier-B burn-down on staged → `sync_staged_to_lifted.py` → re-run `t8_tier_b_queue.py` / density ratchet on updated `_lifted` tree.

## T6 - conformance harness (P2 skeleton)

| Artifact | Role |
|----------|------|
| `jac/tests/jacpy/libtest_runner.jac` | Shared host + staged-Jac + JacPython libtest runner |
| `jac-py/jacpython/layer_p2_libtest.jac` | JacPython ceval libtest harness (shim `platform` from staged ports) |
| `jac-py/tools/p2_libtest_jacpython_bridge.py` | Subprocess bridge for libtest_runner → layer_p2_libtest |
| `tests/run_conformance.jac` | Runs host libtest snippets and staged Jac differential legs; writes `tests/conformance_manifest.json` |
| `tests/test_p2_libtest_partial.jac` | Jac tests for bisect/heapq/platform (host CPython + staged Modules/*.jac differential) |
| `tools/p2_conformance_gate.py` | CI gate: all ten P2 modules have `status: gated` in the manifest |

Gate types in the manifest:

- **oracle** - no stdlib mirror or hand-edited staged lift (`rotatingtree`, `pystrcmp`, `mysnprintf`, `getbuildinfo`, `getcompiler`, `getcopyright`, `pyfpe`); correctness via cc vs jac differential tests
- **libtest** - partial `Lib/test` snippets on **host CPython** (stdlib algorithm smoke) plus optional **staged Jac differential** via `tests.jacpy.libtest_runner` (`jac run` on `Modules/*.jac` when `JACPY_LIBTEST_JAC_DIFF` is enabled) plus optional **JacPython ceval** via `layer_p2_libtest.jac` (`JACPY_LIBTEST_JACPYTHON`, shim `import platform` today). Full stdlib mirror (bisect/heapq) remains future work.

**Jac differential vs JacPython vs host-only smoke:** `tests.jacpy.libtest_runner` always runs the host CPython leg (`expect_stdout`, default `"ok"`). The Jac differential leg composes `Modules/{stem}.jac` + mock preamble + `jac_entry`. The JacPython leg runs the same embedded Python snippet through `exec_code` with shim modules from staged ports. Disable legs with `JACPY_LIBTEST_JAC_DIFF=0` or `JACPY_LIBTEST_JACPYTHON=0`.

Regenerate manifest: `jac test jac-py/tests/run_conformance.jac` (writes `conformance_manifest.json` during collection; fails if host libtest or jac differential legs fail)

P2 exit ratchet: every module in `conformance_manifest.json` must stay `"gated"`; libtest modules must keep `libtest_results[*].failed == 0`, `jac_differential_results[*].failed == 0`, and `jacpython_results[*].failed == 0` when present.

## T8 AI cleanup (MVP)

1. **Queue** - `python jac-py/tools/t8_tier_b_queue.py --emit-queue /tmp/t8.json jac-py/Modules/_lifted/.../project.c2jac.report.json`
2. **Patch** - `python jac-py/tools/t8_driver.py <report> --patcher rule|mock|manual`: automated loop over the queue; `rule` applies known W4201/W4207 fallbacks, `mock` drops sidecar sites only (CI loop smoke, no LLM), `manual` prints prompt payloads.
3. **Accept** - `python jac-py/tools/t8_accept.py --report-before <before> --report-after <after> [--metrics-out metrics.json]`

Acceptance (PLAN §6.8): P2 module oracles pass (`test_p2_module_oracles.jac`, `test_rotatingtree_oracle.jac`), libtest partial suite passes (`test_p2_libtest_partial.jac`), conformance manifest gate passes (`p2_conformance_gate.py`), and `tier_b_total` in the after report is ≤ before (ideally lower). Metrics JSON: `{sites_before, sites_after, sites_fixed, tests_passed, timestamp}`.

Dry-run (acceptance tests + baseline vs current `tier_b_total`, no patch): `python jac-py/tools/t8_tier_b_queue.py --metrics jac-py/Modules/_lifted/.../project.c2jac.report.json`

Unit tests: `python3 -m unittest jac-py/tools/test_t8_accept.py jac-py/tools/test_t8_driver.py`

## P3 - object-core Layer-0 conformance (P3.1a+)

| Artifact | Role |
|----------|------|
| `tools/p3_object_core/manifest.json` | Checked-in passed/failed/errored baselines for int/bool/str/dict/list/tuple Layer-0 replay |
| `tests/test_p3_object_core_gate.jac` | Manifest shape + pending P3.1b/P3.1c slots |
| `jacpython/layer0_replay.jac` | Harvests self-contained `assertEqual` pairs from `Lib/test/test_*.py`; regression tests for replay helpers |
| `jacpython/layer0_replay_p3_gate.jac` | P3.1a/P3.1b manifest ratchet entrypoint (`jac run`, not `jac test`) |
| `tools/p3_object_core/replay_gate.py` | CI driver: runs the ratchet jac on a clean ceval slate |

CI (`jac-py-gates` job, after P2 steps):

```bash
jac test jac-py/tests/test_p3_object_core_gate.jac
jac test jac-py/jacpython/layer0_replay.jac
python jac-py/tools/p3_object_core/replay_gate.py
```

Requires pinned CPython reference (`fetch_cpython_reference.py`, same step as other jac-py gates). **T7** (`jac-py/tests/na_cliffs/t7_gate.py`) stays independent: it gates na-clean emission on `objects.jac`, not Lib/test replay counts.

P3.1b will extend the manifest with Layer-1 baselines (`layer1_replay_source`); P3.1c stages first `Objects/` c2jac extract under `Objects/_lifted/`.
