import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}

obj JacAPIServerLLMTelemetry {
    def register_llm_telemetry_endpoints -> None;
}
