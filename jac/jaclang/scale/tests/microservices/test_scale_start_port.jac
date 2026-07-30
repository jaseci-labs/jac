import os;
import jaclang.scale.plugin as scale_plugin;


obj _PortStubConfig {
    has _ms: dict = {};

    def get_microservices_config -> dict {
        return self._ms;
    }
}


def _run_scale_start_with(ms: dict, port: int) {
    stub = _PortStubConfig(_ms=ms);

    def _fake_factory(project_dir: object = None) -> object {
        return stub;
    }

    orig = scale_plugin.get_scale_config;
    saved = os.environ.get("JAC_SCALE_RUNTIME");
    setattr(scale_plugin, "get_scale_config", _fake_factory);
    try {
        scale_plugin.scale_start("", False, "kubernetes", False, False, False, port);
    } finally {
        setattr(scale_plugin, "get_scale_config", orig);
        if saved is None {
            os.environ.pop("JAC_SCALE_RUNTIME", None);
        } else {
            os.environ["JAC_SCALE_RUNTIME"] = saved;
        }
    }
}


test "scale_start: explicit -p overrides configured gateway_port" {
    ms = {"enabled": False, "gateway_port": 9000};
    _run_scale_start_with(ms, 8600);
    assert ms["gateway_port"] == 8600;
}


test "scale_start: no -p preserves configured gateway_port" {
    ms = {"enabled": False, "gateway_port": 9000};
    _run_scale_start_with(ms, 0);
    assert ms["gateway_port"] == 9000;
}


test "scale_start: explicit -p sets gateway_port when unconfigured" {
    ms = {"enabled": False};
    _run_scale_start_with(ms, 8600);
    assert ms["gateway_port"] == 8600;
}


test "scale_start: no -p leaves gateway_port unset for the default to apply" {
    ms = {"enabled": False};
    _run_scale_start_with(ms, 0);
    assert "gateway_port" not in ms;
}
