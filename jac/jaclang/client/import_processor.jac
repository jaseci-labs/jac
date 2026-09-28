import from pathlib { Path }
import from typing { TYPE_CHECKING }

with entry {
    if TYPE_CHECKING {
        import from jaclang.compiler.codeinfo { ClientManifest }
    }
}

class ImportProcessor {}
