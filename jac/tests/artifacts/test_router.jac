"""The artifact router decides every artifact the same way: the sealed image,
then the checkout, then the kit, else the floor, said once. It never builds;
`build` does, in dependency order, and verifies what it built."""

import io;
import os;
import sys;
import tempfile;
import json;
import hashlib;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.artifacts.model {
    Artifact,
    ArtifactKind,
    ArtifactUnavailable,
    Probe,
    ReleasePolicy,
    Resolution,
    Source
}
import jaclang.artifacts.router as router;
import jaclang.jac0core.artifact_registry as registry;

obj Fake(Artifact) {
    has sealed: (Probe | None) = None,
        checkout: Probe = Probe.missing(),
        kit: Probe = Probe.missing(),
        why: str = "",
        builds: list[str] = [],
        built_ok: bool = True;

    override def unavailable_reason -> str {
        return self.why;
    }

    override def probe_sealed -> (Probe | None) {
        return self.sealed;
    }

    override def probe_checkout -> Probe {
        return self.checkout;
    }

    override def probe_kit -> Probe {
        return self.kit;
    }

    override def checkout_path -> str {
        return f"/tree/{self.name}";
    }

    override def build(log: Callable[[str], None], force: bool, exact: bool) {
        self.builds.append(self.name);
        assert self.name in router.building_now() , "a build runs with its own artifact on the floor";
        if self.built_ok {
            self.checkout = Probe.hit(Source.CHECKOUT, self.checkout_path(), {});
        }
    }
}

def accel(name: str, **kw: any) -> Fake {
    return Fake(
        name=name,
        kind=ArtifactKind.ACCELERATOR,
        release=ReleasePolicy.REQUIRED,
        summary=f"the {name}",
        floor=f"{name}-floor",
        **kw
    );
}

def capability(name: str, **kw: any) -> Fake {
    return Fake(
        name=name,
        kind=ArtifactKind.CAPABILITY,
        release=ReleasePolicy.REQUIRED,
        summary=f"the {name}",
        **kw
    );
}

"""Register `fakes` for the duration of `fn` and capture what it printed."""
def with_fakes(fakes: list[Fake], fn: any) -> tuple[any, str] {
    err = io.StringIO();
    router.forget();
    entries = {f.name: f"tests:{f.name}" for f in fakes};
    try {
        with patch.dict(registry.ARTIFACTS, entries, clear=True) {
            with patch.dict(router._ENTRIES, {f.name: f for f in fakes}, clear=True) {
                with patch.object(sys, "stderr", err) {
                    result = fn();
                }
            }
        }
    } finally {
        router.forget();
    }
    return (result, err.getvalue());
}

test "the sealed image wins and the checkout is never consulted" {
    shipped = Probe.hit(Source.SEALED, "/img/x", {});
    fake = accel(
        "x", sealed=shipped, checkout=Probe.hit(Source.CHECKOUT, "/tree/x", {})
    );
    (found, said) = with_fakes([fake], lambda -> any { return router.resolve("x"); });
    assert found.found is shipped.found;
    assert said == "";
}

test "a sealed image that omits an accelerator by design runs its floor quietly" {
    fake = accel("x", sealed=Probe.by_design());
    (found, said) = with_fakes([fake], lambda -> any { return router.resolve("x"); });
    assert found.on_floor() and found.quiet;
    assert said == "";
}

test "a current checkout artifact wins over the kit's" {
    mine = Probe.hit(Source.CHECKOUT, "/tree/x", {});
    fake = accel("x", checkout=mine, kit=Probe.hit(Source.KIT, "/kit/x", {}));
    (found, said) = with_fakes([fake], lambda -> any { return router.resolve("x"); });
    assert found.found.source == Source.CHECKOUT;
    assert said == "";
}

test "a stale checkout falls through to a matching kit artifact in place" {
    fake = accel(
        "x",
        checkout=Probe.stale(["a.jac changed"]),
        kit=Probe.hit(Source.KIT, "/kit/x", {})
    );
    (found, said) = with_fakes([fake], lambda -> any { return router.resolve("x"); });
    assert found.found.source == Source.KIT and found.found.path == "/kit/x";
    assert said == "";
}

test "an accelerator on its floor says so once, naming what moved" {
    fake = accel("x", checkout=Probe.stale(["a.jac changed", "b.jac changed"]));
    def twice -> tuple[Resolution, Resolution] {
        first = router.resolve("x");
        router._RESOLVED.clear();
        return (first, router.resolve("x"));
    }
    (pair, said) = with_fakes([fake], twice);
    (first, second) = (pair[0], pair[1]);
    assert isinstance(first, Resolution) and isinstance(second, Resolution);
    assert first.on_floor() and second.on_floor();
    assert said.count("runs on its floor") == 1 , said;
    assert "x-floor" in said and "a.jac changed (and 1 more)" in said , said;
    assert "jac native build x" in said , said;
}

