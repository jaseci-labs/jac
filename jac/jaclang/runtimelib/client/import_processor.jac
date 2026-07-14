import from pathlib { Path }
import from typing { TYPE_CHECKING }
import from jaclang.runtimelib.client_bundle { ClientBundleError }

with entry {
    if TYPE_CHECKING {
        import from jaclang.compiler.codeinfo { ClientManifest }
    }
}

class ImportProcessor {}
