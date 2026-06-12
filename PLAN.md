# Plan: Replace `jac ai --tui` Polling with the `--ui` Streaming Model

## Goal

Make `jac ai --tui` reuse the same live agent transport model as `jac ai --ui`, so the TUI:

- stops relying on 200ms HTTP polling
- stops crashing on long/stalled poll requests
- behaves closer to `--ui` for event flow and responsiveness
- keeps using the same backend agent server endpoints already used by `--ui`

## Problem Summary

Current state:

- `jac ai --ui` uses `agent_stream` (SSE) and is stable.
- `jac ai --tui` uses repeated `agent_poll` fetches every 200ms.
- Each TUI fetch has `AbortSignal.timeout(30000)`.
- If a poll stalls long enough, Node throws `DOMException [TimeoutError]` and the Ink client dies.
- The TUI currently reuses the `--ui` backend, but **not** the `--ui` client transport.

Observed evidence:

- `jac ai --ui` responds quickly and does not fail.
- `jac ai --tui` fails after a prolonged wait, likely around 30s.
- Even a trivial prompt like `hi` can trigger the failure.
- This strongly implicates the TUI polling transport, not the model/backend.

## Root-Cause Hypothesis

Primary hypothesis:

1. The Ink TUI starts overlapping poll requests every 200ms.
2. One or more requests stop completing in time.
3. A request reaches the 30s abort timeout.
4. The resulting JS `DOMException` escapes the current runtime/catch path.
5. Node crashes the TUI process.

Secondary issue:

- The TUI presentation path is not aligned with the `--ui` stream-driven client, so the user sees a different feel/flow even though the backend is shared.

## Decision

Adopt **HTTP + SSE** for the TUI, reusing `agent_stream`, instead of polling `agent_poll`.

### Why SSE

- Already exists and works in `--ui`.
- Preserves backend reuse.
- Eliminates overlapping poll request pressure.
- Matches the web UI’s event semantics and live token updates.
- Lower-risk than inventing a new WebSocket or direct IPC transport.

## Transport Options Comparison

| Option | Reuse of existing `--ui` path | Complexity | Risk | Notes |
|---|---:|---:|---:|---|
| Keep polling, harden it | Low | Low-Med | Med-High | Smallest patch, but preserves the wrong architecture. |
| **Switch TUI to SSE** | **High** | **Med** | **Low-Med** | Best parity with `--ui`; recommended. |
| WebSocket | Low | High | Med | No existing path; larger protocol change. |
| Direct local IPC | Low-Med | High | Med | Good local architecture, but diverges from `--ui` reuse goal. |

## Target Architecture

### Before

- TUI launcher starts sidecar server.
- Ink runtime repeatedly calls:
  - `agent_poll`
  - `agent_send`
  - `agent_reset`
  - `agent_stop`
  - settings/graph endpoints
- Live updates come from polling snapshots.

### After

- TUI launcher still starts the same sidecar server.
- Ink runtime opens one long-lived stream to `agent_stream`.
- TUI applies:
  - one initial full snapshot
  - incremental event deltas from stream
  - ledger/state updates from stream frames
- Non-stream actions remain request/response RPCs:
  - `agent_send`
  - `agent_reset`
  - `agent_stop`
  - `agent_settings`
  - `agent_apply_settings`
  - `agent_graph`

### End-state principle

`--tui` should differ from `--ui` mainly in **render target** (Ink vs DOM), not in **live transport semantics**.

## Scope

### In scope

- Replace poll loop with SSE stream loop in Ink TUI.
- Reuse `agent_stream` semantics already used by `--ui`.
- Align transcript/event application logic with the web UI where practical.
- Harden disconnect/reconnect/error handling.
- Add tests for stream boot, reconnect, and no-crash behavior.

### Out of scope

- Replacing the sidecar server with a non-HTTP transport.
- Full UI parity in layout/styling.
- Rewriting the backend event bus.
- Adding new protocol concepts unless strictly needed.

## Workstreams

## 1. Confirm and document the current failure mode

### Objective

Capture enough evidence to prove the polling path is the failure source and establish regression checks.

### Tasks

