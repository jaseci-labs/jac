"""Plugin for Jac's with_llm feature."""

import ast as ast3
import inspect
from typing import (
    Any,
    Callable,
    Mapping,
    Optional,
    Sequence,
    TypeAlias,
    cast,
    get_type_hints,
)

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes.main.pyast_gen_pass import PyastGenPass
from jaclang.runtimelib.machine import JacMachine as Jac, hookimpl

# from jaclang.runtimelib.utils import extract_params, extract_type, get_sem_scope

from mtllm.aott import (
    aott_raise,
    get_all_type_explanations,
)
from mtllm.llm import JacLLM
from mtllm.llms.base import (
    BaseLLM,
    CompletionRequest,
    INSTRUCTION_TOOL,
    Message,
    MessageRole,
    SYSTEM_PERSONA,
    Tool as newTool,
)
from mtllm.semtable import SemInfo, SemRegistry, SemScope
from mtllm.types import Information, InputInformation, OutputHint, Tool


def extract_params(
    body: uni.FuncCall,
) -> tuple[dict[str, uni.Expr], list[tuple[str, ast3.AST]], list[tuple[str, ast3.AST]]]:
    """Extract model parameters, include and exclude information."""
    model_params = {}
    include_info = []
    exclude_info = []
    if body.params:
        for param in body.params:
            if isinstance(param, uni.KWPair) and isinstance(param.key, uni.Name):
                key = param.key.value
                value = param.value
                if key not in ["incl_info", "excl_info"]:
                    model_params[key] = value
                elif key == "incl_info":
                    if isinstance(value, uni.AtomUnit):
                        var_name = (
                            value.value.right.value
                            if isinstance(value.value, uni.AtomTrailer)
                            and isinstance(value.value.right, uni.Name)
                            else (
                                value.value.value
                                if isinstance(value.value, uni.Name)
                                else ""
                            )
                        )
                        include_info.append((var_name, value.gen.py_ast[0]))
                    elif isinstance(value, uni.TupleVal) and value.values:
                        for i in value.values:
                            var_name = (
                                i.right.value
                                if isinstance(i, uni.AtomTrailer)
                                and isinstance(i.right, uni.Name)
                                else (i.value if isinstance(i, uni.Name) else "")
                            )
                            include_info.append((var_name, i.gen.py_ast[0]))
                elif key == "excl_info":
                    if isinstance(value, uni.AtomUnit):
                        var_name = (
                            value.value.right.value
                            if isinstance(value.value, uni.AtomTrailer)
                            and isinstance(value.value.right, uni.Name)
                            else (
                                value.value.value
                                if isinstance(value.value, uni.Name)
                                else ""
                            )
                        )
                        exclude_info.append((var_name, value.gen.py_ast[0]))
                    elif isinstance(value, uni.TupleVal) and value.values:
                        for i in value.values:
                            var_name = (
                                i.right.value
                                if isinstance(i, uni.AtomTrailer)
                                and isinstance(i.right, uni.Name)
                                else (i.value if isinstance(i, uni.Name) else "")
                            )
                            exclude_info.append((var_name, i.gen.py_ast[0]))
    return model_params, include_info, exclude_info


def get_sem_scope(node: uni.UniNode) -> SemScope:
    """Get scope of the node."""
    a = (
        node.name
        if isinstance(node, uni.Module)
        else (
            node.name.value
            if isinstance(node, (uni.Enum, uni.Archetype))
            else node.name_ref.sym_name if isinstance(node, uni.Ability) else ""
        )
    )
    if isinstance(node, uni.Module):
        return SemScope(a, "Module", None)
    elif isinstance(node, (uni.Enum, uni.Archetype, uni.Ability)):
        node_type = (
            node.__class__.__name__
            if isinstance(node, uni.Enum)
            else ("Ability" if isinstance(node, uni.Ability) else node.arch_type.value)
        )
        if node.parent:
            return SemScope(
                a,
                node_type,
                get_sem_scope(node.parent),
            )
    else:
        if node.parent:
            return get_sem_scope(node.parent)
    return SemScope("", "", None)


