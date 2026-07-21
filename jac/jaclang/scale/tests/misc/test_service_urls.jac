import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.admin.service_urls { service_base_url }
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }

# service_base_url builds the in-cluster URL a gateway uses to reach a sibling
# service. It has three real sources, in precedence order: an explicit env var,
# the K8S_APP_NAME env var, then the kubernetes app_name from scale config -
# with a localhost fallback when none resolve. These assert the real strings the
# pure logic produces for each branch; config-driven branches are fed a real
# jac.toml through get_scale_config(), never a mock of the function under test.

def _seed_k8s_config(k8s_toml: str) -> str {
    project_dir = tempfile.mkdtemp(prefix="jac-svcurl-test-");
    (Path(project_dir) / "jac.toml").write_text(
        "[project]\nname = \"svcurl-test\"\nentry-point = \"main.jac\"\n" + k8s_toml
    );
    reset_scale_config();
    get_scale_config(project_dir=Path(project_dir));
    return project_dir;
}


def _teardown_config(project_dir: str) {
    reset_scale_config();
    shutil.rmtree(project_dir, ignore_errors=True);
}


test "explicit env var wins and is trimmed of whitespace + trailing slashes; port ignored" {
    prev = os.environ.get("SVCURL_EXPLICIT");
    os.environ["SVCURL_EXPLICIT"] = "  http://custom-host:1234///  ";
    try {
        # The env override short-circuits before app_name/port are ever consulted,
        # so the port arg (8000) must not appear in the result.
        assert service_base_url("SVCURL_EXPLICIT", "api", 8000) == "http://custom-host:1234";
    } finally {
        if prev is None {
            os.environ.pop("SVCURL_EXPLICIT", None);
        } else {
            os.environ["SVCURL_EXPLICIT"] = prev;
        }
    }
}


test "K8S_APP_NAME env drives the service host as <app>-<suffix>:<port>" {
    prev_app = os.environ.get("K8S_APP_NAME");
    prev_env = os.environ.pop("SVCURL_UNSET", None);
    os.environ["K8S_APP_NAME"] = "shop";
    try {
        assert service_base_url("SVCURL_UNSET", "gateway", 8000) == "http://shop-gateway:8000";
    } finally {
        if prev_app is None {
            os.environ.pop("K8S_APP_NAME", None);
        } else {
            os.environ["K8S_APP_NAME"] = prev_app;
        }
        if prev_env is not None {
            os.environ["SVCURL_UNSET"] = prev_env;
        }
    }
}


test "scale config app_name drives the host when no env var is set" {
    prev_app = os.environ.pop("K8S_APP_NAME", None);
    prev_env = os.environ.pop("SVCURL_UNSET", None);
    project_dir = _seed_k8s_config("[scale.kubernetes]\napp_name = \"orders\"\n");
    try {
        assert service_base_url("SVCURL_UNSET", "worker", 7000) == "http://orders-worker:7000";
    } finally {
        _teardown_config(project_dir);
        if prev_app is not None {
            os.environ["K8S_APP_NAME"] = prev_app;
        }
        if prev_env is not None {
            os.environ["SVCURL_UNSET"] = prev_env;
        }
    }
}


test "empty app_name in config falls back to http://localhost:<port>" {
    prev_app = os.environ.pop("K8S_APP_NAME", None);
    prev_env = os.environ.pop("SVCURL_UNSET", None);
    project_dir = _seed_k8s_config("[scale.kubernetes]\napp_name = \"\"\n");
    try {
        assert service_base_url("SVCURL_UNSET", "worker", 5555) == "http://localhost:5555";
    } finally {
        _teardown_config(project_dir);
        if prev_app is not None {
            os.environ["K8S_APP_NAME"] = prev_app;
        }
        if prev_env is not None {
            os.environ["SVCURL_UNSET"] = prev_env;
        }
    }
}


test "an unresolved ${VAR} app_name is rejected and falls back to localhost" {
    prev_app = os.environ.pop("K8S_APP_NAME", None);
    prev_env = os.environ.pop("SVCURL_UNSET", None);
    prev_var = os.environ.pop("JAC_SVCURL_NONEXISTENT", None);
    project_dir = _seed_k8s_config(
        "[scale.kubernetes]\napp_name = \"${JAC_SVCURL_NONEXISTENT}\"\n"
    );
    try {
        # expandvars leaves the token intact, so the "${" guard must reject it
        # rather than emit a garbage host like http://${...}-worker:6000.
        assert service_base_url("SVCURL_UNSET", "worker", 6000) == "http://localhost:6000";
    } finally {
        _teardown_config(project_dir);
        if prev_app is not None {
            os.environ["K8S_APP_NAME"] = prev_app;
        }
        if prev_env is not None {
            os.environ["SVCURL_UNSET"] = prev_env;
        }
        if prev_var is not None {
            os.environ["JAC_SVCURL_NONEXISTENT"] = prev_var;
        }
    }
}
