"""Focused tests for V-04 pod-env allowlist redaction + registration.

Redaction is the safety-critical bit: only allowlisted keys show their
value; secretRef values are never resolved.
"""

import from jac_scale.jserver.jserver { HTTPMethod }
import from jac_scale.jserver.jfast_api { JFastApiServer }
import from jac_scale.admin.podenv { JacAPIServerPodEnv }
import from jac_scale.admin.podenv { redact_entry, pod_env_entries }


obj PodEnvHost(JacAPIServerPodEnv) {
    has server: any = None;
}


test "redaction: allowlisted shown, others masked, secrets never resolved" {
    prefixes = ["OTEL_", "JAC_", "K8S_"];

    allowed = redact_entry(
        {"name": "OTEL_EXPORTER_OTLP_ENDPOINT", "value": "http://x:4318", "source": ""},
        prefixes
    );
    assert allowed["shown"] == True and allowed["value"] == "http://x:4318";

    masked = redact_entry(
        {"name": "MONGODB_URI", "value": "mongodb://u:p@h", "source": ""}, prefixes
    );
    assert masked["shown"] == False and "mongodb://" not in masked["value"];

    secret = redact_entry(
        {"name": "JAC_SECRET", "value": "", "source": "secret"}, prefixes
    );
    assert secret["value"] == "(from secret)" , "secretRef never resolved";
}


test "pod_env_entries reads literals + tags valueFrom source" {
    entries = pod_env_entries(
        {
            "spec": {
                "containers": [
                    {
                        "env": [
                            {"name": "JAC_BUILD_SHA", "value": "abc"},
                            {
                                "name": "MONGODB_URI",
                                "value_from": {
                                    "secret_key_ref": {"name": "s", "key": "uri"}
                                }
                            }
                        ]
                    }
                ]
            }
        }
    );
    assert entries[0]["source"] == "" and entries[1]["source"] == "secret";
}


test "register adds GET /admin/ops/podenv" {
    host = PodEnvHost();
    host.server = JFastApiServer();
    host.register_podenv_endpoints();
    eps = [
        e
        for e in host.server._endpoints
        if e.path == "/admin/ops/podenv"
    ];
    assert len(eps) == 1 and eps[0].method == HTTPMethod.GET;
}
