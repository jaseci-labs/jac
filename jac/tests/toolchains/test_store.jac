import hashlib;
import io;
import json;
import os;
import tarfile;
import zipfile;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch, MagicMock }
import from jaclang.toolchains.store {
    Artifact,
    cache_root,
    extract,
    fetch,
    install,
    file_digest
}

def sample_artifact(data: bytes) -> Artifact {
    return Artifact(
        "sample",
        "1.0",
        "linux-x64",
        "https://example.invalid/tool.zip",
        hashlib.sha256(data).hexdigest()
    );
}

def archive_bytes -> bytes {
    buffer = io.BytesIO();
    with zipfile.ZipFile(buffer, "w") as archive {
        archive.writestr("bin/tool", "ready");
    }
    return buffer.getvalue();
}

def response_for(data: bytes) -> any {
    response = MagicMock();
    response.__enter__.return_value = response;
    response.geturl.return_value = "https://example.invalid/tool.zip";
    response.headers = {"Content-Length": str(len(data))};
    stream = io.BytesIO(data);
    response.read.side_effect = stream.read;
    return response;
}

test "verified download installs once and reuses offline" {
    with TemporaryDirectory() as tmp {
        with patch.dict(os.environ, {"JAC_TOOLCHAIN_DIR": tmp, "JAC_OFFLINE": "0"}) {
            data = archive_bytes();
            artifact = sample_artifact(data);
            with patch(
                "jaclang.toolchains.store.urlopen", return_value=response_for(data)
            ) as network {
                destination = install(artifact, "bin/tool");
                assert (destination / "bin/tool").read_text() == "ready";
                assert network.call_count == 1;
                with patch.dict(os.environ, {"JAC_OFFLINE": "1"}) {
                    assert install(artifact, "bin/tool") == destination;
                    assert fetch(artifact).is_file();
                }
                assert network.call_count == 1;
            }
        }
    }
}

test "checksum failure never publishes a download or installation" {
    with TemporaryDirectory() as tmp {
        with patch.dict(os.environ, {"JAC_TOOLCHAIN_DIR": tmp, "JAC_OFFLINE": "0"}) {
            artifact = sample_artifact(b"expected");
            with patch(
                "jaclang.toolchains.store.urlopen",
                side_effect=[
                    response_for(b"wrong"),
                    response_for(b"wrong"),
                    response_for(b"wrong")
                ]
            ) {
                failed = False;
                try {
                    install(artifact, "bin/tool");
                } except ValueError {
                    failed = True;
                }
                assert failed;
                assert not list(Path(tmp).rglob(".jac-install.json"));
                assert not list(Path(tmp).rglob("*.part"));
            }
        }
    }
}

test "missing executable does not publish an installation" {
    with TemporaryDirectory() as tmp {
        with patch.dict(os.environ, {"JAC_TOOLCHAIN_DIR": tmp, "JAC_OFFLINE": "0"}) {
            data = archive_bytes();
            with patch(
                "jaclang.toolchains.store.urlopen", return_value=response_for(data)
            ) {
                failed = False;
                try {
                    install(sample_artifact(data), "bin/missing");
                } except RuntimeError {
                    failed = True;
                }
                assert failed;
                assert not list(Path(tmp).rglob(".jac-install.json"));
            }
        }
    }
}

test "offline cache misses never contact network" {
    with TemporaryDirectory() as tmp {
        with patch.dict(os.environ, {"JAC_TOOLCHAIN_DIR": tmp, "JAC_OFFLINE": "1"}) {
            with patch("jaclang.toolchains.store.urlopen") as network {
                failed = False;
                try {
                    fetch(sample_artifact(b"missing"));
                } except RuntimeError {
                    failed = True;
                }
                assert failed;
                network.assert_not_called();
            }
        }
    }
}

test "archives cannot escape the installation directory" {
    with TemporaryDirectory() as tmp {
        test_dir = Path(tmp);
        for name in ["../escape", "/absolute", "..\\escape", "C:/escape"] {
            archive = test_dir / "bad.zip";
            with zipfile.ZipFile(archive, "w") as bundle {
                bundle.writestr(name, "bad");
            }
            failed = False;
            try {
                extract(archive, test_dir / "output");
            } except ValueError {
                failed = True;
            }
            assert failed , name;
        }
        assert not (test_dir / "escape").exists();
        archive = test_dir / "bad.tar";
        with tarfile.open(archive, "w") as bundle {
            member = tarfile.TarInfo("../escape");
            member.size = 3;
            bundle.addfile(member, io.BytesIO(b"bad"));
        }
        failed = False;
        try {
            extract(archive, test_dir / "output");
        } except tarfile.FilterError {
            failed = True;
        }
        assert failed;
    }
}

test "artifact identity includes content and rejects unsafe names" {
    first = sample_artifact(b"one");
    second = sample_artifact(b"two");
    assert first.key() != second.key();
    for name in ["../escape", "/absolute", "..", "a/b"] {
        first.name = name;
        failed = False;
        try {
            first.key();
        } except ValueError {
            failed = True;
        }
        assert failed;
    }
}

test "partial downloads retry from an empty temporary file" {
    with TemporaryDirectory() as tmp {
        with patch.dict(os.environ, {"JAC_TOOLCHAIN_DIR": tmp, "JAC_OFFLINE": "0"}) {
            data = archive_bytes();
            truncated = response_for(data[:5]);
            truncated.headers = {"Content-Length": str(len(data))};
            with patch(
                "jaclang.toolchains.store.urlopen",
                side_effect=[truncated, response_for(data)]
            ) as network {
                result = fetch(sample_artifact(data));
                assert result.read_bytes() == data;
                assert network.call_count == 2;
            }
        }
    }
}


test "concurrent builds publish one complete installation" {
    import from concurrent.futures { ThreadPoolExecutor }
    with TemporaryDirectory() as tmp {
        with patch.dict(os.environ, {"JAC_TOOLCHAIN_DIR": tmp, "JAC_OFFLINE": "0"}) {
            data = archive_bytes();
            artifact = sample_artifact(data);
            with patch(
                "jaclang.toolchains.store.urlopen", return_value=response_for(data)
            ) as network {
                with ThreadPoolExecutor(max_workers=2) as pool {
                    first = pool.submit(install, artifact, "bin/tool");
                    second = pool.submit(install, artifact, "bin/tool");
                    assert first.result(timeout=15) == second.result(timeout=15);
                    assert (first.result() / "bin/tool").read_text() == "ready";
                }
                assert network.call_count == 1;
            }
        }
    }
}

test "zip extraction preserves executable permissions" {
    with TemporaryDirectory() as tmp {
        archive = Path(tmp) / "tool.zip";
        with zipfile.ZipFile(archive, "w") as bundle {
            member = zipfile.ZipInfo("bin/tool");
            member.external_attr = 0o100755 << 16;
            bundle.writestr(member, "executable");
        }
        target = Path(tmp) / "out";
        extract(archive, target);
        if os.name != "nt" {
            assert (target / "bin/tool").stat().st_mode & 0o111;
        }
    }
}
