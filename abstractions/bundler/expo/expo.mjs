// The Expo bundler: a hermes space's Hermes bytecode, through Metro, and, where the
// Android SDK is at hand, the app an Android phone installs: Expo writes the native
// project in the space's work directory, and Gradle builds it with the bundle inside,
// signed with the project's development key. An .ipa needs Xcode, through
// `expo run:ios` in the work directory.
import { createHash } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import { prepare } from "./expo-project.mjs";

const { job, run } = prepare(process.argv[2]);
const quiet = { EXPO_NO_TELEMETRY: "1", CI: "1" };
run(
    ["node", "node_modules/expo/bin/cli", "export", "--platform", "android", "--platform", "ios", "--output-dir", job.dist],
    quiet,
);
const android = job.android || {};
if (android.sdk) {
    // The native project is made from the app's identity and its packages, and made again,
    // whole, when either changed: one made for another identifier is not this app's.
    const key = createHash("sha256");
    for (const from of [
        path.join(job.work, "app.json"),
        path.join(job.work, "app.config.js"),
        path.join(job.tree, "package.json"),
        path.join(job.tree, "package-lock.json"),
    ]) {
        key.update(from + "\0");
        key.update(existsSync(from) ? readFileSync(from) : "");
    }
    const want = key.digest("hex");
    const native = path.join(job.work, "android");
    const madeFor = path.join(native, ".jac-made-for");
    if (!existsSync(madeFor) || readFileSync(madeFor, "utf8") !== want) {
        rmSync(native, { recursive: true, force: true });
        run(["node", "node_modules/expo/bin/cli", "prebuild", "--platform", "android", "--no-install"], quiet);
        writeFileSync(madeFor, want);
    }
    // Gradle runs `node` for the bundle it puts in the app: jac's, by that name.
    const lib = process.env.JAC_LIB_DIR || path.join(path.dirname(process.env.JAC), "..", "lib");
    const env = {
        ...quiet,
        ANDROID_HOME: android.sdk,
        ANDROID_SDK_ROOT: android.sdk,
        PATH: path.join(lib, "node", "bin") + path.delimiter + process.env.PATH,
        NODE_ENV: "production",
    };
    if (android.java) env.JAVA_HOME = android.java;
    const { spawnSync } = await import("node:child_process");
    // No daemon is left behind: Gradle's and Kotlin's would each hold gigabytes for hours
    // after a build that, with nothing changed, is not run again.
    const gradle = ["assembleRelease", "--console=plain", "-q", "--no-daemon", "-Pkotlin.compiler.execution.strategy=in-process"];
    const built = spawnSync(path.join(native, "gradlew"), gradle, {
        cwd: native,
        stdio: "inherit",
        env: { ...process.env, ...env },
    });
    if (built.status !== 0) process.exit(built.status === null ? 1 : built.status);
    const made = path.join(native, "app", "build", "outputs", "apk", "release", "app-release.apk");
    if (!existsSync(made)) {
        console.error("Gradle built no app: " + made + " is missing");
        process.exit(1);
    }
    mkdirSync(job.dist, { recursive: true });
    copyFileSync(made, path.join(job.dist, job.name + ".apk"));
} else {
    console.log(
        "No Android SDK: built the bundles only. For an installable " + job.name + ".apk, set ANDROID_HOME, or let jac fetch one: `jac install` with `[android] licenses = \"accepted\"` in jac.toml.",
    );
}

// What this read, for a build with none of it changed to run nothing (compiler/app): the
// space's modules as jac wrote them, with any that appear, the packages its npm tree
// pins, and of the environment what Expo hands the modules as constants.
const files = [];
const missing = [];
const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
        if (entry.isDirectory()) walk(path.join(dir, entry.name));
        else files.push(path.join(dir, entry.name));
    }
};
walk(job.src);
for (const pinned of [path.join(job.tree, "package.json"), path.join(job.tree, "package-lock.json")]) {
    (existsSync(pinned) ? files : missing).push(pinned);
}
writeFileSync(
    path.join(job.work, "bundle-read.json"),
    JSON.stringify({ root: job.src, files, missing, globs: ["**/*"], public: "", env: ["NODE_ENV", "EXPO_PUBLIC_*"] }) + "\n",
);
