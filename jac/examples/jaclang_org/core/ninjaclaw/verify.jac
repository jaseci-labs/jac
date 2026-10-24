import os;
import re;
import shutil;
import subprocess;
import sys;
import tempfile;
import time;
import from pathlib { Path }
import from jaclang.jac0core.handoff { handoff }

glob SANDBOX_ENV: str = "NINJACLAW_SANDBOX",
     WARM_TIMEOUT_S: int = 1200,
     WARMED: dict[str, bool] = {},
     CHECK_TIMEOUT_S: int = 180,
     RUN_TIMEOUT_S: int = 60,
     CPU_LIMIT_S: int = 90,
     DETAIL_LIMIT: int = 600,
     SERVER_MARKERS: list[str] = [
         "walker:pub",
         "walker:priv",
         "walker:protect",
         "def:pub",
         "def:priv",
         "def:protect",
         "by llm",
         "JsxElement",
         "jac start",
         "@schedule"
     ];

def code_blocks(markdown: str) -> list[str];

def block_mode(code: str) -> str;

def jac_binary -> str;

def sandbox_cache -> Path;

def compiler_source -> str;

def sandbox_env(home: str, cache: Path) -> dict[str, str];

def seatbelt_profile(work: Path, cache: Path) -> str;

def bwrap_args(work: Path, cache: Path) -> list[str];

def sandbox_command(work: Path, cache: Path) -> list[str] | None;

def warm_sandbox -> str;

def limit_resources -> None;

def run_jac(args: list[str], cwd: Path, timeout: int) -> tuple[bool, str];

def verify_block(index: int, code: str) -> BlockView;

def verify_markdown(
    markdown: str, note: Callable, deadline: float = 0.0
) -> list[BlockView];

impl code_blocks(markdown: str) -> list[str] {
    return [
        (m.group(1) as str).strip("\n")
        for m in re.finditer(r"```jac[^\n]*\n(.*?)```", markdown, re.DOTALL)
    ];
}

impl block_mode(code: str) -> str {
    for marker in SERVER_MARKERS {
        if marker in code {
            return "check";
        }
    }
    return "run" if "with entry" in code else "check";
}

impl jac_binary -> str {
    return shutil.which("jac") or "jac";
}

impl sandbox_cache -> Path {
    cache = knowledge_dir() / "sandbox-cache";
    cache.mkdir(parents=True, exist_ok=True);
    return cache.resolve();
}

impl compiler_source -> str {
    return str(handoff().get("compiler_source") or "");
}

impl sandbox_env(home: str, cache: Path) -> dict[str, str] {
    keep = ["PATH", "LANG", "LC_ALL", "SYSTEMROOT"];
    env: dict[str, str] = {
        k: os.environ[k]
        for k in keep
        if k in os.environ
    };
    env["HOME"] = home;
    env["TMPDIR"] = home;
    env["JAC_CACHE_HOME"] = str(cache);
    env["JAC_TEST_JOBS"] = "0";
    env["NO_COLOR"] = "1";
    return env;
}

impl seatbelt_profile(work: Path, cache: Path) -> str {
    def q(path: str) -> str {
        return '"' + path.replace("\\", "\\\\").replace('"', '\\"') + '"';
    }
    reads = ["/usr", "/System", "/Library", "/private/var/db", "/dev", "/opt/homebrew"];
    rules = [
        "(version 1)",
        "(deny default)",
        "(allow process-fork)",
        "(allow process-exec)",
        "(allow signal (target same-sandbox))",
        "(allow sysctl-read)",
        "(allow mach-lookup)",
        "(allow ipc-posix-shm)",
        "(allow file-read-metadata)",
        '(allow file-read* (literal "/"))',
        "(allow file-read* "
            + " ".join(["(subpath " + q(r) + ")" for r in reads])
            + ")",
        "(allow file-read* (literal " + q(os.path.realpath(jac_binary())) + "))"
    ];
    source = compiler_source();
    if source {
        real = os.path.realpath(source);
        rules.append("(allow file-read* (subpath " + q(real) + "))");
        rules.append(
            "(deny file-read* (subpath " + q(os.path.join(real, "examples")) + "))"
        );
    }
    rules.append(
        "(allow file-read* file-write* (subpath "
            + q(str(work))
            + ") (subpath "
            + q(str(cache))
            + ") (literal \"/dev/null\"))"
    );
    return "\n".join(rules) + "\n";
}

impl bwrap_args(work: Path, cache: Path) -> list[str] {
    bwrap = shutil.which("bwrap") or "bwrap";
    args = [
        bwrap,
        "--unshare-all",
        "--die-with-parent",
        "--new-session",
        "--proc",
        "/proc",
        "--dev",
        "/dev",
        "--tmpfs",
        "/tmp"
    ];
    for path in [
        "/usr",
        "/bin",
        "/sbin",
        "/lib",
        "/lib64",
        "/lib32",
        "/etc/alternatives"
    ] {
        args += ["--ro-bind-try", path, path];
    }
    binary = os.path.realpath(jac_binary());
    args += ["--ro-bind", binary, binary];
    source = compiler_source();
    if source {
        real = os.path.realpath(source);
        args += ["--ro-bind", real, real, "--tmpfs", os.path.join(real, "examples")];
    }
    args += [
        "--bind",
        str(cache),
        str(cache),
        "--bind",
        str(work),
        str(work),
        "--chdir",
        str(work)
    ];
    return args;
}

