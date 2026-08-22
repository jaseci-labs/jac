import from jaclang.runtimelib.serving.datatypes { Request }
import from jaclang.runtimelib.serving.datatypes { JSONResponse }
import from jaclang.runtimelib.serving.endpoint {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}

obj JacAPIServerLogs {
    def register_logs_endpoints -> None;
}
