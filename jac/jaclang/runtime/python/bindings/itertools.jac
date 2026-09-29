"""The itertools module: its types, built from itertoolsmodule.c's docs and
method tables, over the construction modules/itertools.jac keeps."""

import from jaclang.runtime.python.cpython_api { PyObject, Py_GenericAlias }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodCallbacks,
    MethodDefinition,
    add_state_owned
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags
}
import from jaclang.runtime.python.bindings.clinic.itertools {
    _tee_doc,
    accumulate_doc,
    batched_doc,
    batched_new_new,
    chain_class_getitem_doc,
    chain_doc,
    chain_methods,
    combinations_doc,
    combinations_with_replacement_doc,
    compress_doc,
    count_doc,
    cycle_doc,
    dropwhile_doc,
    filterfalse_doc,
    groupby_doc,
    islice_doc,
    itertools__grouper_new,
    itertools__tee_new,
    itertools_accumulate_new,
    itertools_combinations_new,
    itertools_combinations_with_replacement_new,
    itertools_compress_new,
    itertools_count_new,
    itertools_cycle_new,
    itertools_dropwhile_new,
    itertools_filterfalse_new,
    itertools_groupby_new,
    itertools_permutations_new,
    itertools_starmap_new,
    itertools_takewhile_new,
    itertools_teedataobject_new,
    length_hint_doc,
    module_doc,
    module_methods,
    pairwise_doc,
    pairwise_new_new,
    permutations_doc,
    product_doc,
    repeat_doc,
    sizeof_doc,
    starmap_doc,
    takewhile_doc,
    teecopy_doc,
    teedataobject_doc,
    zip_longest_doc
}
import from jaclang.runtime.python.modules.itertools {
    Kind,
    combination_size,
    data_dealloc,
    iterator_clear,
    iterator_dealloc,
    iterator_new,
    iterator_next,
    pipeline_iterator_next,
    iterator_repr,
    iterator_self,
    iterator_traverse,
    itertools_module_token,
    kind_tokens,
    names,
    repeat_length,
    tee_copy
}

# Each type's tp_doc.
glob:priv docs = [
         accumulate_doc,
         batched_doc,
         chain_doc,
         compress_doc,
         count_doc,
         cycle_doc,
         dropwhile_doc,
         filterfalse_doc,
         islice_doc,
         pairwise_doc,
         repeat_doc,
         starmap_doc,
         takewhile_doc,
         zip_longest_doc,
         product_doc,
         combinations_doc,
         combinations_with_replacement_doc,
         permutations_doc,
         groupby_doc,
         "",
         _tee_doc,
         teedataobject_doc
     ];


def:priv make_types -> list[TypeDefinition] {
    result: list[TypeDefinition] = [];
    for kind in range(len(names)) {
        methods: list[MethodDefinition] = [];
        flags = u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value);
        hooks = TypeHooks(
            create=iterator_new,
            dealloc=iterator_dealloc,
            traverse=iterator_traverse,
            clear=iterator_clear,
            iter=iterator_self,
            next=iterator_next
        );
        # clinic's __new__ glue; C's hand-written tp_new (chain, islice,
        # product, repeat, zip_longest) otherwise.
        if kind == Kind.ACCUMULATE.value {
            hooks.create = itertools_accumulate_new;
        } elif kind == Kind.BATCHED.value {
            hooks.create = batched_new_new;
        } elif kind == Kind.COMPRESS.value {
            hooks.create = itertools_compress_new;
        } elif kind == Kind.COUNT.value {
            hooks.create = itertools_count_new;
        } elif kind == Kind.CYCLE.value {
            hooks.create = itertools_cycle_new;
        } elif kind == Kind.DROPWHILE.value {
            hooks.create = itertools_dropwhile_new;
        } elif kind == Kind.FILTERFALSE.value {
            hooks.create = itertools_filterfalse_new;
        } elif kind == Kind.PAIRWISE.value {
            hooks.create = pairwise_new_new;
        } elif kind == Kind.STARMAP.value {
            hooks.create = itertools_starmap_new;
        } elif kind == Kind.TAKEWHILE.value {
            hooks.create = itertools_takewhile_new;
        } elif kind == Kind.COMBINATIONS.value {
            hooks.create = itertools_combinations_new;
        } elif kind == Kind.CWR.value {
            hooks.create = itertools_combinations_with_replacement_new;
        } elif kind == Kind.PERMUTATIONS.value {
            hooks.create = itertools_permutations_new;
        } elif kind == Kind.GROUPBY.value {
            hooks.create = itertools_groupby_new;
        } elif kind == Kind.GROUPER.value {
            hooks.create = itertools__grouper_new;
        } elif kind == Kind.TEE.value {
            hooks.create = itertools__tee_new;
        } elif kind == Kind.TEE_DATA.value {
            hooks.create = itertools_teedataobject_new;
        }
        if kind <= Kind.ZIP_LONGEST.value {
            hooks.next = pipeline_iterator_next;
        }
        if kind <= Kind.GROUPBY.value {
            flags = flags | u64(TypeFlags.BASETYPE.value);
        }
        if kind == Kind.COUNT.value or kind == Kind.REPEAT.value {
            hooks.repr = iterator_repr;
        }
        if kind >= Kind.PRODUCT.value and kind <= Kind.PERMUTATIONS.value {
            methods.append(
                MethodDefinition(
                    "__sizeof__",
                    MethodCallbacks(positional=combination_size),
                    sizeof_doc,
                    flags=4
                )
            );
        }
        if kind == Kind.REPEAT.value {
            methods.append(
                MethodDefinition(
                    "__length_hint__",
                    MethodCallbacks(positional=repeat_length),
                    length_hint_doc,
                    flags=4
                )
            );
        }
        if kind == Kind.CHAIN.value {
            methods = chain_methods
                + [
                    MethodDefinition(
                        "__class_getitem__",
                        MethodCallbacks(positional=Py_GenericAlias),
                        chain_class_getitem_doc,
                        flags=24
                    )
                ];
        }
        if kind == Kind.TEE.value {
            methods.append(
                MethodDefinition(
                    "__copy__",
                    MethodCallbacks(positional=tee_copy),
                    teecopy_doc,
                    flags=4
                )
            );
        }
        if kind == Kind.TEE_DATA.value {
            hooks = TypeHooks(
                create=itertools_teedataobject_new,
                dealloc=data_dealloc,
                traverse=iterator_traverse,
                clear=iterator_clear
            );
        }
        # Every type but _tee sets Py_tp_getattro to PyObject_GenericGetAttr;
        # _tee keeps a weakref list.
        result.append(
            TypeDefinition(
                "itertools." + names[kind],
                docs[kind],
                methods,
                flags,
                hooks,
                weaklist=kind == Kind.TEE.value,
                generic_getattr=kind != Kind.TEE.value
            )
        );
    }
    return result;
}

glob:priv types = make_types();
def:priv execute(module: ptr[PyObject]) -> i32 {
    for index in range(len(types)) {
        kind_tokens[index].handle = types[index].handle;
    }
    itertools_module_token.handle = definition.handle;
    for index in range(len(types)) {
        if not add_state_owned(
            module, index, names[index], types[index].create(module)
        ) {
            return i32(-1);
        }
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "itertools",
         module_doc,
         module_methods,
         hooks=ModuleHooks(execute=execute),
         state_count=22
     );

def:pub PyInit_itertools -> ptr[PyObject] {
    return definition.initialize();
}
