# feat(jac-scale): support KEDA HTTP Add-on activation via declarative jac.toml config

Closes #7475

## Overview

PR #7421 added a programmatic API for KEDA HTTP Add-on scale-to-zero activation (`HTTPActivationSpec`, `KEDAAutoscaler.apply_http_activation` / `destroy_http_activation`), but left it reachable only by writing a Jac driver script. Every other autoscaler knob in jac-scale is configured declaratively through `jac.toml`, so this PR adds that same entry point for HTTP activation, for both the monolith deploy path and per-service microservice deploys.

The programmatic API from #7421 is unchanged and remains the right tool for callers with a dynamic, create/destroy-on-demand lifecycle (for example, an IDE preview orchestrator). The two entry points are additive, not a replacement of one by the other: `jac.toml` covers a known, standing service; the programmatic API covers a workload created and torn down at runtime.

## Notable design point

`destroy()`'s KEDA sweep previously went through `AutoscalerFactory.create(self.k8s_config.autoscaler_engine, ...)`, so when `autoscaler_engine = "hpa"` it resolved to `HPAAutoscaler.destroy_collection`, which does not know about `InterceptorRoute` or HTTP-activation `ScaledObject` resources, orphaning them on teardown. `destroy()` now also runs an unconditional `KEDAAutoscaler(...).destroy_collection(...)` sweep whenever `autoscaler_engine != "keda"`, since HTTP activation needs the KEDA HTTP Add-on regardless of the base engine.

## Tests

12 new tests, plus the 30 existing HTTP activation tests preserved unchanged (verified passing after a fixture refactor):

- `test_http_activation_config.jac` (8 tests): config-to-spec translation (disabled/absent, minimal config defaults, one full-config test covering every optional field, the two jac.toml-relative validation errors) and the injectable apply/destroy wiring helpers.
- `test_http_activation_microservices.jac` (4 tests): the per-service config pass-through and the per-service apply loop, including that a disabled service is skipped while an enabled one targets its own generated Service.
- `http_activation_test_support.jac`: shared fixtures (`default_http_activation_spec`, `default_http_activation_config`, `mocked_keda_autoscaler`) extracted from `test_keda_http_activation.jac` so both files use one source of truth instead of duplicating mock setup.

All 127 relevant tests pass (`jac test` across the HTTP activation, KEDA autoscaler, config loader, factories, and deployment overlay suites).

The microservices `destroy()` engine-gap fix has no dedicated test: like the rest of that method, it requires a live cluster (`_load_kube_config`, real client construction) with no existing unit-test precedent in this codebase.

## Files Changed

| File | What Changed |
|---|---|
| `jac/jaclang/scale/deploy/autoscale/http_activation_config.jac` | New. `build_http_activation_spec` translates a `[*.http_activation]` config dict into an `HTTPActivationSpec`, with jac.toml-relative validation errors. `apply_http_activation_for_target` / `destroy_http_activation_for_target` wrap the `KEDAAutoscaler` calls behind an injectable interface, shared by both deploy paths below. |
| `jac/jaclang/scale/config/plugin_config.jac` | New `[scale.kubernetes.http_activation]` schema block (23 keys: master switch, replica bounds, target port, concurrency/request-rate metrics, routing rules, cold start, timeouts, custom scale target). Documents the per-service `[scale.microservices.services.NAME.http_activation]` override, which falls back to the top-level block. |
| `jac/jaclang/scale/deploy/target/kubernetes/kubernetes_config.jac` | New `http_activation: dict[str, any]` field on `KubernetesConfig`, wired into `to_dict()` / `from_dict()` like `extra_triggers`. |
| `jac/jaclang/scale/deploy/target/kubernetes/kubernetes_target.jac` | Monolith apply/destroy call the new wiring functions next to the existing base-autoscaler calls. |
| `jac/jaclang/scale/deploy/target/kubernetes/microservice/manifest_builder.jac` | New `_get_http_activation_config(svc_name)`, mirroring `_get_autoscaler_config`. `generate_manifests()` now populates `bundle["http_activations"]`. |
| `jac/jaclang/scale/deploy/target/kubernetes/microservice/target.jac` | New `apply_http_activations_for_bundle`, wired into the per-service autoscaler loop. `destroy()` engine-gap fix (see Notable design point). |
| `jac/jaclang/scale/tests/deploy/http_activation_test_support.jac` | New. Shared fixtures (`default_http_activation_spec`, `default_http_activation_config`, `mocked_keda_autoscaler`) extracted from `test_keda_http_activation.jac`. |
| `jac/jaclang/scale/tests/deploy/test_http_activation_config.jac` | Config-to-spec translation tests plus the injectable apply/destroy wiring-helper tests (8 tests). |
| `jac/jaclang/scale/tests/deploy/test_http_activation_microservices.jac` | New. Per-service config pass-through and apply-loop tests (4 tests). |
| `jac/jaclang/scale/tests/deploy/test_keda_http_activation.jac` | Now imports shared fixtures instead of defining them locally; no test behavior change (still 30 tests). |
| `docs/docs/reference/plugins/jac-scale-kubernetes.md` | Restores the "HTTP Add-on Activation" reference section (removed pending a `jac.toml` surface) with the new config keys, both deploy-path examples, and a note on the still-available programmatic API. |