test "a kit that ships the floor by design is quiet" {
    fake = accel("x", kit=Probe.by_design());
    (found, said) = with_fakes([fake], lambda -> any { return router.resolve("x"); });
    assert found.on_floor() and found.quiet and said == "";
}

test "an unavailable toolchain is the reason, before any probe" {
    fake = accel("x", why="no LLVM shim here");
    (found, said) = with_fakes([fake], lambda -> any { return router.resolve("x"); });
    assert found.reason == "no LLVM shim here";
    assert "no LLVM shim here" in said;
}

test "a missing capability fails loudly and names the build command" {
    fake = capability("cap");
    def needed -> any {
        try {
            router.require("cap");
        } except ArtifactUnavailable as e {
            return str(e);
        }
        return "";
    }
    (message, said) = with_fakes([fake], needed);
    assert "jac native build cap" in message , message;
    assert said == "" , "a capability has no floor to announce";
}

test "an artifact being built resolves to its floor in the builder" {
    fake = accel("x", checkout=Probe.hit(Source.CHECKOUT, "/tree/x", {}));
    def inside -> tuple[Resolution, Resolution] {
        with router.building(["x"]) {
            during = router.resolve("x");
        }
        return (during, router.resolve("x"));
    }
    (pair, _) = with_fakes([fake], inside);
    (during, after) = (pair[0], pair[1]);
    assert isinstance(during, Resolution) and isinstance(after, Resolution);
    assert during.on_floor() and during.quiet;
    assert after.found is not None , "leaving the build restores resolution";
}

test "build follows dependencies, skips what is current, and verifies the result" {
    base = accel("base");
    top = accel("top", requires=["base"]);
    ready = accel("ready", checkout=Probe.hit(Source.CHECKOUT, "/tree/ready", {}));
    lines: list[str] = [];
    (built, _) = with_fakes(
        [base, top, ready],
        lambda -> any { return router.build(["top", "ready"], lines.append); }
    );
    assert built == ["base", "top"] , built;
    assert "ready: current" in lines , lines;
    broken = accel("broken", built_ok=False);
    def attempt -> any {
        try {
            router.build(["broken"], lines.append);
        } except ArtifactUnavailable as e {
            return str(e);
        }
        return "";
    }
    (message, _) = with_fakes([broken], attempt);
    assert "does not match its inputs" in message;
}

test "a forced build rebuilds the named artifact but not its current dependencies" {
    base = accel("base", checkout=Probe.hit(Source.CHECKOUT, "/tree/base", {}));
    top = accel(
        "top", requires=["base"], checkout=Probe.hit(Source.CHECKOUT, "/tree/top", {})
    );
    (built, _) = with_fakes(
        [base, top],
        lambda -> any { return router.build(
            ["top"], lambda (line: str) {}, force=True
        ); }
    );
    assert built == ["top"] , built;
}

test "an unsupported host is skipped, or refused in release mode" {
    fake = accel("x", hosts=["no-such-host"]);
    lines: list[str] = [];
    (built, _) = with_fakes(
        [fake], lambda -> any { return router.build(["x"], lines.append); }
    );
    assert built == [] and any("cannot be built on this host" in l for l in lines);
    def strict -> any {
        try {
            router.build(["x"], lines.append, strict=True);
        } except ArtifactUnavailable {
            return True;
        }
        return False;
    }
    (refused, _) = with_fakes([fake], strict);
    assert refused;
}

test "the release check holds required artifacts native and shipped floors present" {
    native = accel("native", checkout=Probe.hit(Source.CHECKOUT, "/tree/native", {}));
    stale = accel("stale", checkout=Probe.stale(["x changed"]));
    shipped = accel("shipped");
    shipped.release = ReleasePolicy.FLOOR;
    def check -> any {
        return (
            router.release_set(),
            router.shipped_floors(),
            router.unmet(router.release_set() + router.shipped_floors())
        );
    }
    ((required, floors, problems), _) = with_fakes([native, stale, shipped], check);
    assert required == ["native", "stale"] and floors == ["shipped"];
    assert problems == ["stale: stale: x changed"] , problems;
}

test "publication holds the lock across every file of an artifact" {
    import from jaclang.jac0core.cache_paths { FileLock, atomic_write }
    with tempfile.TemporaryDirectory() as directory {
        stage = Path(directory) / "stage.so";
        target = Path(directory) / "lib.so";
        stage.write_bytes(b"new");
        Path(str(stage) + ".layout.json").write_text("{}");
        held: list[bool] = [];
        def write(path: str, data: bytes, mode: (int | None) = None) {
            rival = FileLock(str(target) + ".lock", timeout=0.0);
            try {
                rival.acquire();
                rival.release();
                held.append(False);
            } except TimeoutError {
                held.append(True);
            }
            atomic_write(path, data, mode);
        }
        with patch("jaclang.jac0core.cache_paths.atomic_write", side_effect=write) {
            router.publish(str(stage), str(target), companions=(".layout.json", ));
        }
        assert held == [True, True];
        assert target.read_bytes() == b"new";
        assert Path(str(target) + ".layout.json").read_text() == "{}";
    }
}

