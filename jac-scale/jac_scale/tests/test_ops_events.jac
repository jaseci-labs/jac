"""Focused tests for V-05 events/resource-pressure pure helpers."""

import from jac_scale.jserver.jserver { HTTPMethod }
import from jac_scale.jserver.jfast_api { JFastApiServer }
import from jac_scale.admin.events { JacAPIServerEvents }
import from jac_scale.admin.events { is_pressure_reason, build_events }


obj EventsHost(JacAPIServerEvents) {
    has server: any = None;
}


test "pressure reasons match by case-insensitive prefix" {
    assert is_pressure_reason("OOMKilled") == True;
    assert is_pressure_reason("InsufficientMemory") == True;
    assert is_pressure_reason("FailedScheduling") == True;
    assert is_pressure_reason("Started") == False;
}


test "warnings sort first; pressure + warning counts surfaced" {
    out = build_events(
        "ns",
        [
            {
                "type": "Normal",
                "reason": "Started",
                "message": "ok",
                "involved_object": {"kind": "Pod", "name": "p1"},
                "count": 1,
                "last_timestamp": "2026-06-11T10:00:00Z"
            },
            {
                "type": "Warning",
                "reason": "OOMKilled",
                "message": "oom",
                "involved_object": {"kind": "Pod", "name": "p2"},
                "count": 3,
                "last_timestamp": "2026-06-11T09:00:00Z"
            }
        ]
    );
    assert out["events"][0]["reason"] == "OOMKilled" , "warning sorts first";
    assert out["warnings"] == 1 and out["pressure"] == 1;
}


test "register adds GET /admin/ops/events" {
    host = EventsHost();
    host.server = JFastApiServer();
    host.register_events_endpoints();
    eps = [
        e
        for e in host.server._endpoints
        if e.path == "/admin/ops/events"
    ];
    assert len(eps) == 1 and eps[0].method == HTTPMethod.GET;
}
