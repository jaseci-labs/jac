"""Collection of passes for Jac IR."""

from ..transform import Alert, BaseTransform, Transform
from .annex_pass import JacAnnexPass
from .cfg_build_pass import CFGBuildPass
from .def_impl_match_pass import DeclImplMatchPass
from .import_pass import JacImportDepsPass
from .predynamo_pass import PreDynamoPass
from .pyast_gen_pass import PyastGenPass
from .pyast_load_pass import PyastBuildPass  # type: ignore
from .pybc_gen_pass import PyBytecodeGenPass
from .pyjac_ast_link_pass import PyJacAstLinkPass
from .sem_def_match_pass import SemDefMatchPass
from .semantic_analysis_pass import SemanticAnalysisPass
from .sym_tab_build_pass import SymTabBuildPass, UniPass
from .type_checker_pass import TypeCheckPass

__all__ = [
    "Alert",
    "BaseTransform",
    "Transform",
    "UniPass",
    "JacAnnexPass",
    "JacImportDepsPass",
    "TypeCheckPass",
    "SymTabBuildPass",
    "SemanticAnalysisPass",
    "DeclImplMatchPass",
    "SemDefMatchPass",
    "PyastBuildPass",
    "PyastGenPass",
    "PreDynamoPass",
    "PyBytecodeGenPass",
    "CFGBuildPass",
    "PyJacAstLinkPass",
]
