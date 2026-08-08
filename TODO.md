### 1. Compose types leak into every client target

 This is the largest problem in the current working tree.

 TypeEvaluator.postinit() unconditionally installs Compose widgets, modifiers, constants, and .dp/.sp/.len:

- type_evaluator.impl.jac:3569-3572

 Resolution is gated only by expr.in_client_context():

- type_evaluator.impl.jac:1878-1881

 That means a normal React .cl.jac file can see Compose ambient names. The seam should be Compose target, not generic client codespace. MobUI
 already demonstrates target-aware checking through _is_mobui_module().

### 2. Target selection has two sources of truth

 Currently these are separate:

- CLI target: --client android
- Compiler framework: [client] framework = "compose"

 AndroidTarget runs the Compose pipeline regardless, while the normal ES backend resolves framework independently from configuration:

- ecmascript/backends/registry.jac:38-42
- android_target.impl.jac:351-383

 Those choices should not be able to disagree. Selecting Android should select the Compose client surface once, or validation should reject a
 mismatch.

### 3. “Open vocabulary” is not fully implemented yet

 Any capitalized tag emits as a Kotlin call, and wildcard imports expose the standard Compose packages. That is useful, but it is not yet the full
 promised model:

- Non-screen user def ... -> Composable declarations are collected but ComposeEmit.emit_screens() emits only routed/screen functions.
- Jac imports are not translated into target Kotlin imports.
- Third-party composables therefore do not become genuinely first-class.
- <Raw kotlin=...> remains necessary for several cases.

 So the standard Material/Foundation vocabulary is becoming open, but user and library composables are not fully open yet.

### 4. Type checking and emission do not share all metadata

 compose_stub_gen.jac classifies parameters as value/event/slot and feeds the checker. But the emitter still decides slots heuristically:

- Signature classification: compose_stub_gen.jac
- Heuristic _slot_wrap: compose_native_emit.impl.jac:241-252

 The same parsed Compose signature model should drive both. Otherwise the checker and generated Kotlin can disagree.

 Recommended seam

 Create one target-aware client surface module selected once during compilation. Its interface should provide:

- ambient names and types;
- JSX child/slot semantics;
- foreign signature ingestion;
- target imports and dependencies;
- expression/view lowering;
- emitted target files.

 Then React, MobUI, and Compose become adapters at that seam. The shared frontend, intent model, routes, and interop manifest stay untouched.
