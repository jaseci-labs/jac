# Compose Android demo

Jac client UI compiled to Jetpack Compose.

```bash
# one-time
jac setup android

# build APK
jac build --client android --platform android
# → apps/android/app/build/outputs/apk/debug/app-debug.apk

# install + launch (starts an emulator automatically when none is connected)
jac start --client android
```

Optional `[client.android] avd = "Small_Phone"` pins which emulator to auto-start.
Override with `JAC_ANDROID_AVD=Other_AVD jac start --client android`.

Requires JDK 17+, `ANDROID_HOME`, and Gradle (or the wrapper generated on first build).

## Dev loop (DexClassLoader HMR)

`jac start --client android --dev` installs the base host APK once, serves hot
`classes.dex` over HTTP, and watches `.jac` sources for edits; the on-device
`JacDevHostActivity` polls and hot-swaps without reinstalling.

```bash
# pick a free port if 8000 is taken (e.g. jac serve)
jac start --client android --dev -p 8010
```

## On-device verification

From the repo root (booted emulator or device required):

```bash
bash scripts/android_compose_device_e2e.sh
```

CI runs the same script inside a headless emulator (`test-android-compose-device`).

For typed RPC (`root spawn greet(...)` in the demo), run a Jac API server and point the
app at it:

```bash
# terminal 1 - API (emulator reaches host via 10.0.2.2)
jac start main.jac   # or jac serve

# in jac.toml:
# [client.android]
# backend_url = "http://10.0.2.2:8000"
```

Renaming a `:pub` walker `has` field regenerates `*Request` and breaks Kotlin call sites
that still use the old name - that compile failure is intentional (typed RPC contract).
