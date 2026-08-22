import from jaclang.runtimelib.serving.datatypes { Request }
import from jaclang.runtimelib.serving.datatypes { JSONResponse }
import from jaclang.runtimelib.serving.endpoint {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}

obj JacAPIServerLLMTelemetry {
    def register_llm_telemetry_endpoints -> None;
}
