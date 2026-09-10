"""Typed values must survive a real process boundary (#9101)."""

import shutil;
import requests;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.scale.tests.support { get_free_port, start_server, stop_server }

test "split services recursively reconstruct returned archetypes" {
    fixture = Path(__file__).parent.parent / "fixtures" / "typed_boundary";
    with TemporaryDirectory() as tmp {
        project = Path(tmp);
        shutil.copytree(
            fixture, project, dirs_exist_ok=True, ignore=shutil.ignore_patterns(".jac")
        );
        # Keep subprocesses on the same compiler source as the test runner.
        import jaclang;
        with (project / "jac.toml").open("a") as manifest {
            manifest.write(
                "\n[dev]\njaclang_source = "
                    + repr(str(Path(jaclang.__file__).parent.parent))
                    + "\n"
            );
        }
        provider_port = get_free_port();
        consumer_port = get_free_port();
        other_port = get_free_port();
        provider = None;
        consumer = None;
        other = None;
        try {
            provider = start_server(
                project, project / "scoring.jac", provider_port, {"JAC_SV_SIBLING": "1"}
            );
            other = start_server(
                project,
                project / "other_service.jac",
                other_port,
                {"JAC_SV_SIBLING": "1"}
            );
            consumer = start_server(
                project,
                project / "consumer.jac",
                consumer_port,
                {
                    "JAC_SV_SIBLING": "1",
                    "JAC_APP_SCORING_URL": f"http://127.0.0.1:{provider_port}",
                    "JAC_APP_OTHER_URL": f"http://127.0.0.1:{other_port}"
                }
            );
            response = requests.post(
                f"http://127.0.0.1:{consumer_port}/function/check_score",
                json={},
                timeout=30
            );
            assert response.status_code == 200 , response.text;
            body = response.json();
            assert body["ok"] , body;
            result = body["data"]["result"];
            assert result["owner"] == "jaseci-labs";
            assert result["provider_pid"] == provider.pid;
            assert result["consumer_pid"] == consumer.pid;
            assert provider.pid != consumer.pid;
            assert result["provider_loaded"] is False;
            errors: list[str] = [];
            for endpoint in [
                "check_collections",
                "check_walker",
                "check_provider_alias",
                "check_inherited",
                "check_distinct_types"
            ] {
                response = requests.post(
                    f"http://127.0.0.1:{consumer_port}/function/{endpoint}",
                    json={},
                    timeout=30
                );
                if response.status_code != 200 {
                    errors.append(f"{endpoint}: {response.text}");
                } else {
                    assert response.json()["data"]["result"] is True , response.text;
                }
            }
            assert not errors , "\n".join(errors);
            response = requests.post(
                f"http://127.0.0.1:{consumer_port}/function/forward_score",
                json={},
                timeout=30
            );
            assert response.status_code == 200 , response.text;
            forwarded = response.json()["data"]["result"];
            assert forwarded["_jac_type"] == "ScoredPayload";
            assert forwarded["meta"]["_jac_type"] == "RepoMeta";
            assert forwarded["analysis"]["meta"]["_jac_type"] == "RepoMeta";
        } finally {
            stop_server(consumer);
            stop_server(provider);
            stop_server(other);
            for server in [consumer, provider, other] {
                if server is not None {
                    (stdout, stderr) = server.communicate();
                    print(stdout + stderr);
                }
            }
        }
    }
}