def extract_type(node: uni.UniNode) -> list[str]:
    """Collect type information in assignment using bfs."""
    extracted_type = []
    if isinstance(node, (uni.BuiltinType, uni.Token)):
        extracted_type.append(node.value)
    for child in node.kid:
        extracted_type.extend(extract_type(child))
    return extracted_type


def callable_to_tool(tool: Callable, mod_registry: SemRegistry) -> Tool:
    """Convert a callable to a Tool."""
    assert callable(tool), f"{tool} cannot be used as a tool"
    tool_name = tool.__name__
    _, tool_info = mod_registry.lookup(name=tool_name)
    assert tool_info and isinstance(
        tool_info, SemInfo
    ), f"Tool {tool_name} not found in the registry"
    return Tool(tool, tool_info, tool_info.get_children(mod_registry, uni.ParamVar))


FuncSemStr: TypeAlias = tuple[str, dict[str, str]]  # (func_semstr, param_semstr)


def semstr_of_func(func: Callable, scope: str) -> FuncSemStr:
    """Get the semstr of a function as a Tool."""
    if hasattr(func, "__semstrs__"):
        return func.__semstrs__  # type: ignore
    # -------------------------------------------------------------------------
    # FIXME: This entire SemScope, SemRegistry is here to get the function
    # Get them from the Jac Machine itself and remove the SemRegistry completely.
    program_head = Jac.program.mod
    _scope = SemScope.get_scope_from_str(scope) or SemScope(
        program_head.main.name, "Module", None
    )
    mod_registry = SemRegistry(program_head=program_head, by_scope=_scope)
    _, tool_info = mod_registry.lookup(name=func.__name__)
    assert isinstance(tool_info, SemInfo)
    params_info = tool_info.get_children(mod_registry, uni.ParamVar)
    # -------------------------------------------------------------------------
    func_semstr = tool_info.semstr or func.__doc__ or ""
    param_semstr = {info.name: info.semstr for info in params_info}
    # Cache the output.
    func.__semstrs__ = (func_semstr, param_semstr)  # type: ignore
    return func_semstr, param_semstr


def tool_from_function(func: Callable, scope: str) -> newTool:
    """Create a new Tool from a function."""
    desc, param_desc = semstr_of_func(func, scope)
    return newTool(func, desc, param_desc)


