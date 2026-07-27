import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}

obj JacAPIServerTraces {
    def register_traces_endpoints -> None;
}
