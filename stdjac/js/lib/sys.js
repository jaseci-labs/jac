// Python's sys module on a JS host (rt/sys.jac's names), as much of it as a
// JS host has: the command line, the standard streams, exit, and the facts
// of the host. A compiled module imports it as it uses it.
import { Obj, exc, SystemExit, rt_set_stdout } from "../core.js";

const G = globalThis;
const proc = G.process;

// A standard stream: text written goes straight to the host's.
export class TextStream extends Obj {
    static $name = "TextStream";
    init(fd) { this.fd = fd; }
    write(s) {
        if (proc && proc.stdout && proc.stderr) (this.fd === 2 ? proc.stderr : proc.stdout).write(s);
        else (this.fd === 2 ? G.console.error : G.console.log)(s.endsWith("\n") ? s.slice(0, -1) : s);
        return s.length;
    }
    flush() {}
    fileno() { return this.fd; }
}

// Standard input, which a JS host doesn't read from a program's code.
export class InStream extends Obj {
    static $name = "InStream";
    init() {}
    readline() { return ""; }
    read() { return ""; }
    fileno() { return 0; }
}

export const argv = proc && proc.argv ? proc.argv.slice(1) : [];
export const orig_argv = proc && proc.argv ? proc.argv.slice() : [];
export const executable = proc && proc.execPath ? proc.execPath : "";
export const __stdout__ = new TextStream().$init(1);
export const __stderr__ = new TextStream().$init(2);
// sys.stdout and sys.stderr may be replaced by any object with a write method
// (each with its setter, which a module assigning it calls), and so may
// sys.stdin; print() writes through sys.stdout. __stdout__ and __stderr__
// keep the originals.
export let stdout = __stdout__;
export let stderr = __stderr__;
export function $set_stdout(v) { stdout = v; rt_set_stdout(v === __stdout__ ? undefined : v); }
export function $set_stderr(v) { stderr = v; }
export const __stdin__ = new InStream().$init();
export let stdin = __stdin__;
export function $set_stdin(v) { stdin = v; }
// The largest int: a JS host's ints are exact to ±2**53.
export const maxsize = Number.MAX_SAFE_INTEGER;
export const byteorder = "little";
// The operating system as Python names it: on Node, its process.platform
// (linux, darwin, win32, ... as Python's are, but SunOS's "sunos5"); in a
// page, which has none, "browser". A hermes space's is lib/sys.hermes.js's.
const PY_PLATFORM = { sunos: "sunos5" };
export const platform = proc && proc.platform ? PY_PLATFORM[proc.platform] || proc.platform : "browser";

// Raise SystemExit: with no status, code None (exit 0); an int is the exit
// status; anything else is the message.
export function exit(status) {
    const e = exc(SystemExit, ...(status === undefined ? [] : [status]));
    e.code = status;
    throw e;
}
