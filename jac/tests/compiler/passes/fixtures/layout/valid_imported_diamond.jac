import from .imported_ancestry { Root, Expr }

node Token(Root) {}
node EnumBlockStmt(Root) {}
node AtomExpr(Expr) {}
node NameAtom(AtomExpr, EnumBlockStmt) {}
node Name(Token, NameAtom) {}
node Literal(Token, AtomExpr) {}
node BuiltinType(Name, Literal) {}
