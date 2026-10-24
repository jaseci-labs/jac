import os;
import sys;

import from jaclang { JacRuntime as Jac }

obj PreparedInProcessRuntime {
    has server: any,
        transport_kind: str,
        client: any | None = None,
        _prior_ctx: (ExecutionContext | None) = None;

    def close;
}


def _extensions_for(profile: str) -> list[ServerExtension];


def prepare_inprocess_runtime(
    jac_file: str,
    base_path: str,
    endpoint_profile: str = "full",
    setup_background_services: bool = True,
    transport_kind: str = "testclient",
    extensions: (list[ServerExtension] | None) = None,
    overrides: (dict[str, any] | None) = None
) -> PreparedInProcessRuntime;
