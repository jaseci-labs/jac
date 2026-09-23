import sys;
import platform;
import from jaclang.compiler.types.ct_value { CtEnvironment }

def host_ct_environment -> CtEnvironment {
    host_os = "linux";
    if sys.platform.startswith("win") {
        host_os = "windows";
    } elif sys.platform == "darwin" {
        host_os = "darwin";
    }
    return CtEnvironment(os=host_os, arch=platform.machine());
}
