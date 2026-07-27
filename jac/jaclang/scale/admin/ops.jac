import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.scale.jserver.jserver { HTTPMethod, JEndPoint }

obj JacAPIServerOps {
    def register_ops_endpoints -> None;
}
