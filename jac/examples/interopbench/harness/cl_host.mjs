#!/usr/bin/env node
/**
 * Node adapter for generated cl->sv feed benchmarks.
 *
 * Compiles client_driver.cl.jac via `jac js`, wires a minimal
 * @jac/runtime shim, and times `run_feed(work, calls)`.
 *
 * Usage:
 *   JAC_API_BASE_URL=http://127.0.0.1:PORT node harness/cl_host.mjs \
 *     kernels/xop_feed <work> <calls>
 */
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { performance } from "node:perf_hooks";

const harnessDir = dirname(fileURLToPath(import.meta.url));
const benchRoot = resolve(harnessDir, "..");
const kernelDir = resolve(benchRoot, process.argv[2] ?? "kernels/xop_feed");
const work = Number(process.argv[3]);
const calls = Number(process.argv[4]);

if (!Number.isInteger(work) || work < 1 || !Number.isInteger(calls) || calls < 1) {
  console.error("usage: cl_host.mjs <kernel-dir> <work> <calls>");
  process.exit(2);
}
const apiBase = process.env.JAC_API_BASE_URL;
if (!apiBase) {
  console.error("JAC_API_BASE_URL is required");
  process.exit(2);
}

const compile = spawnSync("jac", ["js", "client_driver.cl.jac"], {
  cwd: kernelDir,
  encoding: "utf8",
});
if (compile.status !== 0) {
  console.error(compile.stderr || compile.stdout);
  process.exit(compile.status ?? 1);
}

const workDir = mkdtempSync(join(tmpdir(), "interop-cl-"));
writeFileSync(join(workDir, "runtime.mjs"), `
export async function __jacCallFunction(function_name, args = {}) {
  const resp = await fetch(\`\${process.env.JAC_API_BASE_URL}/function/\${function_name}\`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(args),
  });
  if (!resp.ok) {
    throw new Error(\`function \${function_name} failed: \${await resp.text()}\`);
  }
  const payload = await resp.json();
  if (!payload.ok) {
    throw new Error(\`function \${function_name} error: \${JSON.stringify(payload.error)}\`);
  }
  return payload.data?.result;
}
`);

writeFileSync(
  join(workDir, "client.mjs"),
  compile.stdout
    .replace(
      'import { __jacCallFunction } from "@jac/runtime";',
      'import { __jacCallFunction } from "./runtime.mjs";',
    )
    .replace(
      /import \{ jacIsLoggedIn \} from "@jac\/runtime";\n/,
      "",
    ),
);

writeFileSync(
  join(workDir, "driver.mjs"),
  `import { run_feed } from "./client.mjs";

const work = Number(process.argv[2]);
const calls = Number(process.argv[3]);

const bench = async (w, c) => {
  return run_feed(w, c);
};

await bench(work, 1);
const t0 = performance.now();
const checksum = await bench(work, calls);
const elapsedNs = Math.round((performance.now() - t0) * 1e6);
console.log(\`feed:\${checksum}\`);
console.log(\`m:per_call_ns=\${Math.floor(elapsedNs / calls)}\`);
console.log(\`ns=\${elapsedNs}\`);
`,
);

const run = spawnSync(
  process.execPath,
  [join(workDir, "driver.mjs"), String(work), String(calls)],
  {
    cwd: workDir,
    encoding: "utf8",
    env: { ...process.env, JAC_API_BASE_URL: apiBase },
  },
);
process.stdout.write(run.stdout ?? "");
process.stderr.write(run.stderr ?? "");
process.exit(run.status ?? 1);
