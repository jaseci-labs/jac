import from jaclang.compiler.ir.types.nodes { ClassType, FunctionType, TypeBase }
import from jaclang.compiler.ir.schema {
    Symbol,
    NameAtom,
    Archetype,
    AstSymbolNode,
    Ability,
    Module,
    UniScopeNode
}

def specialize_function(function: FunctionType, class_type: ClassType) -> FunctionType {
    import from jaclang.compiler.analysis.types.type_utils {
        apply_solved_type_vars,
        build_type_var_solution
    }

    solution = build_type_var_solution(class_type);

    clone = function.clone();

    for param in clone.parameters {
        if param.param_type {
            param.param_type = apply_solved_type_vars(
                param.param_type, solution, class_type
            );
        }
    }

    if clone.return_type {
        clone.return_type = apply_solved_type_vars(
            clone.return_type, solution, class_type
        );
    }

    return clone;
}


def specialize_function_variables(
    function: FunctionType, solution: dict[(str, TypeBase)]
) -> FunctionType {
    import from jaclang.compiler.analysis.types.type_utils { apply_solved_type_vars }

    clone = function.clone();

    for param in clone.parameters {
        if param.param_type {
            param.param_type = apply_solved_type_vars(param.param_type, solution);
        }
    }

    if clone.return_type {
        clone.return_type = apply_solved_type_vars(clone.return_type, solution);
    }

    return clone;
}
