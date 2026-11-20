// The Vite bundler: the project's own Vite, with its own config, run in the space's npm
// tree (eco/<tree>) on the vendored Node.
import { spawnSync } from "node:child_process";
import path from "node:path";
import { prepare } from "./vite-plugin.mjs";

const jobPath = process.argv[2];
const job = prepare(jobPath);
// Vite reports its progress on stdout and what it warns of on stderr. A jac
// showing the build's progress (JAC_PROGRESS_TO) shows the first as where the
// build is and passes the second through; with no one shown progress, Vite says
// only what it warns of.
const args = ["node", "node_modules/vite/bin/vite.js", "build"];
if (!process.env.JAC_PROGRESS_TO) args.push("--logLevel", "warn");
if (job.config) args.push("--config", job.config);
const done = spawnSync(process.env.JAC, args, {
    cwd: job.tree,
    stdio: "inherit",
    env: { ...process.env, JAC_BUNDLE_JOB: path.resolve(jobPath) },
});
process.exit(done.status === null ? 1 : done.status);
