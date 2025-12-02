"""Collection of passes for Jac IR."""

from ..transform import Alert, BaseTransform, Transform  # noqa: I100
from .annex_pass import JacAnnexPass  # noqa: I100
from .cfg_build_pass import CFGBuildPass  # noqa: I100
from .def_impl_match_pass import DeclImplMatchPass  # noqa: I100
from .import_pass import JacImportDepsPass  # noqa: I100
from .predynamo_pass import PreDynamoPass  # noqa: I100
from .pyast_gen_pass import PyastGenPass  # noqa: I100
from .pyast_load_pass import PyastBuildPass  # type: ignore # noqa: I100
from .pybc_gen_pass import PyBytecodeGenPass  # noqa: I100
from .pyjac_ast_link_pass import PyJacAstLinkPass  # noqa: I100
from .sem_def_match_pass import SemDefMatchPass  # noqa: I100
from .semantic_analysis_pass import SemanticAnalysisPass  # noqa: I100
from .sym_tab_build_pass import SymTabBuildPass, UniPass  # noqa: I100
from .type_checker_pass import TypeCheckPass  # noqa: I100

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