- Reproduce `jac ai --tui` failure with current polling runtime.
- Verify failure timing roughly matches `AbortSignal.timeout(30000)`.
- Confirm `jac ai --ui` remains stable under the same prompt/session.
- Confirm the sidecar server survives when the Ink client crashes.
- Record baseline behavior for transcript/activity differences between `--ui` and `--tui`.

### Deliverables

- Short diagnosis note in PR/issue description.
- Repro steps and expected failure signature.

## 2. Port the web UI stream model into the Ink TUI

### Objective

Replace polling with a stream loop modeled directly on `jac/jaclang/cli/ai_ui/frontend.cl.jac`.

### Current files

- `jac-super/jac_super/ai_tui_ink/runtime.cl.jac`
- `jac-super/jac_super/ai_tui_ink/.jac/tui/jac_builtin_runtime.mjs` (generated)
- `jac/jaclang/cli/ai_ui/frontend.cl.jac`

### Planned changes

- Remove `startPolling()` / `stopPolling()` as primary live-update path.
- Add a `streamLoop()` equivalent for Ink.
- Open `POST /function/agent_stream` with a long-lived fetch.
- Read SSE frames from `resp.body.getReader()`.
- Parse `data: ...` frames exactly like the web UI does.
- Apply:
  - full snapshot frames (`full`)
  - delta event frames (`ev`)
  - ledger/state-only frames
  - heartbeats
- Keep graph/settings initial fetches as one-shot RPCs.

### Notes

- Prefer copying/adapting the web UI stream parser instead of inventing a second stream format.
- If Jac/Ink runtime differences require small wrappers, keep them local and documented.

## 3. Unify message application semantics with `--ui`

### Objective

Reduce behavior drift between TUI and UI by reusing the same event-application model.

### Current issue

The TUI currently transforms poll snapshots into its own `displayEvents` rows. The web UI instead upserts stream events by id and derives panels from the shared feed.

### Planned changes

- Introduce an `applyMsg()` style function in the Ink client.
- Maintain one canonical in-memory event list keyed by event id.
- Upsert stream deltas in place.
- Preserve ledger/status/path/model/needs_key from stream state frames.
- Derive transcript/activity panels from the canonical event list, not from polling-specific transformations.

### Result

- Less transport-specific logic.
- Same source event semantics as `--ui`.
- Easier debugging and parity maintenance.

## 4. Simplify or remove polling-only state machinery

### Objective

Delete code that exists only to support snapshot polling and overlapping request behavior.

### Candidates

- `_timer`
- `poll()` as a live update loop primitive
- `startPolling()` / `stopPolling()`
- `processPollEvents()` if superseded by stream upsert logic
- polling-specific feed state assumptions (`feedSinceId`, snapshot replacement patterns)

### Rule

Retain only what still serves Ink rendering; remove transport-era workarounds.

## 5. Harden stream lifecycle and failure handling

### Objective

Ensure the TUI degrades gracefully if the stream drops or the server restarts.

### Planned behavior

- Open stream on mount.
- Reconnect after disconnect with bounded backoff.
- Abort stream cleanly on unmount/exit.
- Treat server restart as recoverable.
- Never crash on native JS transport exceptions.

### Specific safeguards

- Catch real JS/Node exceptions, not only Jac runtime exceptions.
- Validate `resp.body` before calling `getReader()`.
- Handle malformed/partial SSE frame chunks safely.
- Keep reconnect logic single-flight; do not open multiple streams concurrently.
- Ensure `/stop`, `/reset`, `/send` do not race into duplicate stream setup.

## 6. Keep one-shot RPC endpoints for command actions

### Objective

Use streaming only for live feed/state; keep command endpoints simple.

### Endpoints that remain request/response

- `agent_send`
- `agent_reset`
- `agent_stop`
- `agent_settings`
- `agent_apply_settings`
- `agent_graph`
- optional aux endpoints (`agent_guides`, `agent_mcp_status`) as they mature

### Notes

- These calls should not inherit the 30s blanket timeout behavior that killed polling.
- Timeouts, if any, should be endpoint-specific and intentional.

## 7. Align transcript behavior with product intent

### Objective

Decide whether the TUI should feel like the `--ui` conversation-first view or intentionally show more raw phase activity.

### Recommendation

Adopt this principle:

- **canonical stream feed is shared**
- transcript can be **conversation-first**
- separate panels can show **phase/tool/reasoning** details

