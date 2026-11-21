// The Vite bundler's dev server, for `jac dev`: the project's own Vite serving a
// space's compiled modules as they are, with its own config, on the vendored Node.
// jac compiles the space again when its sources change; Vite sees the modules that
// came out different and puts them into the open page.
//
// The job says where to listen (`listen`) and where the app's program is (`app`): the
// plugin has Vite ask the program first for whatever isn't the page's (jac-vite.js).
import { createRequire } from "node:module";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { prepare } from "./vite-plugin.mjs";

const jobPath = process.argv[2];
const job = prepare(jobPath);
process.env.JAC_BUNDLE_JOB = path.resolve(jobPath);
process.chdir(job.tree);
// The project's Vite, as the packages of the space's npm tree resolve it.
const from = createRequire(path.join(job.tree, "package.json"));
const { createServer } = await import(pathToFileURL(from.resolve("vite")).href);
const server = await createServer({
    configFile: job.config || undefined,
    clearScreen: false,
});
await server.listen();
server.printUrls();
for (const signal of ["SIGINT", "SIGTERM"]) {
    process.on(signal, () => server.close().finally(() => process.exit(0)));
}
