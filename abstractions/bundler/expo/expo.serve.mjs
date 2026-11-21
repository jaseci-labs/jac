// The Expo bundler's dev server, for `jac dev`: Metro serving a hermes space's
// compiled modules to a device or an emulator, which loads the app from it and takes
// each change as Metro's fast refresh gives it. jac compiles the space again when
// its sources change; Metro, which watches the space's work directory, sees the modules
// that came out different.
//
// It listens at the port the job gives. (Not as `CI`, under which Metro watches nothing.)
// Metro is a program of its own, which ends when this one is asked to.
import { spawn } from "node:child_process";
import { prepare } from "./expo-project.mjs";

const { job } = prepare(process.argv[2]);
const port = (job.listen || "").split(":")[1] || "8081";
const metro = spawn(process.env.JAC, ["node", "node_modules/expo/bin/cli", "start", "--port", port], {
    cwd: job.work,
    stdio: "inherit",
    env: { ...process.env, EXPO_NO_TELEMETRY: "1" },
});
for (const signal of ["SIGINT", "SIGTERM"]) {
    process.on(signal, () => metro.kill(signal));
}
metro.on("exit", (status) => process.exit(status === null ? 0 : status));
