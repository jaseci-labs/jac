// What both of the Expo bundler's scripts do first: read the job, and lay out in the
// space's work directory the project Expo and Metro take it for (its entry, where the
// spaces it reaches are, its package.json and packages, its app.json). Returns the job
// and `run`, which runs jac's Node on a script there and ends this process if it fails.
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export function prepare(jobPath) {
    const job = JSON.parse(readFileSync(jobPath, "utf8"));
    const here = path.join(path.dirname(fileURLToPath(import.meta.url)), "expo");
    const run = (args, env) => {
        const done = spawnSync(process.env.JAC, args, { cwd: job.work, stdio: "inherit", env: { ...process.env, ...env } });
        if (done.status !== 0) process.exit(done.status === null ? 1 : done.status);
    };
    copyFileSync(path.join(here, "metro.config.js"), path.join(job.work, "metro.config.js"));
    writeFileSync(
        path.join(job.work, "index.js"),
        readFileSync(path.join(here, "index.js"), "utf8").replace("ENTRY", job.entry),
    );
    const first = Object.values(job.remotes)[0] || "";
    writeFileSync(
        path.join(job.work, "remotes.js"),
        "globalThis.__JAC_REMOTES__ = " + JSON.stringify(job.remotes) + ";\nglobalThis.__JAC_API_BASE_URL__ = " + JSON.stringify(first) + ";\n",
    );
    // Its npm packages are those of the space's npm tree: jac.toml's [npm.<tree>], which
    // jac writes as eco/<tree>/package.json and `jac install` installs beside it.
    if (!job.tree) {
        console.error("a hermes space needs an npm tree, with expo and react-native: jac.toml declares none ([npm.<tree>])");
        process.exit(1);
    }
    const manifest = path.join(job.tree, "package.json");
    const installed = path.join(job.tree, "node_modules");
    if (!existsSync(manifest) || !existsSync(installed)) {
        console.error("the packages of " + job.tree + " aren't installed: run `jac install`");
        process.exit(1);
    }
    const pkg = { main: "index.js", ...JSON.parse(readFileSync(manifest, "utf8")) };
    writeFileSync(path.join(job.work, "package.json"), JSON.stringify(pkg, null, 2) + "\n");
    const linked = path.join(job.work, "node_modules");
    rmSync(linked, { recursive: true, force: true });
    symlinkSync(installed, linked, "dir");
    // The app as its phone shows it: its name, its version and, for Android, the
    // identifier it is installed under (jac.toml's [apps.<app>]).
    const android = job.android || {};
    const expo = { name: android.title || job.name, slug: job.name, version: android.version || "1.0.0", newArchEnabled: true, web: { bundler: "metro", output: "single" } };
    if (android.identifier) expo.android = { package: android.identifier };
    writeFileSync(path.join(job.work, "app.json"), JSON.stringify({ expo }, null, 2) + "\n");
    // An app that calls a space over plain HTTP (a server on the developer's own machine)
    // is allowed to: Android refuses cleartext to an installed app unless its manifest
    // says otherwise.
    const plain = Object.values(job.remotes).some((u) => String(u).startsWith("http://"));
    const config = path.join(job.work, "app.config.js");
    if (plain) {
        writeFileSync(
            config,
            'const { withAndroidManifest } = require("expo/config-plugins");\n'
                + "module.exports = ({ config }) => withAndroidManifest(config, (made) => {\n"
                + '    made.modResults.manifest.application[0].$["android:usesCleartextTraffic"] = "true";\n'
                + "    return made;\n});\n",
        );
    } else {
        rmSync(config, { force: true });
    }
    return { job, run };
}