### Concrete plan

- Keep the event feed canonical and shared.
- Derive a conversation view similar to `--ui`:
  - mostly `user`, `answer`, `system`, `error`
- Keep activity/phase panels for deeper visibility.
- Do not let transport implementation dictate UX semantics.

## 8. Testing plan

### Unit-ish / component-level

- Stream parser handles:
  - full snapshot frame
  - delta event frame
  - heartbeat frame
  - partial chunk boundaries
  - reconnect after EOF
- Event upsert logic replaces same-id events correctly.
- Ledger/state-only frames update side panels without corrupting events.

### Integration

- Sidecar boots and `agent_stream` responds.
- Ink TUI mounts, connects, receives initial full snapshot.
- `agent_send("hi")` yields streamed response without polling.
- Long idle session does not crash after 30s.
- Server restart/disconnect triggers reconnect instead of process death.
- `jac ai --ui` behavior remains unchanged.

### Regression tests

- No overlapping live-update requests.
- No uncaught `DOMException [TimeoutError]` during normal idle/running usage.
- TUI stays alive longer than prior failure window.

## 9. Rollout plan

### Phase A: Safe migration scaffolding

- Add stream client code alongside existing polling code.
- Hide behind a temporary runtime flag if useful.
- Use diagnostics/logging during development.

### Phase B: Make stream path default

- Switch Ink runtime to stream-first live updates.
- Retain polling code only as a short-lived fallback if necessary.

### Phase C: Remove poll path

- Delete obsolete polling loop/state.
- Remove generic 30s timeout assumptions from live update path.
- Update docs/comments to reflect stream architecture.

## File-by-file implementation map

### `jac-super/jac_super/ai_tui_ink/runtime.cl.jac`

Primary change site.

Planned edits:

- add `streamLoop()` modeled after `jac/jaclang/cli/ai_ui/frontend.cl.jac`
- add `applyMsg()`/event upsert logic
- remove polling timer as primary update mechanism
- clean up polling-specific state
- harden exception handling around fetch/reader/JSON parsing

### `jac-super/jac_super/ai_agent/impl/run_tui_session.impl.jac`

Likely small/no architectural change.

Possible edits:

- optional env flag to enable stream debug logging
- optional startup diagnostics around sidecar readiness
- no transport redesign needed here unless diagnostics reveal a launcher issue

### `jac-super/jac_super/ai_tui_server/main.jac`

Expected minimal/no change.

Reason:

- already re-exports `agent_stream`
- backend reuse goal is already satisfied here

### `jac/jaclang/cli/ai_ui/frontend.cl.jac`

Reference implementation only.

Use as source of truth for:

- stream loop structure
- SSE parsing behavior
- state application semantics

### Tests/docs

- add/update tests for TUI stream behavior
- document architecture change from polling to streaming

## Acceptance Criteria

The work is complete when all are true:

1. `jac ai --tui` no longer uses periodic `agent_poll` as its live update path.
2. `jac ai --tui` consumes `agent_stream` successfully.
3. A trivial prompt like `hi` works reliably.
4. Idle or long-running sessions do not die after ~30s.
5. If the stream disconnects, the TUI reconnects or degrades gracefully instead of crashing.
6. The TUI’s event flow feels materially closer to `--ui`.
7. `jac ai --ui` remains unchanged and stable.

## Risks and Mitigations

### Risk: Ink/Node stream APIs behave differently than browser runtime

Mitigation:

- port the existing parser with minimal semantic drift
- validate `ReadableStream` assumptions in Node 26
- add parser-focused tests around chunk boundaries and EOF

### Risk: Jac-to-Ink compilation mishandles stream code patterns

Mitigation:

- keep stream code structurally close to already working web UI logic
- isolate any Ink-specific polyfills/helpers
- inspect compiled JS if runtime behavior diverges

### Risk: TUI still needs some snapshot fetches

Mitigation:

- retain one-shot RPCs for graph/settings/commands
- use stream only for live feed/state

### Risk: Different transcript feel remains after transport swap

Mitigation:

- explicitly define transcript derivation rules
- separate transport parity from display parity
- tune presentation after stream parity is achieved

## Non-goals for the first pass

