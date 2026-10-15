import hashlib;
import os;
import tempfile;
import threading;
import time;
import from contextlib { ExitStack }
import from pathlib { Path }
import from unittest.mock { patch }
import jaclang.byllm.model_cache as model_cache;
import from jaclang.byllm.model_cache {
    ensure_model,
    force_pull,
    gguf_path,
    is_downloaded,
    weight_status
}
import from jaclang.byllm.local_runtime { LOCAL_MODELS }
import from jaclang.byllm.cli { model }
import from jaclang.cli.console { console }

glob GOOD: bytes = b"GGUF" + bytes(range(60)),
     ALIAS: str = "tiny-model";

def spec_for(data: bytes) -> dict[str, any] {
    return {
        "repo": "test/tiny",
        "file": "tiny.gguf",
        "revision": "0" * 40,
        "sha256": hashlib.sha256(data).hexdigest(),
        "size_bytes": len(data),
        "size_mb": 0,
        "description": "fixture"
    };
}

glob SPEC: dict[str, any] = spec_for(GOOD);

"""Point the cache at `cache_dir`, make every download stage `payload`, and set consent."""
def use_fixture_cache(
    stack: ExitStack,
    cache_dir: Path,
    payload: bytes,
    calls: list[str],
    consent: bool,
    delay: float = 0.0,
    started: threading.Event | None = None
) {
    def fake_download(alias: str, spec: dict[str, any]) -> Path {
        calls.append(alias);
        if started is not None {
            started.set();
        }
        assert not gguf_path(alias, spec).exists()
            or weight_status(alias, spec) != "valid" , "downloaded over a valid weight";
        staging = cache_dir / alias / ".jac_partial";
        staging.mkdir(parents=True, exist_ok=True);
        staged = staging / spec["file"];
        staged.write_bytes(payload[:len(payload) // 2]);
        time.sleep(delay);
        staged.write_bytes(payload);
        return staged;
    }
    stack.enter_context(
        patch.object(model_cache, "get_cache_dir", return_value=cache_dir)
    );
    stack.enter_context(
        patch.object(model_cache, "_download", side_effect=fake_download)
    );
    stack.enter_context(
        patch.dict(os.environ, {"BYLLM_AUTO_DOWNLOAD": "1" if consent else "0"})
    );
}

test "a truncated or modified weight is not reported as downloaded" {
    with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack {
        use_fixture_cache(stack, Path(tmp), GOOD, [], consent=False);
        target = gguf_path(ALIAS, SPEC);
        target.parent.mkdir(parents=True);
        target.write_bytes(b"not a model file");
        assert weight_status(ALIAS, SPEC) == "invalid";
        assert not is_downloaded(ALIAS, SPEC);
        target.write_bytes(GOOD[:-1] + b"\x00");
        assert weight_status(ALIAS, SPEC) == "invalid" , "same size, wrong digest";
        target.write_bytes(GOOD);
        assert weight_status(ALIAS, SPEC) == "valid";
        target.write_bytes(GOOD[:10]);
        assert weight_status(ALIAS, SPEC) == "invalid" , "truncated after it was verified";
    }
}

test "a verified weight is trusted by its stamp until the file changes" {
    with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack {
        use_fixture_cache(stack, Path(tmp), GOOD, [], consent=False);
        hashing = stack.enter_context(
            patch.object(model_cache, "_file_sha256", wraps=model_cache._file_sha256)
        );
        target = gguf_path(ALIAS, SPEC);
        target.parent.mkdir(parents=True);
        target.write_bytes(GOOD);
        assert weight_status(ALIAS, SPEC) == "valid";
        assert weight_status(ALIAS, SPEC) == "valid";
        assert hashing.call_count == 1 , "a stamped weight must not be hashed again";
        stat = target.stat();
        os.utime(target, ns=(stat.st_atime_ns, stat.st_mtime_ns + 1000000000));
        assert weight_status(ALIAS, SPEC) == "valid";
        assert hashing.call_count == 2 , "a changed file must be verified again";
    }
}

test "an invalid weight is refused with a repair command instead of being loaded" {
    with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack {
        calls: list[str] = [];
        use_fixture_cache(stack, Path(tmp), GOOD, calls, consent=False);
        target = gguf_path(ALIAS, SPEC);
        target.parent.mkdir(parents=True);
        target.write_bytes(b"not a model file");
        try {
            ensure_model(ALIAS, SPEC);
            assert False , "ensure_model handed out a corrupt weight";
        } except RuntimeError as err {
            assert "failed verification" in str(err) , str(err);
            assert f"jac model pull {ALIAS}" in str(err) , str(err);
        }
        assert calls == [];
    }
}

test "a forced pull replaces an invalid weight" {
    with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack {
        calls: list[str] = [];
        use_fixture_cache(stack, Path(tmp), GOOD, calls, consent=True);
        target = gguf_path(ALIAS, SPEC);
        target.parent.mkdir(parents=True);
        target.write_bytes(b"not a model file");
        assert force_pull(ALIAS, SPEC) == str(target);
        assert calls == [ALIAS];
        assert target.read_bytes() == GOOD;
        assert weight_status(ALIAS, SPEC) == "valid";
        assert not (target.parent / ".jac_partial").exists() , "staging was left behind";
    }
}

test "a download that fails verification installs nothing" {
    with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack {
        use_fixture_cache(stack, Path(tmp), GOOD[:-1] + b"!", [], consent=True);
        try {
            force_pull(ALIAS, SPEC);
            assert False , "a download with the wrong digest was installed";
        } except RuntimeError as err {
            assert "failed verification" in str(err) , str(err);
        }
        target = gguf_path(ALIAS, SPEC);
        assert not target.exists();
        assert not (target.parent / ".jac_partial" / "tiny.gguf").exists();
        assert weight_status(ALIAS, SPEC) == "missing";
    }
}

test "an interrupted download is incomplete, never ready" {
    with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack {
        use_fixture_cache(stack, Path(tmp), GOOD, [], consent=False);
        partial = gguf_path(ALIAS, SPEC).parent
            / ".jac_partial"
            / "tiny.gguf.incomplete";
        partial.parent.mkdir(parents=True);
        partial.write_bytes(GOOD[:20]);
        assert weight_status(ALIAS, SPEC) == "incomplete";
        assert not is_downloaded(ALIAS, SPEC);
        try {
            ensure_model(ALIAS, SPEC);
            assert False , "an incomplete download was handed out";
        } except RuntimeError as err {
            assert "is not downloaded" in str(err) , str(err);
        }
    }
}

test "concurrent pulls download once and never expose a partial target" {
    with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack {
        calls: list[str] = [];
        use_fixture_cache(stack, Path(tmp), GOOD, calls, consent=True, delay=0.3);
        results: list[str] = [];
        errors: list[str] = [];
        def pull {
            try {
                results.append(force_pull(ALIAS, SPEC));
            } except Exception as err {
                errors.append(repr(err));
            }
        }
        workers = [threading.Thread(target=pull) for _ in range(2)];
        for worker in workers {
            worker.start();
        }
        for worker in workers {
            worker.join();
        }
        assert errors == [] , errors;
        assert calls == [ALIAS] , f"expected one download, got {calls}";
        assert results == [str(gguf_path(ALIAS, SPEC))] * 2;
        assert gguf_path(ALIAS, SPEC).read_bytes() == GOOD;
    }
}

test "removing a model waits for an in-progress pull instead of breaking it" {
    with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack {
        started = threading.Event();
        use_fixture_cache(
            stack, Path(tmp), GOOD, [], consent=True, delay=0.5, started=started
        );
        errors: list[str] = [];
        def pull {
            try {
                force_pull(ALIAS, SPEC);
            } except Exception as err {
                errors.append(repr(err));
            }
        }
        worker = threading.Thread(target=pull);
        worker.start();
        assert started.wait(5) , "the pull never started downloading";
        assert model_cache.remove_alias(ALIAS);
        worker.join();
        assert errors == [] , f"removal broke the pull in progress: {errors}";
        assert weight_status(ALIAS, SPEC) == "missing";
        assert (Path(tmp) / ".locks").is_dir() , "the lock must outlive the alias directory";
    }
}

test "jac model rm refuses a name that is not an alias" {
    with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack {
        cache = Path(tmp) / "models";
        cache.mkdir();
        keep = Path(tmp) / "keep.txt";
        keep.write_text("other cache data\n");
        use_fixture_cache(stack, cache, GOOD, [], consent=False);
        for name in ["..", ".", "../models", ".locks", "a/b"] {
            try {
                model_cache.remove_alias(name);
                assert False , f"remove_alias accepted {name!r}";
            } except ValueError {}
        }
        assert keep.read_text() == "other cache data\n";
        stack.enter_context(patch.object(console, "error"));
        assert model(action="rm", alias="..") == 2;
        assert keep.exists() and cache.is_dir();
    }
}

test "jac model list marks invalid and incomplete weights, and pull repairs them" {
    with tempfile.TemporaryDirectory() as tmp, ExitStack() as stack {
        calls: list[str] = [];
        use_fixture_cache(stack, Path(tmp), GOOD, calls, consent=True);
        stack.enter_context(
            patch.dict(
                LOCAL_MODELS,
                {"ok": SPEC, "bad": SPEC, "partial": SPEC, "absent": SPEC},
                clear=True
            )
        );
        lines: list[str] = [];
        def record(*args: any, **kwargs: any) {
            lines.append(" ".join(str(arg) for arg in args));
        }
        for method in ["print", "info", "warning", "error"] {
            stack.enter_context(patch.object(console, method, side_effect=record));
        }
        for name in ["ok", "bad"] {
            gguf_path(name, SPEC).parent.mkdir(parents=True);
        }
        gguf_path("ok", SPEC).write_bytes(GOOD);
        gguf_path("bad", SPEC).write_bytes(b"not a model file");
        partial = gguf_path("partial", SPEC).parent
            / ".jac_partial"
            / "tiny.gguf.incomplete";
        partial.parent.mkdir(parents=True);
        partial.write_bytes(GOOD[:20]);
        assert model(action="list") == 0;
        rows = {
            line.split()[0]: line
            for line in lines
            if line.startswith("  ")
        };
        assert "downloaded" in rows["ok"] , rows;
        assert "invalid" in rows["bad"] , rows;
        assert "incomplete" in rows["partial"] , rows;
        assert "not cached" in rows["absent"] , rows;
        assert any("jac model pull bad" in line for line in lines) , lines;
        assert any("jac model pull partial" in line for line in lines) , lines;
        assert model(action="pull", alias="bad") == 0;
        assert calls == ["bad"];
        assert weight_status("bad", SPEC) == "valid";
        assert model(action="pull", alias="ok") == 0;
        assert calls == ["bad"] , "a valid weight must not be downloaded again";
    }
}
