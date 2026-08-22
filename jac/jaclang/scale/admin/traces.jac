import from jaclang.runtimelib.serving.datatypes { Request }
import from jaclang.runtimelib.serving.datatypes { JSONResponse }
import from jaclang.runtimelib.serving.endpoint {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}

obj JacAPIServerTraces {
    def register_traces_endpoints -> None;
}
