import from jaclang.compiler.ir.placement.nodes { Codespace, ContextAwareNode }
import from jaclang.compiler.ir.syntax.nodes { Module }

edge PlacedIn: ContextAwareNode --> Codespace {}

edge DecidedCodespace: Module --> Codespace {}