test "an artifact the image declares it leaves out runs its floor quietly, from any tier" {
    fake = accel(
        "x",
        sealed=Probe.hit(Source.SEALED, "/img/x", {}),
        kit=Probe.hit(Source.KIT, "/kit/x", {})
    );
    def resolve_omitted -> tuple[Resolution, frozenset[str]] {
        with patch.object(router, "_omitted", return_value=frozenset({"x"})) {
            return (router.resolve("x"), router.omitted_by_image());
        }
    }
    (outcome, said) = with_fakes([fake], resolve_omitted);
    (found, omitted) = outcome;
    assert found.on_floor() and found.quiet;
    assert omitted == frozenset({"x"});
    assert said == "";
}

test "unmet holds what a release needs, and nothing a host cannot carry" {
    here = accel("here", checkout=Probe.stale(["a.jac changed"]));
    elsewhere = capability("elsewhere", hosts=["no-such-host"]);
    def check -> any {
        return router.unmet(["here", "elsewhere"]);
    }
    (problems, _said) = with_fakes([here, elsewhere], check);
    assert len(problems) == 1 and problems[0].startswith("here:") , problems;
}

test "a build whose command fails is refused cleanly, naming the command" {
    import subprocess;
    fake = accel("x");
    def fail(log: Callable[[str], None], force: bool, exact: bool) {
        raise subprocess.CalledProcessError(1, ["zig", "build", "x"]);
    }
    fake.build = fail;
    def attempt -> any {
        try {
            router.build(["x"], lambda (line: str) {});
        } except ArtifactUnavailable as e {
            return str(e);
        }
        return "";
    }
    (message, _) = with_fakes([fake], attempt);
    assert "x: `zig build x` failed (exit status 1)" in message , message;
}

test "the build command named for a missing per-target artifact is one `jac native` accepts" {
    import re;
    import from jaclang.artifacts.kit { osarch }
    import from jaclang.cli.commands.native { native }
    import jaclang.compiler.backends.native.floors as floors;
    target = "linux-aarch64" if osarch() == "linux-x86_64" else "linux-x86_64";
    router.forget();
    try {
        with patch.object(floors.MuslArtifact, "probe_sealed", return_value=None), patch.object(
            floors.MuslArtifact, "probe_checkout", return_value=Probe.missing()
        ), patch.object(
            floors.MuslArtifact, "probe_kit", return_value=Probe.missing()
        ) {
            router._ENTRIES.pop(f"musl@{target}", None);
            try {
                router.require(f"musl@{target}");
                assert False , "a musl runtime that no tier holds must be refused";
            } except ArtifactUnavailable as e {
                advice = str(e);
            }
        }
    } finally {
        router._ENTRIES.pop(f"musl@{target}", None);
        router.forget();
    }
    named = re.search(r"`jac native build ([^`]+)`", advice);
    assert named is not None , advice;
    assert named.group(1) == f"musl@{target}" , advice;
    assert native(action="status", names=[named.group(1)]) == 0;
    requested: list[list[str]] = [];
    def fake_build(
        names: list[str],
        log: any,
        force: bool = False,
        exact: bool = False,
        strict: bool = False
    ) -> list[str] {
        requested.append(list(names));
        return list(names);
    }
    with patch.object(router, "build", side_effect=fake_build) {
        assert native(action="build", names=[named.group(1)]) == 0;
    }
    assert requested == [[f"musl@{target}"]] , requested;
    assert native(action="status", names=[f"c-floor@{target}"]) == 0;
    assert native(action="status", names=["musl@"]) == 1;
    assert native(action="status", names=[f"no-such-artifact@{target}"]) == 1;
}

test "a C floor for another target is refused rather than built for the host" {
    import from jaclang.artifacts.kit { osarch }
    import jaclang.compiler.backends.native.floors as floors;
    target = "linux-aarch64" if osarch() == "linux-x86_64" else "linux-x86_64";
    router.forget();
    try {
        with patch.object(
            floors.CFloorArtifact, "probe_checkout", return_value=Probe.missing()
        ), patch.object(floors, "_zig_build") as zig_build {
            try {
                router.build([f"c-floor@{target}"], lambda (line: str) {}, strict=True);
                assert False , "a cross-target C floor build must be refused";
            } except ArtifactUnavailable as e {
                message = str(e);
            }
            zig_build.assert_not_called();
        }
    } finally {
        router._ENTRIES.pop(f"c-floor@{target}", None);
        router.forget();
    }
    assert f"c-floor@{target}:" in message , message;
    assert f"only for this host ({osarch()})" in message , message;
    assert router.artifact_named(f"c-floor@{osarch()}").build_blocker()
        in ("", "zig is not on PATH");
}
