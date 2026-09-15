"""Typed optional lookup results for CPython's output-parameter APIs.

A lookup owns either one Python reference, a missing-result marker, or the null
error result. The marker has no Python identity and cannot be borrowed as an
object. This representation uses no heap allocation or Jac reference counting.
"""

import from jaclang.runtime.python.references { PyObjectRef, JacPyThreadState }

@foreign_resource(abi="pointer", empty=0, drop=jacpy_lookup_close,
                  aliasing="shared", reentrant_drop=True)
obj PyLookupRef;

import from c {
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_lookup_close(result: own PyLookupRef);
    # -1: error; 0: absent; 1: owned value. This status does not inspect or
    # disturb a preexisting Python exception.
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_lookup_state(result: &PyLookupRef) -> i32;
    # Consumes the result. Missing and error results produce a null owner.
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_lookup_take(result: own PyLookupRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_mapping_lookup(mapping: &PyObjectRef, key: &PyObjectRef) -> own PyLookupRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_dict_lookup(dictionary: &PyObjectRef, key: &PyObjectRef) -> own PyLookupRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_attribute_lookup(value: &PyObjectRef, name: &PyObjectRef) -> own PyLookupRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_module_origin_lookup(specification: &PyObjectRef) -> own PyLookupRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_sys_lookup(name: str) -> own PyLookupRef;
}