class JacMachine:
    """Jac's with_llm feature."""

    @staticmethod
    @hookimpl
    def with_llm(
        file_loc: str,
        model: BaseLLM,
        model_params: dict[str, Any],
        scope: str,
        incl_info: list[tuple[str, Any]],  # noqa: ANN401
        excl_info: list[tuple[str, str]],
        inputs: list[
            tuple[str, str, str, Any]
        ],  # TODO: Need to change this in the jaclang pyast_build_pass
        outputs: tuple,
        action: str,
        _globals: dict,
        _locals: Mapping,
    ) -> Any:  # noqa: ANN401
        """Jac's with_llm feature."""
        # FIXME: This is incremental change only did for the ollama models.
        # Everything else will remain the older way.
        if getattr(model, "model_name", None) in ("llama3.2:1b", "llama3.2:3b"):
            # ['with_llm', '_multicall', '_hookexec', '__call__', 'proxy', 'caller', ... ]
            #  0            1            2             3           4        5
            caller_frame = inspect.stack()[5]
            function_name = caller_frame.function
            frame = caller_frame.frame
            function: Callable = frame.f_locals.get(function_name) or frame.f_globals[function_name]  # type: ignore
            output_type = get_type_hints(function).get("return")

            tools = [
                tool_from_function(func, scope)
                for func in model_params.pop("tools", [])
            ]

            semstr, _ = semstr_of_func(function, scope)
            messages = [
                Message(
                    role=MessageRole.SYSTEM,
                    content=SYSTEM_PERSONA + (INSTRUCTION_TOOL if tools else ""),
                ),
                Message(
                    role=MessageRole.USER,
                    content=(
                        semstr
                        + "\n\n"
                        + "\n".join(
                            [f"{name} = {value}" for _, _, name, value in inputs]
                        )
                    ),
                ),
            ]

            req = CompletionRequest(
                messages=messages,
                tools=tools,
                resp_type=output_type,
                params={},
            )

            while True:
                resp = model.completion(req)
                if resp.tool_calls:
                    for tool_call in resp.tool_calls:
                        if tool_call.is_finish_tool():
                            return tool_call.get_output()
                        else:
                            req.add_message(tool_call())
                else:
                    break

            return resp.output

        program_head = Jac.program.mod
        _scope = SemScope.get_scope_from_str(scope) or SemScope(
            program_head.main.name, "Module", None
        )
        mod_registry = SemRegistry(program_head=program_head, by_scope=_scope)

        if not program_head:
            raise ValueError("Jac program head not found")

        assert _scope is not None, f"Invalid scope: {scope}"

        method = model_params.pop("method") if "method" in model_params else "Normal"  # type: ignore
        is_custom = (
            model_params.pop("is_custom") if "is_custom" in model_params else False
        )
        raw_output = (
            model_params.pop("raw_output") if "raw_output" in model_params else False
        )
        available_methods = model.MTLLM_METHOD_PROMPTS.keys()
        assert (
            method in available_methods
        ), f"Invalid method: {method}. Select from {available_methods}"

        context = (
            "\n".join(model_params.pop("context")) if "context" in model_params else ""
        )

        type_collector: list = []
        incl_info = [x for x in incl_info if not isinstance(x[1], type)]
        information = [Information(mod_registry, x[0], x[1]) for x in incl_info]

        inputs_information = []
        for input_item in inputs:
            _input = InputInformation(input_item[0], input_item[2], input_item[3])
            type_collector.extend(_input.get_types())
            inputs_information.append(_input)

        output = outputs[0] if isinstance(outputs, list) else outputs
        output_hint = OutputHint(output[0], output[1])
        type_collector.extend(output_hint.get_types())
        type_explanations = get_all_type_explanations(type_collector, mod_registry)

        tools = model_params.pop("tools") if "tools" in model_params else None  # type: ignore
        if method == "ReAct":
            assert tools, "Tools must be provided for the ReAct method."
            _tools = [
                tool if isinstance(tool, Tool) else callable_to_tool(tool, mod_registry)
                for tool in tools
            ]
        else:
            _tools = []

        meaning_out = aott_raise(
            model,
            information,  # TODO: Collect and pass information here.
            inputs_information,
            output_hint,
            type_explanations,
            action,
            context,
            method,
            is_custom,
            _tools,
            model_params,
            _globals,
            _locals,
        )
        if raw_output:
            return meaning_out
        _eval_output = output_hint.type != "str"
        return model.resolve_output(meaning_out, _eval_output, _globals, _locals)

    # -------------------------------------------------------------------------
    # Python code generation
    # -------------------------------------------------------------------------

    @staticmethod
    def _ability_positional_param(ability: uni.Ability, i: int) -> uni.ParamVar | None:
        """Return the i-th positional parameter of the ability."""
        if isinstance(ability.signature, uni.FuncSignature):
            min_pos_argc, max_pos_argc = ability.get_pos_argc_range()
            if i < min_pos_argc:
                return ability.signature.params[i]
            elif max_pos_argc == -1:
                return ability.signature.params[min_pos_argc]
        return None

    @staticmethod
    def _ability_positional_param_type_tag(
        ability: uni.Ability, i: int
    ) -> uni.SubTag[uni.Expr] | None:
        """Return the type tag of the i-th positional parameter of the ability."""
        if pos_param := JacMachine._ability_positional_param(ability, i):
            return pos_param.type_tag
        return None

    @staticmethod
    def _ability_param_from_name(
        ability: uni.Ability, name: str
    ) -> uni.ParamVar | None:
        """Return the parameter of the ability with the given name."""
        if isinstance(ability.signature, uni.FuncSignature):
            for param in ability.signature.params:
                if param.name.value == name:
                    return param
        return None

    @staticmethod
    @hookimpl
    def gen_llm_call_override(
        _pass: PyastGenPass, node: uni.FuncCall
    ) -> list[ast3.AST]:
        """Generate python ast nodes for llm function body override syntax.

        example:
            foo() by llm();
        """
        if node.body_genai_call:
            model = node.body_genai_call.target.gen.py_ast[0]

            if not (isinstance(node.target, uni.AstSymbolNode) and node.target.sym):
                raise _pass.ice(
                    "Semantic Error: Couldn't infer by call body override at compile time."
                )
            ability = node.target.sym.fetch_sym_tab
            if not isinstance(ability, uni.Ability):
                raise _pass.ice("Semantic Error: Expected an ability call.")
            extracted_type = (
                "".join(extract_type(ability.signature.return_type))
                if isinstance(ability.signature, uni.FuncSignature)
                and ability.signature.return_type
                else None
            )
            scope = _pass.sync(ast3.Constant(value=str(get_sem_scope(ability))))
            model_params, include_info, exclude_info = extract_params(
                node.body_genai_call
            )

            args, kwargs = _pass.gen_call_args(node)

            if not isinstance(ability.signature, uni.FuncSignature):
                raise _pass.ice(
                    "Semantic Error: Expected an ability with a function signature."
                )

            inputs: list[ast3.Tuple] = []
            for i, arg in enumerate(args):
                param = JacMachine._ability_positional_param(ability, i)
                type_tag: uni.SubTag[uni.Expr] | None = (
                    JacMachine._ability_positional_param_type_tag(ability, i)
                )
                inputs.append(
                    _pass.sync(
                        ast3.Tuple(
                            elts=[
                                (_pass.sync(ast3.Constant(value=None))),
                                (  # Type of the parameter.
                                    cast(ast3.expr, type_tag.tag.gen.py_ast[0])
                                    if type_tag
                                    else _pass.sync(ast3.Constant(value="object"))
                                ),
                                (  # Name of the parameter.
                                    _pass.sync(ast3.Constant(value=param.name.value))
                                    if param
                                    else _pass.sync(ast3.Constant(value="arg"))
                                ),
                                arg,  # Value of the parameter.
                            ],
                            ctx=ast3.Load(),
                        )
                    )
                )

            for kwarg in kwargs:
                param = JacMachine._ability_param_from_name(ability, kwarg.arg or "")
                type_tag = param.type_tag if param else None
                inputs.append(
                    _pass.sync(
                        ast3.Tuple(
                            elts=[
                                (_pass.sync(ast3.Constant(value=None))),
                                (  # Type of the parameter.
                                    cast(ast3.expr, type_tag.tag.gen.py_ast[0])
                                    if type_tag
                                    else _pass.sync(ast3.Constant(value="object"))
                                ),
                                _pass.sync(
                                    ast3.Constant(value=kwarg.arg or "")
                                ),  # Name of the parameter.
                                kwarg.value,  # Value of the parameter.
                            ],
                            ctx=ast3.Load(),
                        )
                    )
                )

            outputs = [
                (_pass.sync(ast3.Constant(value=("")))),
                (_pass.sync(ast3.Constant(value=(extracted_type)))),
            ]
            docstr = (
                ((ability.doc and ability.doc.lit_value) or "")
                if isinstance(ability, uni.AstDocNode)
                else ""
            )
            action = _pass.sync(
                ast3.Constant(value=f"{docstr.strip()} ({ability.name_ref.sym_name})\n")
            )
            return [
                _pass.sync(
                    _pass.by_llm_call(
                        model,
                        model_params,
                        scope,
                        inputs,
                        outputs,
                        action,
                        include_info,
                        exclude_info,
                    )
                )
            ]
        else:
            return []

    @staticmethod
    @hookimpl
    def gen_llm_body(_pass: PyastGenPass, node: uni.Ability) -> list[ast3.AST]:
        """Generate the by LLM body."""
        if isinstance(node.body, uni.FuncCall):
            model = node.body.target.gen.py_ast[0]
            extracted_type = (
                "".join(extract_type(node.signature.return_type))
                if isinstance(node.signature, uni.FuncSignature)
                and node.signature.return_type
                else None
            )
            scope = _pass.sync(ast3.Constant(value=str(get_sem_scope(node))))
            model_params, include_info, exclude_info = extract_params(node.body)
            inputs = (
                [
                    _pass.sync(
                        ast3.Tuple(
                            elts=[
                                (_pass.sync(ast3.Constant(value=None))),
                                (
                                    cast(ast3.expr, param.type_tag.tag.gen.py_ast[0])
                                    if param.type_tag
                                    else _pass.sync(ast3.Constant(value="object"))
                                ),
                                _pass.sync(ast3.Constant(value=param.name.value)),
                                _pass.sync(
                                    ast3.Name(
                                        id=param.name.value,
                                        ctx=ast3.Load(),
                                    )
                                ),
                            ],
                            ctx=ast3.Load(),
                        )
                    )
                    for param in node.signature.params
                ]
                if isinstance(node.signature, uni.FuncSignature)
                and node.signature.params
                else []
            )
            outputs = (
                [
                    (_pass.sync(ast3.Constant(value=("")))),
                    (_pass.sync(ast3.Constant(value=(extracted_type)))),
                ]
                if isinstance(node.signature, uni.FuncSignature)
                else []
            )
            # Use the ability name as action, and if docstring exists, append it
            semstr = node.semstr or ((node.doc and node.doc.lit_value) or "").strip()
            action = _pass.sync(
                ast3.Constant(value=f"{semstr} ({node.name_ref.sym_name})\n")
            )
            return [
                _pass.sync(
                    ast3.Return(
                        value=_pass.sync(
                            _pass.by_llm_call(
                                model,
                                model_params,
                                scope,
                                inputs,
                                outputs,
                                action,
                                include_info,
                                exclude_info,
                            )
                        )
                    )
                )
            ]
        else:
            return []

    @staticmethod
    @hookimpl
    def by_llm_call(
        _pass: PyastGenPass,
        model: ast3.AST,
        model_params: dict[str, uni.Expr],
        scope: ast3.AST,
        inputs: Sequence[Optional[ast3.AST]],
        outputs: Sequence[Optional[ast3.AST]] | ast3.Call,
        action: Optional[ast3.AST],
        include_info: list[tuple[str, ast3.AST]],
        exclude_info: list[tuple[str, ast3.AST]],
    ) -> ast3.Call:
        """Return the LLM Call, e.g. JacMachine.with_llm()."""
        return _pass.sync(
            ast3.Call(
                func=_pass.sync(
                    ast3.Attribute(
                        value=_pass.sync(
                            ast3.Name(
                                id="_",
                                ctx=ast3.Load(),
                            )
                        ),
                        attr="with_llm",
                        ctx=ast3.Load(),
                    )
                ),
                args=[],
                keywords=[
                    _pass.sync(
                        ast3.keyword(
                            arg="file_loc",
                            value=_pass.sync(ast3.Name(id="__file__", ctx=ast3.Load())),
                        )
                    ),
                    _pass.sync(
                        ast3.keyword(
                            arg="model",
                            value=cast(ast3.expr, model),
                        )
                    ),
                    _pass.sync(
                        ast3.keyword(
                            arg="model_params",
                            value=_pass.sync(
                                ast3.Dict(
                                    keys=[
                                        _pass.sync(ast3.Constant(value=key))
                                        for key in model_params.keys()
                                    ],
                                    values=[
                                        cast(ast3.expr, value.gen.py_ast[0])
                                        for value in model_params.values()
                                    ],
                                )
                            ),
                        )
                    ),
                    _pass.sync(
                        ast3.keyword(
                            arg="scope",
                            value=cast(ast3.expr, scope),
                        )
                    ),
                    _pass.sync(
                        ast3.keyword(
                            arg="incl_info",
                            value=_pass.sync(
                                ast3.List(
                                    elts=[
                                        _pass.sync(
                                            ast3.Tuple(
                                                elts=[
                                                    _pass.sync(
                                                        ast3.Constant(value=key)
                                                    ),
                                                    cast(ast3.expr, value),
                                                ],
                                                ctx=ast3.Load(),
                                            )
                                        )
                                        for key, value in include_info
                                    ],
                                    ctx=ast3.Load(),
                                )
                            ),
                        )
                    ),
                    _pass.sync(
                        ast3.keyword(
                            arg="excl_info",
                            value=_pass.sync(
                                ast3.List(
                                    elts=[
                                        _pass.sync(
                                            ast3.Tuple(
                                                elts=[
                                                    _pass.sync(
                                                        ast3.Constant(value=key)
                                                    ),
                                                    cast(ast3.expr, value),
                                                ],
                                                ctx=ast3.Load(),
                                            )
                                        )
                                        for key, value in exclude_info
                                    ],
                                    ctx=ast3.Load(),
                                )
                            ),
                        ),
                    ),
                    _pass.sync(
                        ast3.keyword(
                            arg="inputs",
                            value=_pass.sync(
                                ast3.List(
                                    elts=cast(list[ast3.expr], inputs),
                                    ctx=ast3.Load(),
                                )
                            ),
                        )
                    ),
                    _pass.sync(
                        ast3.keyword(
                            arg="outputs",
                            value=(
                                _pass.sync(
                                    ast3.Tuple(
                                        elts=cast(list[ast3.expr], outputs),
                                        ctx=ast3.Load(),
                                    )
                                )
                                if not isinstance(outputs, ast3.Call)
                                else outputs
                            ),
                        )
                    ),
                    _pass.sync(
                        ast3.keyword(
                            arg="action",
                            value=cast(ast3.expr, action),
                        )
                    ),
                    _pass.sync(
                        ast3.keyword(
                            arg="_globals",
                            value=_pass.sync(
                                ast3.Call(
                                    func=_pass.sync(
                                        ast3.Name(
                                            id="globals",
                                            ctx=ast3.Load(),
                                        )
                                    ),
                                    args=[],
                                    keywords=[],
                                )
                            ),
                        )
                    ),
                    _pass.sync(
                        ast3.keyword(
                            arg="_locals",
                            value=_pass.sync(
                                ast3.Call(
                                    func=_pass.sync(
                                        ast3.Name(
                                            id="locals",
                                            ctx=ast3.Load(),
                                        )
                                    ),
                                    args=[],
                                    keywords=[],
                                )
                            ),
                        )
                    ),
                ],
            )
        )

    @staticmethod
    @hookimpl
    def get_by_llm_call_args(_pass: PyastGenPass, node: uni.FuncCall) -> dict:
        """Get the by LLM call args."""
        if node.genai_call is None:
            raise _pass.ice("No genai_call")

        model = node.genai_call.target.gen.py_ast[0]
        model_params, include_info, exclude_info = extract_params(node.genai_call)

        action = _pass.sync(
            ast3.Constant(
                value="Create an object of the specified type, using the specifically "
                " provided input value(s) and look up any missing attributes from reliable"
                " online sources to fill them in accurately."
            )
        )
        _output_ = "".join(extract_type(node.target))
        include_info.append(
            (
                _output_.split(".")[0],
                _pass.sync(ast3.Name(id=_output_.split(".")[0], ctx=ast3.Load())),
            )
        )
        scope = _pass.sync(
            ast3.Call(
                func=_pass.sync(
                    ast3.Attribute(
                        value=_pass.sync(
                            ast3.Name(
                                id="_",
                                ctx=ast3.Load(),
                            )
                        ),
                        attr="obj_scope",
                        ctx=ast3.Load(),
                    )
                ),
                args=[
                    _pass.sync(
                        ast3.Name(
                            id="__file__",
                            ctx=ast3.Load(),
                        )
                    ),
                    _pass.sync(ast3.Constant(value=_output_)),
                ],
                keywords=[],
            )
        )
        outputs = _pass.sync(
            ast3.Call(
                func=_pass.sync(
                    ast3.Attribute(
                        value=_pass.sync(
                            ast3.Name(
                                id="_",
                                ctx=ast3.Load(),
                            )
                        ),
                        attr="get_sem_type",
                        ctx=ast3.Load(),
                    )
                ),
                args=[
                    _pass.sync(
                        ast3.Name(
                            id="__file__",
                            ctx=ast3.Load(),
                        )
                    ),
                    _pass.sync(ast3.Constant(value=str(_output_))),
                ],
                keywords=[],
            )
        )
        if node.params:
            inputs = [
                _pass.sync(
                    ast3.Tuple(
                        elts=[
                            _pass.sync(
                                ast3.Call(
                                    func=_pass.sync(
                                        ast3.Attribute(
                                            value=_pass.sync(
                                                ast3.Name(
                                                    id="_",
                                                    ctx=ast3.Load(),
                                                )
                                            ),
                                            attr="get_semstr_type",
                                            ctx=ast3.Load(),
                                        )
                                    ),
                                    args=[
                                        _pass.sync(
                                            ast3.Name(id="__file__", ctx=ast3.Load())
                                        ),
                                        scope,
                                        _pass.sync(
                                            ast3.Constant(
                                                value=(
                                                    kw_pair.key.value
                                                    if isinstance(kw_pair.key, uni.Name)
                                                    else None
                                                )
                                            )
                                        ),
                                        _pass.sync(ast3.Constant(value=True)),
                                    ],
                                    keywords=[],
                                )
                            ),
                            _pass.sync(
                                ast3.Call(
                                    func=_pass.sync(
                                        ast3.Attribute(
                                            value=_pass.sync(
                                                ast3.Name(
                                                    id="_",
                                                    ctx=ast3.Load(),
                                                )
                                            ),
                                            attr="get_semstr_type",
                                            ctx=ast3.Load(),
                                        )
                                    ),
                                    args=[
                                        _pass.sync(
                                            ast3.Name(id="__file__", ctx=ast3.Load())
                                        ),
                                        scope,
                                        _pass.sync(
                                            ast3.Constant(
                                                value=(
                                                    kw_pair.key.value
                                                    if isinstance(kw_pair.key, uni.Name)
                                                    else None
                                                )
                                            )
                                        ),
                                        _pass.sync(ast3.Constant(value=False)),
                                    ],
                                    keywords=[],
                                )
                            ),
                            _pass.sync(
                                ast3.Constant(
                                    value=(
                                        kw_pair.key.value
                                        if isinstance(kw_pair.key, uni.Name)
                                        else None
                                    )
                                )
                            ),
                            kw_pair.value.gen.py_ast[0],  # type: ignore
                        ],
                        ctx=ast3.Load(),
                    )
                )
                for kw_pair in node.params
                if isinstance(kw_pair, uni.KWPair)
            ]
        else:
            inputs = []

        return {
            "model": model,
            "model_params": model_params,
            "scope": scope,
            "inputs": inputs,
            "outputs": outputs,
            "action": action,
            "include_info": include_info,
            "exclude_info": exclude_info,
        }

    @staticmethod
    @hookimpl
    def get_semstr_type(
        file_loc: str, scope: str, attr: str, return_semstr: bool
    ) -> Optional[str]:
        """Jac's get_semstr_type feature."""
        program_head = Jac.program.mod
        _scope = SemScope.get_scope_from_str(scope) or SemScope(
            program_head.main.name, "Module", None
        )
        mod_registry = SemRegistry(program_head=program_head, by_scope=_scope)
        _, attr_seminfo = mod_registry.lookup(_scope, attr)
        if attr_seminfo and isinstance(attr_seminfo, SemInfo):
            return attr_seminfo.semstr if return_semstr else attr_seminfo.type
        return None

    @staticmethod
    @hookimpl
    def obj_scope(file_loc: str, attr: str) -> str:
        """Jac's gather_scope feature."""
        program_head = Jac.program.mod
        root_scope = SemScope(program_head.main.name, "Module", None)
        mod_registry = SemRegistry(program_head=program_head, by_scope=root_scope)

        attr_scope = None
        for x in attr.split("."):
            attr_scope, attr_sem_info = mod_registry.lookup(attr_scope, x)
            if isinstance(attr_sem_info, SemInfo) and attr_sem_info.type not in [
                "class",
                "object",
                "node",
                "edge",
            ]:
                attr_scope, attr_sem_info = mod_registry.lookup(
                    None, attr_sem_info.type
                )
                if isinstance(attr_sem_info, SemInfo) and isinstance(
                    attr_sem_info.type, str
                ):
                    attr_scope = SemScope(
                        attr_sem_info.name, attr_sem_info.type, attr_scope
                    )
            else:
                if isinstance(attr_sem_info, SemInfo) and isinstance(
                    attr_sem_info.type, str
                ):
                    attr_scope = SemScope(
                        attr_sem_info.name, attr_sem_info.type, attr_scope
                    )
        return str(attr_scope)

    @staticmethod
    @hookimpl
    def get_sem_type(file_loc: str, attr: str) -> tuple[str | None, str | None]:
        """Jac's get_semstr_type implementation."""
        program_head = Jac.program.mod
        # Create a root scope for the module
        root_scope = SemScope(program_head.main.name, "Module", None)
        mod_registry = SemRegistry(program_head=program_head, by_scope=root_scope)

        attr_scope, attr_sem_info = None, None
        for x in attr.split("."):
            attr_scope, attr_sem_info = mod_registry.lookup(attr_scope, x)
            if isinstance(attr_sem_info, SemInfo) and attr_sem_info.type not in [
                "class",
                "object",
                "node",
                "edge",
            ]:
                attr_scope, attr_sem_info = mod_registry.lookup(
                    None, attr_sem_info.type
                )
                if isinstance(attr_sem_info, SemInfo) and isinstance(
                    attr_sem_info.type, str
                ):
                    attr_scope = SemScope(
                        attr_sem_info.name, attr_sem_info.type, attr_scope
                    )
            else:
                if isinstance(attr_sem_info, SemInfo) and isinstance(
                    attr_sem_info.type, str
                ):
                    attr_scope = SemScope(
                        attr_sem_info.name, attr_sem_info.type, attr_scope
                    )
        if isinstance(attr_sem_info, SemInfo) and isinstance(attr_scope, SemScope):
            return attr_sem_info.semstr, attr_scope.as_type_str
        return "", ""

    # -----------------------------------------------------------------------------
    # NOTE: Below this line is the new implementation of the MTLLM plugin. Where
    #       we're not using *ANY* of the old plugin features and eventually we can
    #       completely remove the old implementation.
    # -----------------------------------------------------------------------------

    @staticmethod
    @hookimpl
    def call_llm(
        model: JacLLM, caller: Callable, args: dict[str | int, object]
    ) -> object:
        """Call JacLLM and return the result.

        ```jac
        def get_weather(city: str, unit: str = "") -> str
            by llm(
                temperature=0.7,
                top_k=50,
                top_p=0.95,
                max_tokens=100,
            );
        ```
        For body llm override the args dictionary will be like this as the
        parameter names are not resolvable at compiletime (unless keywords):
            { 0 : "moratuwa", "unit" : "celsius" }
        """
        return model.invoke(caller, args)
