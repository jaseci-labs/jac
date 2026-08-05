obj RpcClientEmitter {
    has package_name: str = "dev.jac.generated";

    def emit(manifest: any) -> str;
    def jac_type_to_kotlin(jac_type: str) -> str;
}

def emit_jac_client(package_name: str, manifest: any) -> str;
def walker_to_pascal(walker_name: str) -> str;
def kotlin_default_literal(jac_type: str, value: any) -> (str | None);
