"""A native kernel session reads typeshed only through the stub catalog. When
the catalog is missing, jac builds it, once, saying so, and goes on with the
kernel; when it cannot be built, the command stops and says why and what to
run. It never quietly falls back to the bytecode compiler."""

import io;
import sys;
import from unittest.mock { patch }
import from jaclang.artifacts.model { ArtifactUnavailable, Probe, Source }
import jaclang.artifacts.router as router;
import jaclang.project.kernel_snapshot as snapshot;
import from jaclang.compiler.types.stubcat.locate { StubcatArtifact }

obj FakeCompiler {
    has catalog: list[bool],
        opened: int = 0,
        _stub_catalog_tried: bool = False;

    def ensure_stub_catalog -> any {
        self.opened += 1;
        return None;
    }
}

obj FakeHost {
    has compiler: FakeCompiler;

    def compiler_for(program: any) -> FakeCompiler {
        return self.compiler;
    }

    def has_active_stub_catalog -> bool {
        return self.compiler.catalog[
            min(self.compiler.opened, len(self.compiler.catalog)) - 1
        ];
    }
}

glob _built: list[list[str]] = [];

def _build_ok(requested: list[str], log: any, **kw: any) -> list[str] {
    _built.append(list(requested));
    return list(requested);
}

def _build_fails(requested: list[str], log: any, **kw: any) -> list[str] {
    _built.append(list(requested));
    raise ArtifactUnavailable("typeshed: the stubs could not be fetched (offline)");
}

def _require(
    compiler: FakeCompiler, builder: any, sealed_image: bool = False
) -> tuple[any, str] {
    err = io.StringIO();
    _built.clear();
    outcome: any = None;
    host: any = FakeHost(compiler=compiler);
    program: any = None;
    router.forget();
    import from jaclang.jac0core { sealed }
    image: any = object() if sealed_image else None;
    try {
        with patch.object(sealed, "_jaclang_image", return_value=image) {
            with patch.object(router, "build", side_effect=builder) {
                with patch.object(
                    StubcatArtifact, "built", return_value=Probe.missing()
                ) {
                    with patch.object(
                        StubcatArtifact,
                        "checkout_path",
                        return_value=_lock_dir() + "/stubcat.bin"
                    ) {
                        with patch.object(sys, "stderr", err) {
                            try {
                                outcome = snapshot.require_stub_catalog(host, program);
                            } except snapshot.StubCatalogMissing as e {
                                outcome = e;
                            }
                        }
                    }
                }
            }
        }
    } finally {
        router.forget();
    }
    return (outcome, err.getvalue());
}

def _lock_dir -> str {
    import tempfile;
    return tempfile.mkdtemp(prefix="jac-stubcat-lock-");
}

test "a present catalog is used as is" {
    compiler = FakeCompiler(catalog=[True]);
    (outcome, said) = _require(compiler, _build_ok);
    assert outcome is True;
    assert _built == [] and said == "" , (_built, said);
}

test "a missing catalog is built once, loudly, and the kernel goes on" {
    compiler = FakeCompiler(catalog=[False, True]);
    (outcome, said) = _require(compiler, _build_ok);
    assert outcome is True , outcome;
    assert _built == [["stubcat"]] , _built;
    assert "needs the stub catalog" in said and "building stubcat now" in said , said;
    assert "runs on its floor" not in said , said;
    assert compiler.opened == 2 , "the catalog is reopened after the build";
}

test "a catalog that cannot be built stops the command with the cause and the command to run" {
    compiler = FakeCompiler(catalog=[False]);
    (outcome, said) = _require(compiler, _build_fails);
    assert isinstance(outcome, snapshot.StubCatalogMissing) , outcome;
    assert outcome.stops_command;
    told = str(outcome.code);
    assert "could not be built" in told , told;
    assert "the stubs could not be fetched (offline)" in told , told;
    assert "jac native build stubcat" in told , told;
    assert "runs on its floor" not in said , said;
}

test "a sealed install with no catalog stops without trying to build" {
    compiler = FakeCompiler(catalog=[False]);
    (outcome, said) = _require(compiler, _build_ok, sealed_image=True);
    assert isinstance(outcome, snapshot.StubCatalogMissing) , outcome;
    assert _built == [] , _built;
    assert "reinstall jac" in str(outcome.code) , outcome.code;
}

test "an offline project missing the typeshed stubs stops without downloading them" {
    import jaclang.project.config as config;
    import from jaclang.compiler.types.stubcat.locate { TypeshedArtifact }
    compiler = FakeCompiler(catalog=[False]);
    with patch.object(config, "offline_mode", return_value=True) {
        with patch.object(TypeshedArtifact, "built", return_value=Probe.missing()) {
            (outcome, said) = _require(compiler, _build_ok);
        }
    }
    assert isinstance(outcome, snapshot.StubCatalogMissing) , outcome;
    assert _built == [] , _built;
    told = str(outcome.code);
    assert "offline" in told and "jac native build stubcat" in told , told;
}

test "an offline project with the typeshed stubs still builds the catalog" {
    import jaclang.project.config as config;
    import from jaclang.compiler.types.stubcat.locate { TypeshedArtifact }
    compiler = FakeCompiler(catalog=[False, True]);
    present = Probe.hit(Source.CHECKOUT, "/typeshed/stdlib", {});
    with patch.object(config, "offline_mode", return_value=True) {
        with patch.object(TypeshedArtifact, "built", return_value=present) {
            (outcome, said) = _require(compiler, _build_ok);
        }
    }
    assert outcome is True , outcome;
    assert _built == [["stubcat"]] , _built;
}

test "building the kernel builds its stub catalog first" {
    import from jaclang.compiler.backends.native.kernel_resolve { KernelArtifact }
    assert "stubcat" in KernelArtifact().requires;
    assert router.build_order(["kernel"]).index("stubcat")
        < router.build_order(["kernel"]).index("kernel");
}
