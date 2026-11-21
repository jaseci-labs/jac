// What both of the Vite bundler's scripts do first: read the job, and put the plugin
// that hands Vite a space's compiled Jac (`@jac/vite`, jac-vite.js) where the project's
// configuration imports it from. Shipped and versioned with jac.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export function prepare(jobPath) {
    const job = JSON.parse(readFileSync(jobPath, "utf8"));
    const here = path.dirname(fileURLToPath(import.meta.url));
    // Vite and its plugins are the packages of the space's npm tree (jac.toml's
    // [npm.<tree>], installed in eco/<tree>), where Vite runs and its configuration is.
    if (!job.tree) {
        console.error("space " + job.name + " has no npm tree to take its bundler from: jac.toml declares none ([npm.<tree>])");
        process.exit(1);
    }
    const plugin = path.join(job.tree, "node_modules", "@jac", "vite");
    mkdirSync(plugin, { recursive: true });
    // (Written only when it differs: a file no one changed keeps its time.)
    const put = (file, text) => {
        if (!existsSync(file) || readFileSync(file, "utf8") !== text) writeFileSync(file, text);
    };
    put(path.join(plugin, "index.js"), readFileSync(path.join(here, "jac-vite.js"), "utf8"));
    put(
        path.join(plugin, "package.json"),
        JSON.stringify({ name: "@jac/vite", version: "0.0.0", type: "module", main: "index.js" }) + "\n",
    );
    return job;
}
