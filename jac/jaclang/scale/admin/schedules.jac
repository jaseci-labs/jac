import from jaclang.server.serving.datatypes { JSONResponse }
import from jaclang.server.server { EndpointHost }
import from jaclang.server.task_scheduler { Scheduler }

obj JacAPIServerSchedules {
    has server: (EndpointHost | None) = None,
        scheduler: (Scheduler | None) = None;

    def require_admin_json(Authorization: str | None) -> (JSONResponse | None) abst;
    def register_schedules_endpoints -> None;
}