impl sandbox_command(work: Path, cache: Path) -> list[str] | None {
    mode = os.environ.get(SANDBOX_ENV, "auto").strip().lower();
    if mode == "none" {
        return [];
    }
    if sys.platform.startswith("linux") and shutil.which("bwrap") {
        return bwrap_args(work, cache);
    }
    if sys.platform == "darwin" and shutil.which("sandbox-exec") {
        return ["sandbox-exec", "-p", seatbelt_profile(work, cache)];
    }
    return None;
}

impl limit_resources -> None {
    import resource;
    try {
        resource.setrlimit(resource.RLIMIT_CPU, (CPU_LIMIT_S, CPU_LIMIT_S));
    } except Exception {}
    if sys.platform.startswith("linux") {
        try {
            gib = 2 * 1024 * 1024 * 1024;
            resource.setrlimit(resource.RLIMIT_AS, (gib, gib));
        } except Exception {}
    }
}

impl run_jac(args: list[str], cwd: Path, timeout: int) -> tuple[bool, str] {
    cache = sandbox_cache();
    prefix = sandbox_command(cwd, cache);
    if prefix is None {
        return (
            False,
            "no sandbox is available on this server: install bubblewrap (bwrap) on Linux, or set "
                + SANDBOX_ENV
                + "=none to run examples unisolated"
        );
    }
    try {
        done = subprocess.run(
            prefix + [jac_binary()] + args,
            cwd=str(cwd),
            env=sandbox_env(str(cwd / ".home"), cache),
            capture_output=True,
            text=True,
            timeout=timeout,
            preexec_fn=limit_resources
        );
    } except subprocess.TimeoutExpired {
        return (False, "timed out after " + str(timeout) + " s");
    }
    output = (done.stdout or "") + (done.stderr or "");
    lines = [
        ln
        for ln in output.splitlines()
        if "jac dev mode" not in ln and ln.strip()
    ];
    if done.returncode != 0 {
        errors = [
            ln
            for ln in lines
            if "rror" in ln or "-->" in ln
        ]
            or lines;
        return (False, "\n".join(errors[-8:])[:DETAIL_LIMIT]);
    }
    return (True, "\n".join(lines[-3:])[:DETAIL_LIMIT]);
}

impl warm_sandbox -> str {
    if WARMED.get("done") {
        return "";
    }
    with tempfile.TemporaryDirectory(prefix="ninjaclaw-warm-") as tmp {
        work = Path(tmp).resolve();
        (work / ".home").mkdir();
        toml = '[project]\nname = "ninjaclaw_warm"\n';
        if compiler_source() {
            toml = toml + '\n[dev]\njaclang_source = "' + compiler_source() + '"\n';
        }
        (work / "jac.toml").write_text(toml, encoding="utf-8");
        (work / "main.jac").write_text(
            'with entry {\n    print("ready");\n}\n', encoding="utf-8"
        );
        (ok, detail) = run_jac(["run", "main.jac"], work, WARM_TIMEOUT_S);
        if not ok {
            return detail;
        }
    }
    WARMED["done"] = True;
    return "";
}

impl verify_block(index: int, code: str) -> BlockView {
    mode = block_mode(code);
    with tempfile.TemporaryDirectory(prefix="ninjaclaw-") as tmp {
        work = Path(tmp).resolve();
        (work / ".home").mkdir();
        toml = '[project]\nname = "ninjaclaw_check"\n';
        source = compiler_source();
        if source {
            toml = toml + '\n[dev]\njaclang_source = "' + source + '"\n';
        }
        (work / "jac.toml").write_text(toml, encoding="utf-8");
        (work / "main.jac").write_text(code + "\n", encoding="utf-8");
        (ok, detail) = run_jac(
            ["check", "main.jac", "--nowarn"], work, CHECK_TIMEOUT_S
        );
        if not ok or mode == "check" {
            return BlockView(
                index=index, mode=mode, ok=ok, detail="" if ok else detail
            );
        }
        (ok, detail) = run_jac(["run", "main.jac"], work, RUN_TIMEOUT_S);
        return BlockView(index=index, mode=mode, ok=ok, detail="" if ok else detail);
    }
}

impl verify_markdown(
    markdown: str, note: Callable, deadline: float = 0.0
) -> list[BlockView] {
    results: list[BlockView] = [];
    blocks = code_blocks(markdown);
    no_time = False;
    if blocks and not WARMED.get("done") {
        if deadline and deadline - time.monotonic() < WARM_TIMEOUT_S {
            no_time = True;
        } else {
            note("verify", "preparing the sandbox (first use on this server)");
            problem = warm_sandbox();
            if problem {
                note("verify", "the sandbox is not usable: " + problem[:200]);
            }
        }
    }
    for (i, code) in enumerate(blocks) {
        if no_time
            or (
                deadline
                and deadline - time.monotonic() < CHECK_TIMEOUT_S + RUN_TIMEOUT_S
            ) {
            results.append(
                BlockView(
                    index=i,
                    mode=block_mode(code),
                    ok=False,
                    detail="not checked: out of time"
                )
            );
            continue;
        }
        note(
            "verify",
            "block " + str(i + 1) + " of " + str(len(blocks)) + ": " + block_mode(code)
        );
        result = verify_block(i, code);
        note(
            "verify",
            "block "
                + str(i + 1)
                + (" passed" if result.ok else " failed: " + result.detail[:160])
        );
        results.append(result);
    }
    return results;
}
