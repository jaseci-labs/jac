import from jaclang.runtimelib.serving.datatypes { Request }
import from jaclang.runtimelib.serving.datatypes { JSONResponse }
import from jaclang.runtimelib.serving.endpoint { HTTPMethod, JEndPoint }

obj JacAPIServerOps {
    def register_ops_endpoints -> None;
}
