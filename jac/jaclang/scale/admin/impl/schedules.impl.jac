import asyncio;
import logging;
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.datatypes { JSONResponse }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }

glob logger = logging.getLogger(__name__);

impl JacAPIServerSchedules.register_schedules_endpoints -> None {
    async def schedules_handler(request: Request) -> JSONResponse {
        guard = self.require_admin_json(request.headers.get("Authorization"));
        if guard {
            return guard;
        }
        scheduler = self.scheduler;
        if scheduler is None {
            return JSONResponse(
                content={"ok": True, "data": {"namespace": "", "schedules": []}}
            );
        }
        rows = await asyncio.to_thread(scheduler.schedules);
        return JSONResponse(
            content={
                "ok": True,
                "data": {"namespace": scheduler.namespace, "schedules": rows}
            }
        );
    }
    server = self.server;
    if server is None {
        return;
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/schedules",
            callback=schedules_handler,
            parameters=[],
            response_model=None,
            tags=["Scheduler"],
            summary="Static @schedule tasks",
            description=(
                "Every static @schedule task this service runs, with its "
                "interval, cron or date, its next run, and its last run on any "
                "worker or replica: the tick, the worker, the status, the "
                "duration and the error."
            )
        )
    );
    logger.info("Schedules endpoint registered: /admin/schedules");
}
