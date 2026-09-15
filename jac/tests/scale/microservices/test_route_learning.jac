"""Route learning must not cache what a service said while it was booting.

Services start cold: the first `jac run` of a fleet compiles each one, and a
service that has not finished compiling either says nothing or answers
/openapi.json with a 404. Caching that answer for the refresh window means the
gateway permanently misses the routes of every service that was slow to start.
A service is only quotable once it is healthy.
"""

import from jaclang.scale.runtime.gateway.route_table { ServiceRouteTable }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceEntry,
    ServiceStatus
}


def _entry(status: ServiceStatus) -> ServiceEntry {
    return ServiceEntry(
        name="scoring",
        file="scoring.jac",
        prefix="/scoring",
        port=9001,
        url="http://127.0.0.1:9001",
        status=status
    );
}


test "a booting service is always due for another spec probe" {
    table = ServiceRouteTable();
    svc = _entry(ServiceStatus.STARTING);
    table.mark_spec_seen(svc, 100.0);

    assert table.spec_due(svc, 100.0, 30.0) , (
        "a service that was still compiling when it answered must be asked "
        "again on the next request, not written off for the refresh window"
    );
}


test "a healthy service's spec is cached until the refresh window elapses" {
    table = ServiceRouteTable();
    svc = _entry(ServiceStatus.HEALTHY);
    table.mark_spec_seen(svc, 100.0);

    assert not table.spec_due(svc, 110.0, 30.0);
    assert table.spec_due(svc, 140.0, 30.0) , (
        "past the refresh window every service is asked again"
    );
}


test "becoming healthy makes a service due again" {
    table = ServiceRouteTable();
    svc = _entry(ServiceStatus.STARTING);
    table.mark_spec_seen(svc, 100.0);
    svc.status = ServiceStatus.HEALTHY;

    assert table.spec_due(svc, 101.0, 30.0);
}
