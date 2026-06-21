"""Focused tests for V-03 endpoints/ingress/PVC pure reshape helpers."""

import from jac_scale.jserver.jserver { HTTPMethod }
import from jac_scale.jserver.jfast_api { JFastApiServer }
import from jac_scale.admin.network { JacAPIServerNetwork }
import from jac_scale.admin.network {
    summarize_service,
    summarize_ingress,
    pvc_claimants,
    summarize_pvc
}


obj NetworkHost(JacAPIServerNetwork) {
    has server: any = None;
}


test "service surfaces 0 ready backends (the no-endpoints 503 cause)" {
    svc = summarize_service(
        {
            "metadata": {"name": "gateway-service"},
            "spec": {
                "type": "ClusterIP",
                "cluster_ip": "10.0.0.1",
                "ports": [{"port": 80, "target_port": 8000, "protocol": "TCP"}]
            }
        },
        {"gateway-service": {"ready": 0, "not_ready": 0}}
    );
    assert svc["ready_backends"] == 0 and svc["ports"][0]["port"] == 80;
}


test "ingress resolves host->service:port + LB; PVC claimants from pods" {
    ing = summarize_ingress(
        {
            "metadata": {"name": "gw-ing"},
            "spec": {
                "rules": [
                    {
                        "host": "app.example.com",
                        "http": {
                            "paths": [
                                {
                                    "path": "/",
                                    "backend": {
                                        "service": {
                                            "name": "gateway-service",
                                            "port": {"number": 80}
                                        }
                                    }
                                }
                            ]
                        }
                    }
                ]
            },
            "status": {
                "load_balancer": {"ingress": [{"hostname": "abc.elb.amazonaws.com"}]}
            }
        }
    );
    assert ing["rules"][0]["service"] == "gateway-service"
    and ing["lb"] == ["abc.elb.amazonaws.com"];

    claims = pvc_claimants(
        [
            {
                "metadata": {"name": "gw-1"},
                "spec": {
                    "volumes": [{"persistent_volume_claim": {"claim_name": "shared"}}]
                }
            },
            {
                "metadata": {"name": "gw-2"},
                "spec": {
                    "volumes": [{"persistent_volume_claim": {"claim_name": "shared"}}]
                }
            }
        ]
    );
    assert claims["shared"] == ["gw-1", "gw-2"];
    pvc = summarize_pvc(
        {
            "metadata": {"name": "shared"},
            "spec": {},
            "status": {"phase": "Bound", "capacity": {"storage": "5Gi"}}
        },
        claims
    );
    assert pvc["phase"] == "Bound" and pvc["claimants"] == ["gw-1", "gw-2"];
}


test "register adds GET /admin/ops/network" {
    host = NetworkHost();
    host.server = JFastApiServer();
    host.register_network_endpoints();
    eps = [
        e
        for e in host.server._endpoints
        if e.path == "/admin/ops/network"
    ];
    assert len(eps) == 1 and eps[0].method == HTTPMethod.GET;
}