- WebSocket migration
- direct stdio/IPC transport
- shared package extraction between web UI and Ink UI
- complete UI component parity

## Recommended Execution Order

1. Reproduce and capture baseline failure.
2. Port `agent_stream` loop into Ink runtime.
3. Add shared-style `applyMsg()`/upsert semantics.
4. Switch live updates from polling to stream.
5. Harden error/reconnect behavior.
6. Verify `hi`, idle >30s, long-running response, stop/reset.
7. Remove obsolete polling machinery.
8. Add tests and documentation.

## Concrete Implementation Checklist

### A. `jac-super/jac_super/ai_tui_ink/runtime.cl.jac`

#### A1. Transport primitives

- [ ] **Keep** `agent_fetch()` for request/response endpoints.
- [ ] **Remove live dependence on** `poll()`.
- [ ] **Add** `streamLoop(setters: any)` modeled after `jac/jaclang/cli/ai_ui/frontend.cl.jac:streamLoop`.
- [ ] **Add** a stream abort handle, e.g. `_streamCtrl` or equivalent global/ref-like state.
- [ ] **Add** a reconnect/backoff helper for stream reconnects after EOF/disconnect.
- [ ] **Do not edit** generated `.jac/tui/jac_builtin_runtime.mjs` directly; regenerate it from `runtime.cl.jac`.

#### A2. Event/state application

- [ ] **Replace poll-snapshot logic** centered on `processPollEvents()` with stream-message application logic.
- [ ] **Add** `applyMsg(msg: any, setters: any)` modeled after the web UI.
- [ ] `applyMsg()` must:
  - [ ] ignore `heartbeat`
  - [ ] replace the whole feed on `full`
  - [ ] upsert `msg.ev` by `id`
  - [ ] update top-level state: `status`, `active`, `path`, `stats`, `needs_key`, `key_env`, `model_name`
  - [ ] preserve ledger/state-only messages even when no new event is present
- [ ] Decide whether `displayEvents` remains the canonical list or becomes a derived rendering cache.
- [ ] Prefer: keep one canonical event list, then derive transcript/activity rows from it.

#### A3. Polling removal

- [ ] Delete or retire:
  - [ ] `_timer`
  - [ ] `startPolling()`
  - [ ] `stopPolling()`
  - [ ] `tick()` polling loop
- [ ] Remove `AbortSignal.timeout(30000)` from the **live update path**.
- [ ] If request timeouts remain for one-shot endpoints, make them explicit and endpoint-specific.

#### A4. Rendering derivation helpers

- [ ] Review `eventToDisplayRow()`.
- [ ] Review `processPollEvents()`.
- [ ] Decide whether to:
  - [ ] keep them as presentation-only transforms over canonical stream-fed events, or
  - [ ] replace them with simpler direct derivation per panel.
- [ ] Ensure transcript/activity rendering no longer depends on polling snapshots arriving intact.

#### A5. Lifecycle wiring in `app()`

- [ ] In `useEffect(...)`, replace `startPolling(...)` with `streamLoop(...)` startup.
- [ ] Keep boot-time one-shot fetches for:
  - [ ] `refreshSettings(actions)`
  - [ ] `refreshGraph(actions)`
- [ ] Keep optional `JAC_TUI_INITIAL_PROMPT` send after boot.
- [ ] On cleanup, abort the stream cleanly instead of clearing a poll timer.
- [ ] Ensure only one stream loop is active at a time.

#### A6. Error handling hardening

- [ ] Harden fetch/stream code against native JS exceptions, not just Jac exceptions.
- [ ] Guard `resp.body` before `getReader()`.
- [ ] Handle partial SSE chunks safely.
- [ ] If JSON parse fails for one frame, skip frame and continue.
- [ ] On disconnect, reconnect after short delay unless app is exiting.
- [ ] Never allow stream transport failure to crash the Node process.

#### A7. UX parity adjustments

- [ ] Revisit `Transcript(...)` so it reflects conversation-first semantics closer to `--ui`.
- [ ] Keep `ActivityFeed(...)` for phase/tool/reasoning visibility.
- [ ] Ensure `StatusBar(...)`, `StatsLine(...)`, `PhaseGraph(...)`, `UsagePanel(...)` all update from stream-driven state.

