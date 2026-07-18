discipline with unusually good SAFETY comments on the ouroboros wrappers; and the old dev-side loader was actually deleted when it moved in-compiler, not forked. The jac add rust: CLI correctly reuses the existing EcosystemProvider seam rather than duplicating package machinery.

Recommended order (replacing REMAINING.md's "Suggested order")

1. Pre-merge: gate the callback heuristic on known bridge callees; fix the identity-lambda double-free, ctor overwrite, null-handle guards, and identifier sanitization; wire the dark tests into CI.
2. Immediately post-merge: adopt the Lanes Plan (`bridges/reference/FFI-LANES-PLAN.md`, decided in Claude session `c48344d3` -- serde wide lane + py-interop tier, replaces cancelled recursive type-table approach), freeze v1 tags, and do Lanes Phase 0 (serde wide lane: TAG_WIDE + msgpack encoder/decoder pair per loader) before seed-crate expansion.
3. Then seed crates + overlays on the recursive model, where each new crate exercises rules instead of multiplying hand edits.
4. Never widen scope past the interop value language -- PLAN.md's principle zero ("expose a Jac-compatible component interface, not Rust") is the best decision in the project; the pressure to "support all of Rust" should be answered with overlays and skips, not type-system features.

Minor/hygiene findings (REMAINING.md committed into the PR, docs overstating v1 marshaling support, registry fetch without timeout, missing-sha256 silent accept, _bundle_binary ignoring copy failures, etc.) are in the agents' reports and are all cheap cleanups -- I can dump the full itemized list or start fixing any tier of this if you want.
