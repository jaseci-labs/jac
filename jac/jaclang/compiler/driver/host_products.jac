def bytecode_passes(request: ProductRequest) -> PassSchedule;

def native_object_passes(request: ProductRequest) -> PassSchedule;

def format_passes(request: ProductRequest) -> PassSchedule;

def format_lintfix_passes(request: ProductRequest) -> PassSchedule;

def python_ast_passes(request: ProductRequest) -> PassSchedule;

def grammar_passes(request: ProductRequest) -> PassSchedule;

def cfg_dot_passes(request: ProductRequest) -> PassSchedule;

def normalize_passes(request: ProductRequest) -> PassSchedule;

def unparse_passes(request: ProductRequest) -> PassSchedule;

def doc_passes(request: ProductRequest) -> PassSchedule;

def format_text_passes(request: ProductRequest) -> PassSchedule;

glob HOST_PRODUCTS: list[CompilationProduct] = [
         CompilationProduct.BYTECODE,
         CompilationProduct.NATIVE_OBJECT,
         CompilationProduct.FORMAT,
         CompilationProduct.FORMAT_LINTFIX,
         CompilationProduct.PYTHON_AST,
         CompilationProduct.GRAMMAR,
         CompilationProduct.CFG_DOT,
         CompilationProduct.NORMALIZE,
         CompilationProduct.UNPARSE,
         CompilationProduct.DOC,
         CompilationProduct.FORMAT_TEXT
     ];

def register_host_products;
