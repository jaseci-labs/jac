// `@jac/vite`: hands Vite a space's compiled Jac. Shipped and versioned with jac;
// its bundler installs it into the project's node_modules.
import { appendFileSync, existsSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import http from "node:http";
import path from "node:path";

// Tell the jac showing the build's progress where the bundle is: a line in
// the file JAC_PROGRESS_TO names, when there is one.
function report(text) {
    const to = process.env.JAC_PROGRESS_TO;
    if (!to) return;
    try {
        appendFileSync(to, text + "\n");
    } catch {
        // No one is reading.
    }
}

// A dev server's request, asked of the app's program at `app` first: the program's
// answer is the answer, unless it has nothing there (404 to a GET), which leaves the
// request to Vite. So the page and its modules are Vite's, and everything the app
// answers (its endpoints, its routes, its other pages) is the app's, without a list of
// which is which. While the program is down (it is started again when its code
// changes) a page still loads, and a call of the app's says so.
function askApp(app, req, res, next) {
    const reads = req.method === "GET" || req.method === "HEAD";
    const target = new URL(req.url, app);
    const asked = http.request(
        target,
        { method: req.method, headers: { ...req.headers, host: target.host } },
        (answer) => {
            if (answer.statusCode === 404 && reads) {
                answer.resume();
                next();
                return;
            }
            res.writeHead(answer.statusCode, answer.headers);
            answer.pipe(res);
        },
    );
    // A reply its reader left (a stream's, a page closed): the app's program is told.
    res.on("close", () => asked.destroy());
    asked.on("error", () => {
        if (reads) {
            next();
            return;
        }
        res.writeHead(502, { "content-type": "text/plain" });
        res.end("the app's program isn't answering: it may be starting again\n");
    });
    req.pipe(asked);
}

export default function jac({ assets } = {}) {
    const job = JSON.parse(readFileSync(process.env.JAC_BUNDLE_JOB, "utf8"));
    const bundle = JSON.parse(readFileSync(path.join(job.src, "@jac", "bundle.json"), "utf8"));
    const alias = Object.entries(bundle.aliases).map(([find, to]) => ({
        find: new RegExp("^" + find.replace(/[/$]/g, "\\$&") + "$"),
        replacement: path.join(job.src, to),
    }));
    alias.push({ find: /^\$src\//, replacement: job.top + "/" });
    let parsed = 0;
    let resolved = null;
    let watched = [];
    return {
        name: "jac",
        enforce: "pre",
        config() {
            mkdirSync(path.join(job.public, "static"), { recursive: true });
            if (assets) {
                const link = path.join(job.public, "static", "assets");
                rmSync(link, { force: true, recursive: true });
                symlinkSync(path.join(job.top, assets), link);
            }
            // Serving the space as it is worked on (`jac dev`): where the job says.
            const [host, port] = (job.listen || "").split(":");
            // Vite runs in the space's npm tree, and serves what the project holds
            // outside it too: its stylesheets and assets, by `$src/`.
            const serving =
                job.mode === "serve"
                    ? { server: { host, port: Number(port), strictPort: true, fs: { allow: [job.top] } } }
                    : {};
            return {
                ...serving,
                base: job.base,
                publicDir: job.public,
                // (No gzip size for each file in Vite's report: no one is shown the
                // report of a build that succeeds, and the sizes take seconds to compute.)
                build: {
                    outDir: job.dist,
                    emptyOutDir: true,
                    chunkSizeWarningLimit: 4000,
                    reportCompressedSize: false,
                },
                resolve: { alias },
            };
        },
        resolveId(id) {
            if (id === "/@jac/entry") return path.join(job.src, bundle.entry);
            return null;
        },
        moduleParsed() {
            parsed += 1;
            if (parsed % 100 === 0) report("transforming " + parsed + " modules");
        },
        renderStart() {
            report("rendering " + parsed + " modules");
        },
        configureServer(server) {
            // Vite's own (its client, the modules it serves by id, its packages) is
            // never the app's; the rest is asked of the app's program first.
            if (!job.app) return;
            server.middlewares.use((req, res, next) => {
                const own = req.url.startsWith(job.base + "@") || req.url.startsWith(job.base + "node_modules/");
                if (own) next();
                else askApp(job.app, req, res, next);
            });
        },
        configResolved(config) {
            resolved = config;
        },
        buildEnd(error) {
            // What the bundle read, as Vite knows it: every file a build in watch
            // mode would build again for (its modules, and what its plugins said
            // they read), some of them patterns for files that may appear.
            if (!error) watched = this.getWatchFiles();
        },
        writeBundle() {
            // Written, so read in full: jac skips the next bundle of the space
            // when none of this has changed (compiler/app).
            const root = resolved.root;
            const files = new Set();
            const missing = new Set();
            const globs = new Set();
            const note = (file) => (existsSync(file) ? files : missing).add(file);
            for (const w of watched) {
                if (/[*?{}[\]]/.test(w)) globs.add(w);
                else note(path.resolve(root, w));
            }
            // And what Vite reads without watching: its configuration and what that
            // imports, the mode's .env files, and the tsconfig.json or jsconfig.json
            // nearest the space's modules, which esbuild compiles them by.
            if (resolved.configFile) note(resolved.configFile);
            for (const dep of resolved.configFileDependencies || []) note(path.resolve(root, dep));
            if (resolved.envDir) {
                for (const name of [".env", ".env.local", `.env.${resolved.mode}`, `.env.${resolved.mode}.local`]) {
                    note(path.join(resolved.envDir, name));
                }
            }
            for (let dir = job.src; ; dir = path.dirname(dir)) {
                note(path.join(dir, "tsconfig.json"));
                note(path.join(dir, "jsconfig.json"));
                if (dir === job.tree || dir === path.dirname(dir)) break;
            }
            // And of the environment: the mode, and the variables Vite hands the
            // modules as constants, by their prefixes.
            const env = ["NODE_ENV"].concat([resolved.envPrefix || "VITE_"].flat().map((prefix) => prefix + "*"));
            writeFileSync(
                path.join(job.work, "bundle-read.json"),
                JSON.stringify({
                    root,
                    files: [...files],
                    missing: [...missing],
                    globs: [...globs],
                    public: resolved.publicDir || "",
                    env,
                }) + "\n",
            );
        },
    };
}
