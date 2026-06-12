"""Implementation of JacAPIServerEvents.

Pure reshape helpers (tested with mocked event dicts) + one thin event
list. Reshapes K8s events to a flat, newest-first list and computes a
`pressure` summary that counts the high-signal failure reasons
(OOMKilled, FailedScheduling / Insufficient*, FailedBinding,
ImagePullBackOff, BackOff, Evicted) so an operator sees the smoke without
reading every row.
"""
import asyncio;
import logging;
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint }
import from jac_scale.admin.k8s_ops {
    core_api,
    ops_namespace,
    k8s_available,
    api_error_detail,
    unavailable_detail
}

glob logger = logging.getLogger(__name__),
     # High-signal failure reasons (case-insensitive prefix match).
     _PRESSURE_REASONS: list = [
         "oomkilled",
         "failedscheduling",
         "insufficient",
         "failedbinding",
         "imagepullbackoff",
         "errimagepull",
         "backoff",
         "evicted",
         "failedmount",
         "unhealthy",
         "nodenotready"
     ];


"""'' for None, else str(v)."""
def _s(v: any) -> str {
    if v is None {
        return "";
    }
    return str(v);
}


"""True when a reason matches a known resource/scheduling-pressure
signal (case-insensitive prefix match)."""
def is_pressure_reason(reason: str) -> bool {
    low = (reason or "").lower();
    for r in _PRESSURE_REASONS {
        if low.startswith(r) {
            return True;
        }
    }
    return False;
}


"""Flatten a CoreV1Event dict to {type, reason, message, kind, name,
count, last_seen, pressure}."""
def summarize_event(ev: dict) -> dict {
    involved = ev.get("involved_object", {}) or {};
    reason = _s(ev.get("reason"));
    last = ev.get("last_timestamp") or ev.get("event_time");
    return {
        "type": _s(ev.get("type")),
        "reason": reason,
        "message": _s(ev.get("message")),
        "kind": _s(involved.get("kind")),
        "name": _s(involved.get("name")),
        "count": int(ev.get("count", 1) or 1),
        "last_seen": _s(last),
        "pressure": is_pressure_reason(reason)
    };
}


"""Assemble the events payload from already-listed event dicts (pure).

Sorts Warning-first then by last_seen descending. Done as two stable
passes (newest-first by timestamp, then a stable Warning-first pass that
preserves the timestamp order within each group) - string compare is safe
since RFC3339 timestamps sort lexically. `pressure` is the count of high-
signal reasons; `warnings` the count of Warning-type events."""
def build_events(namespace: str, events: list) -> dict {
    rows = [summarize_event(e) for e in events];
    # Pass 1: newest last_seen first.
    rows.sort(key=lambda r : r.get("last_seen", ""), reverse=True);
    # Pass 2 (stable): Warning rank 0, everything else 1.
    rows.sort(key=lambda r : 0 if r.get("type") == "Warning" else 1);
    pressure = len(
        [
            r
            for r in rows
            if r.get("pressure")
        ]
    );
    warnings = len(
        [
            r
            for r in rows
            if r.get("type") == "Warning"
        ]
    );
    return {
        "available": True,
        "namespace": namespace,
        "events": rows,
        "warnings": warnings,
        "pressure": pressure
    };
}


def _collect_events -> dict {
    if not k8s_available() {
        return {"available": False, "detail": unavailable_detail()};
    }
    core = core_api();
    if core is None {
        return {"available": False, "detail": unavailable_detail()};
    }
    ns = ops_namespace();
    try {
        ev_objs = core.list_namespaced_event(namespace=ns).items;
    } except Exception as e {
        logger.warning(f"events list failed: {e}");
        return {"available": False, "detail": api_error_detail(e)};
    }
    return build_events(ns, [e.to_dict() for e in (ev_objs or [])]);
}


impl JacAPIServerEvents.register_events_endpoints -> None {
    async def events_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get("http_status", 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        try {
            data = await asyncio.to_thread(_collect_events);
        } except Exception as e {
            logger.warning(f"events handler error: {e}");
            data = {"available": False, "detail": f"self-check error: {e}"};
        }
        return JSONResponse(content={"ok": True, "data": data});
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/ops/events",
            callback=events_handler,
            parameters=[],
            response_model=None,
            tags=["Operations"],
            summary="Events + resource pressure",
            description=(
                "Recent namespace events, Warning-first, with a pressure "
                "count for OOMKilled / FailedScheduling / Insufficient* / "
                "FailedBinding / ImagePullBackOff / Evicted. Needs the read-"
                "only Ops Console Role; 'unavailable' off-cluster."
            )
        )
    );
    logger.info("Events endpoint registered: /admin/ops/events");
}
