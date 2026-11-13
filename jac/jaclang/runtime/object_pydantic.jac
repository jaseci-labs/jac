import from contextvars { ContextVar }
import from typing { get_type_hints }
import from pydantic { GetCoreSchemaHandler }
import from pydantic_core { core_schema }

glob _schema_refs: ContextVar[dict[object, str] | None] = ContextVar(
         "jac_object_schema_refs", `default=None
     );

def object_schema(
    cls: type, source: object, handler: GetCoreSchemaHandler
) -> core_schema.CoreSchema;

def _build_object_schema(
    cls: type, handler: GetCoreSchemaHandler
) -> core_schema.CoreSchema;