### B. `jac/jaclang/cli/ai_ui/frontend.cl.jac`

Use as the reference implementation; no functional change required unless a shared helper extraction becomes worthwhile.

#### B1. Copy/reference specific patterns

- [ ] Mirror `applyMsg(msg)` semantics.
- [ ] Mirror `streamLoop` chunk parsing logic:
  - [ ] `fetch("/function/agent_stream", ...)`
  - [ ] `resp.body.getReader()`
  - [ ] `TextDecoder`
  - [ ] newline/separator framing
  - [ ] parse `data:` lines only
- [ ] Mirror reconnect behavior after stream break.

#### B2. Optional follow-up

- [ ] Consider extracting shared stream parsing/upsert logic later.
- [ ] Do **not** block the first migration on code-sharing refactors.

### C. `jac-super/jac_super/ai_agent/impl/run_tui_session.impl.jac`

Likely small changes only.

#### C1. Launcher robustness

- [ ] Verify no polling-specific assumptions exist here.
- [ ] Optionally add env-gated debug logging for stream diagnostics.
- [ ] Ensure shutdown path cleanly terminates both TUI client and sidecar server.

#### C2. Acceptance checks for launcher

- [ ] `jac ai --tui` still boots server successfully.
- [ ] stream-based Ink client still receives `JAC_TUI_API_URL` and `JAC_TUI_CWD`.
- [ ] `JAC_TUI_INITIAL_PROMPT` still works.

### D. `jac-super/jac_super/ai_tui_server/main.jac`

#### D1. Verify backend export surface

- [ ] Confirm `agent_stream` remains exported.
- [ ] Confirm no TUI-specific backend endpoint changes are required.
- [ ] Confirm command endpoints remain available:
  - [ ] `agent_send`
  - [ ] `agent_reset`
  - [ ] `agent_stop`
  - [ ] `agent_settings`
  - [ ] `agent_apply_settings`
  - [ ] `agent_graph`

### E. Generated artifacts / build

#### E1. Rebuild path

- [ ] After editing `runtime.cl.jac`, re-run the Ink compile path.
- [ ] Verify generated `.jac/tui/jac_builtin_runtime.mjs` reflects the stream code.
- [ ] Do not hand-edit generated output except for temporary diagnosis.

#### E2. Dependency/runtime validation

- [ ] Validate stream code on current Node runtime (`v26.2.0`).
- [ ] Confirm `fetch`, `ReadableStream`, `TextDecoder`, and abort behavior work in the compiled Ink runtime.

### F. Tests

#### F1. Transport-level tests

- [ ] Add/extend integration test that sidecar responds on `agent_stream`.
- [ ] Validate first frame is a full snapshot.
- [ ] Validate subsequent frames update state without polling.

#### F2. Behavior tests

- [ ] `jac ai --tui` + prompt `hi` succeeds.
- [ ] idle session remains alive past prior ~30s failure point.
- [ ] long-running turn does not crash the TUI.
- [ ] `/stop` works during a live streamed turn.
- [ ] `/reset` clears state and remains connected.
- [ ] settings and graph still load.

#### F3. Regression checks

- [ ] No overlapping live-update poll requests remain.
- [ ] No uncaught `DOMException [TimeoutError]` in normal usage.
- [ ] Stream reconnect works after sidecar restart/disconnect.

### G. Suggested implementation order

#### G1. First pass

- [ ] Add `applyMsg(...)`.
- [ ] Add `streamLoop(...)`.
- [ ] Wire `useEffect(...)` to stream instead of polling.
- [ ] Keep existing render helpers as much as possible.

#### G2. Second pass

- [ ] Remove obsolete polling machinery.
- [ ] Simplify event derivation helpers.
- [ ] Tune transcript/activity semantics for closer `--ui` parity.

#### G3. Final pass

- [ ] Rebuild compiled Ink artifacts.
- [ ] Run manual repro matrix.
- [ ] Add/update tests.
- [ ] Update docs/comments to say the TUI is stream-driven, not poll-driven.

## Summary

The right fix direction is not “make polling less bad.” It is:

- keep the existing shared backend
- replace the TUI’s polling transport with the already-proven `--ui` streaming transport
- let `--tui` and `--ui` differ mainly in rendering target, not in live session semantics
