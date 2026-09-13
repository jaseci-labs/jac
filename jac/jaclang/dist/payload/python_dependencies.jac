import hashlib;
import csv;
import json;
import shutil;
import subprocess;
import tarfile;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.dist.payload.artifacts { ArtifactStore }
import from jaclang.dist.payload.python_runtime { interpreter_identity }

def install_dependencies(python: str, site: str, cache_dir: str) -> bool {
    import from jaclang.dist.payload.assemble { tar_stage }
    requirements = Path(__file__).with_name("python_dependencies.txt");
    identity = interpreter_identity(python);
    installer = subprocess.run(
        [
            python,
            "-I",
            "-c",
            "import ensurepip, hashlib, pathlib; "
            "wheel = next(pathlib.Path(ensurepip.__file__).parent.joinpath('_bundled').glob('pip-*.whl')); "
            "print(hashlib.sha256(wheel.read_bytes()).hexdigest())"
        ],
        check=True,
        capture_output=True,
        text=True
    );
    identity["installer"] = installer.stdout.strip();
    digest = hashlib.sha256(json.dumps(identity, sort_keys=True).encode());
    digest.update(requirements.read_bytes());
    digest.update(Path(__file__).read_bytes());

    digest.update(
        Path(__file__).with_name("impl").joinpath("assemble.impl.jac").read_bytes()
    );
    key = digest.hexdigest();
    store = ArtifactStore(Path(cache_dir));
    with TemporaryDirectory() as work {
        archive = Path(work) / "dependencies.tar";
        outputs = {"dependencies.tar": archive};
        with store.lock("python_dependencies", key) {
            reused = store.restore("python_dependencies", key, outputs);
            if not reused {
                bootstrap = Path(work) / "installer";
                script = (
                    "import ensurepip, pathlib, runpy, sys; "
                    "wheel = next(pathlib.Path(ensurepip.__file__).parent.joinpath('_bundled').glob('pip-*.whl')); "
                    "sys.path.insert(0, str(wheel)); sys.argv = ['pip'] + sys.argv[1:]; "
                    "runpy.run_module('pip', run_name='__main__')"
                );
                target = Path(work) / "dependencies";
                subprocess.run(
                    [
                        python,
                        "-I",
                        "-c",
                        script,
                        "install",
                        "--quiet",
                        "--disable-pip-version-check",
                        "--no-compile",
                        "--only-binary=:all:",
                        "--require-hashes",
                        "--no-deps",
                        "--target",
                        str(bootstrap),
                        "-r",
                        str(requirements)
                    ],
                    check=True
                );

                shutil.rmtree(bootstrap / "bin", ignore_errors=True);
                for record in bootstrap.glob("*.dist-info/RECORD") {
                    with record.open(newline="") as stream {
                        rows = [
                            row
                            for row in csv.reader(stream)
                            if (bootstrap / row[0]).is_file()
                        ];
                    }
                    with record.open("w", newline="") as stream {
                        csv.writer(stream, lineterminator="\n").writerows(sorted(rows));
                    }
                }
                shutil.move(str(bootstrap), str(target));
                (deps_tar, _) = tar_stage(str(target));
                archive.write_bytes(deps_tar);
                store.publish("python_dependencies", key, outputs);
            }
        }
        with tarfile.open(archive, "r:") as archive_file {
            archive_file.extractall(site, filter="data");
        }
    }
    return reused;
}
