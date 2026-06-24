import from ctypes {
    POINTER,
    byref,
    cast,
    c_char_p,
    c_double,
    c_int,
    c_size_t,
    c_uint,
    c_uint64,
    c_bool,
    c_void_p
}
import enum;
import from jaclang.compiler.passes.native.llvm.binding { ffi }
import from jaclang.compiler.passes.native.llvm.binding.common { _decode_string, _encode_string }
import from jaclang.compiler.passes.native.llvm.binding.typeref { TypeRef }
class Linkage(`enum.IntEnum) {
    with entry {
        external = 0;
        available_externally = 1;
        linkonce_any = 2;
        linkonce_odr = 3;
        linkonce_odr_autohide = 4;
        weak_any = 5;
        weak_odr = 6;
        appending = 7;
        internal = 8;
        private = 9;
        dllimport = 10;
        dllexport = 11;
        external_weak = 12;
        ghost = 13;
        common = 14;
        linker_private = 15;
        linker_private_weak = 16;
    }
}
class Visibility(`enum.IntEnum) {
    with entry {
        `default = 0;
        hidden = 1;
        protected = 2;
    }
}
class StorageClass(`enum.IntEnum) {
    with entry {
        `default = 0;
        dllimport = 1;
        dllexport = 2;
    }
}
class ValueKind(`enum.IntEnum) {
    with entry {
        argument = 0;
        basic_block = 1;
        memory_use = 2;
        memory_def = 3;
        memory_phi = 4;
        function = 5;
        global_alias = 6;
        global_ifunc = 7;
        global_variable = 8;
        block_address = 9;
        constant_expr = 10;
        constant_array = 11;
        constant_struct = 12;
        constant_vector = 13;
        undef_value = 14;
        constant_aggregate_zero = 15;
        constant_data_array = 16;
        constant_data_vector = 17;
        constant_int = 18;
        constant_fp = 19;
        constant_pointer_null = 20;
        constant_token_none = 21;
        metadata_as_value = 22;
        inline_asm = 23;
        instruction = 24;
        poison_value = 25;
    }
}
"""A weak reference to a LLVM value.
    """
class ValueRef(ffi.ObjectRef) {
    def init(self: ValueRef, ptr: Any, kind: Any, parents: Any) -> object {
        self._kind = kind;
        self._parents = parents;
        ffi.ObjectRef.init(self, ptr);
    }
    def __str__(self: ValueRef) -> object {
        with ffi.OutputString() as outstr {
            ffi.lib.LLVMPY_PrintValueToString(self, outstr);
            return str(outstr);
        }
    }
    """
        The module this function or global variable value was obtained from.
        """
    @property
    def module(self: ValueRef) -> object {
        return self._parents.get('module');
    }

    """
        The function this argument or basic block value was obtained from.
        """
    @property
    def function(self: ValueRef) -> object {
        return self._parents.get('function');
    }

    """
        The block this instruction value was obtained from.
        """
    @property
    def block(self: ValueRef) -> object {
        return self._parents.get('block');
    }

    """
        The instruction this operand value was obtained from.
        """
    @property
    def instruction(self: ValueRef) -> object {
        return self._parents.get('instruction');
    }

    @property
    def is_global(self: ValueRef) -> object {
        return (self._kind == 'global');
    }
    @property
    def is_function(self: ValueRef) -> object {
        return (self._kind == 'function');
    }
    @property
    def is_block(self: ValueRef) -> object {
        return (self._kind == 'block');
    }
    @property
    def is_argument(self: ValueRef) -> object {
        return (self._kind == 'argument');
    }
    @property
    def is_instruction(self: ValueRef) -> object {
        return (self._kind == 'instruction');
    }
    @property
    def is_operand(self: ValueRef) -> object {
        return (self._kind == 'operand');
    }
    @property
    def is_constant(self: ValueRef) -> object {
        return bool(ffi.lib.LLVMPY_IsConstant(self));
    }
    @property
    def value_kind(self: ValueRef) -> object {
        return ValueKind(ffi.lib.LLVMPY_GetValueKind(self));
    }
    @property
    def name(self: ValueRef) -> object {
        return _decode_string(ffi.lib.LLVMPY_GetValueName(self));
    }
    @name.setter
    def name(self: ValueRef, val: Any) -> object {
        ffi.lib.LLVMPY_SetValueName(self, _encode_string(val));
    }
    @property
    def linkage(self: ValueRef) -> object {
        return Linkage(ffi.lib.LLVMPY_GetLinkage(self));
    }
    @linkage.setter
    def linkage(self: ValueRef, value: Any) -> object {
        if not isinstance(value, Linkage) {
            value = Linkage[value];
        }
        ffi.lib.LLVMPY_SetLinkage(self, value);
    }
    @property
    def visibility(self: ValueRef) -> object {
        return Visibility(ffi.lib.LLVMPY_GetVisibility(self));
    }
    @visibility.setter
    def visibility(self: ValueRef, value: Any) -> object {
        if not isinstance(value, Visibility) {
            value = Visibility[value];
        }
        ffi.lib.LLVMPY_SetVisibility(self, value);
    }
    @property
    def storage_class(self: ValueRef) -> object {
        return StorageClass(ffi.lib.LLVMPY_GetDLLStorageClass(self));
    }
    @storage_class.setter
    def storage_class(self: ValueRef, value: Any) -> object {
        if not isinstance(value, StorageClass) {
            value = StorageClass[value];
        }
        ffi.lib.LLVMPY_SetDLLStorageClass(self, value);
    }
    """Only works on function value

        Parameters
        -----------
        attr : str
            attribute name
        """
    def add_function_attribute(self: ValueRef, attr: Any) -> object {
        if not self.is_function {
            raise ValueError(('expected function value, got %s' % (self._kind, )));
        }
        attrname = str(attr);
        attrval = ffi.lib.LLVMPY_GetEnumAttributeKindForName(
            _encode_string(attrname), len(attrname)
        );
        if (attrval == 0) {
            raise ValueError('no such attribute {!r}'.format(attrname));
        }
        ffi.lib.LLVMPY_AddFunctionAttr(self, attrval);
    }

    """
        This value's LLVM type.
        """
    @property
    def `type(self: ValueRef) -> object {
        return TypeRef(ffi.lib.LLVMPY_TypeOf(self));
    }

    """
        Uses ``LLVMGlobalGetValueType()``.
        Needed for opaque pointers in globals.
        > For globals, use getValueType().
        See https://llvm.org/docs/OpaquePointers.html#migration-instructions
        """
    @property
    def global_value_type(self: ValueRef) -> object {
        assert (self.is_global or self.is_function);
        return TypeRef(ffi.lib.LLVMPY_GlobalGetValueType(self));
    }

    """
        Whether this value (presumably global) is defined in the current
        module.
        """
    @property
    def is_declaration(self: ValueRef) -> object {
        if not (self.is_global or self.is_function) {
            raise ValueError(
                ('expected global or function value, got %s' % (self._kind, ))
            );
        }
        return ffi.lib.LLVMPY_IsDeclaration(self);
    }

    """
        Return an iterator over this value's attributes.
        The iterator will yield a string for each attribute.
        """
    @property
    def attributes(self: ValueRef) -> object {
        itr = iter(());
        if self.is_function {
            it = ffi.lib.LLVMPY_FunctionAttributesIter(self);
            itr = _AttributeListIterator(it);
        } elif self.is_instruction {
            if (self.opcode == 'call') {
                it = ffi.lib.LLVMPY_CallInstAttributesIter(self);
                itr = _AttributeListIterator(it);
            } elif (self.opcode == 'invoke') {
                it = ffi.lib.LLVMPY_InvokeInstAttributesIter(self);
                itr = _AttributeListIterator(it);
            }
        } elif self.is_global {
            it = ffi.lib.LLVMPY_GlobalAttributesIter(self);
            itr = _AttributeSetIterator(it);
        } elif self.is_argument {
            it = ffi.lib.LLVMPY_ArgumentAttributesIter(self);
            itr = _AttributeSetIterator(it);
        }
        return itr;
    }

    """
        Return an iterator over this function's blocks.
        The iterator will yield a ValueRef for each block.
        """
    @property
    def blocks(self: ValueRef) -> object {
        if not self.is_function {
            raise ValueError(('expected function value, got %s' % (self._kind, )));
        }
        it = ffi.lib.LLVMPY_FunctionBlocksIter(self);
        parents = self._parents.copy();
        parents.update(function=self);
        return _BlocksIterator(it, parents);
    }

    """
        Return an iterator over this function's arguments.
        The iterator will yield a ValueRef for each argument.
        """
    @property
    def arguments(self: ValueRef) -> object {
        if not self.is_function {
            raise ValueError(('expected function value, got %s' % (self._kind, )));
        }
        it = ffi.lib.LLVMPY_FunctionArgumentsIter(self);
        parents = self._parents.copy();
        parents.update(function=self);
        return _ArgumentsIterator(it, parents);
    }

    """
        Return an iterator over this block's instructions.
        The iterator will yield a ValueRef for each instruction.
        """
    @property
    def instructions(self: ValueRef) -> object {
        if not self.is_block {
            raise ValueError(('expected block value, got %s' % (self._kind, )));
        }
        it = ffi.lib.LLVMPY_BlockInstructionsIter(self);
        parents = self._parents.copy();
        parents.update(block=self);
        return _InstructionsIterator(it, parents);
    }

    """
        Return an iterator over this instruction's operands.
        The iterator will yield a ValueRef for each operand.
        """
    @property
    def operands(self: ValueRef) -> object {
        if not self.is_instruction {
            raise ValueError(('expected instruction value, got %s' % (self._kind, )));
        }
        it = ffi.lib.LLVMPY_InstructionOperandsIter(self);
        parents = self._parents.copy();
        parents.update(instruction=self);
        return _OperandsIterator(it, parents);
    }

    @property
    def opcode(self: ValueRef) -> object {
        if not self.is_instruction {
            raise ValueError(('expected instruction value, got %s' % (self._kind, )));
        }
        return ffi.ret_string(ffi.lib.LLVMPY_GetOpcodeName(self));
    }
    """
        Return an iterator over this phi instruction's incoming blocks.
        The iterator will yield a ValueRef for each block.
        """
    @property
    def incoming_blocks(self: ValueRef) -> object {
        if (not self.is_instruction or (self.opcode != 'phi')) {
            raise ValueError(
                ('expected phi instruction value, got %s' % (self._kind, ))
            );
        }
        it = ffi.lib.LLVMPY_PhiIncomingBlocksIter(self);
        parents = self._parents.copy();
        parents.update(instruction=self);
        return _IncomingBlocksIterator(it, parents);
    }

    """
        Return the constant value, either as a literal (when supported)
        or as a string.

        Parameters
        -----------
        signed_int : bool
            if True and the constant is an integer, returns a signed version
        round_fp : bool
            if True and the constant is a floating point value, rounds the
            result upon accuracy loss (e.g., when querying an fp128 value).
            By default, raises an exception on accuracy loss
        """
    def get_constant_value(
        self: ValueRef, signed_int: Any = False, round_fp: Any = False
    ) -> object {
        if not self.is_constant {
            raise ValueError(('expected constant value, got %s' % (self._kind, )));
        }
        if (self.value_kind == ValueKind.constant_int) {
            little_endian = c_bool(False);
            words = ffi.lib.LLVMPY_GetConstantIntNumWords(self);
            ptr = ffi.lib.LLVMPY_GetConstantIntRawValue(self, byref(little_endian));
            asbytes = `bytes(cast(ptr, POINTER((c_uint64 * words))).contents);
            return int.from_bytes(
                asbytes, 'little' if little_endian.value else 'big', signed=signed_int
            );
        } elif (self.value_kind == ValueKind.constant_fp) {
            accuracy_loss = c_bool(False);
            value = ffi.lib.LLVMPY_GetConstantFPValue(self, byref(accuracy_loss));
            if (accuracy_loss.value and not round_fp) {
                raise ValueError(
                    f'Accuracy loss encountered in conversion of constant value {str(
                        self
                    )}'
                );
            }
            return value;
        }
        return str(self);
    }
}

class _ValueIterator(ffi.ObjectRef) {
    with entry {
        kind = None;
    }

    def init(self: _ValueIterator, ptr: Any, parents: Any) -> object {
        ffi.ObjectRef.init(self, ptr);
        self._parents = parents;
        if (self.kind is None) {
            raise NotImplementedError(
                ('%s must specify kind attribute' % (`type(self).__name__, ))
            );
        }
    }
    def __next__(self: _ValueIterator) -> object {
        vp = self._next();
        if vp {
            return ValueRef(vp, self.kind, self._parents);
        } else {
            raise StopIteration;
        }
    }

    with entry {
        next = __next__;
    }

    def __iter__(self: _ValueIterator) -> object {
        return self;
    }
}
class _AttributeIterator(ffi.ObjectRef) {
    def __next__(self: _AttributeIterator) -> object {
        vp = self._next();
        if vp {
            return vp;
        } else {
            raise StopIteration;
        }
    }

    with entry {
        next = __next__;
    }

    def __iter__(self: _AttributeIterator) -> object {
        return self;
    }
}
class _AttributeListIterator(_AttributeIterator) {
    def _dispose(self: _AttributeListIterator) -> object {
        self._capi.LLVMPY_DisposeAttributeListIter(self);
    }
    def _next(self: _AttributeListIterator) -> object {
        return ffi.ret_bytes(ffi.lib.LLVMPY_AttributeListIterNext(self));
    }
}
class _AttributeSetIterator(_AttributeIterator) {
    def _dispose(self: _AttributeSetIterator) -> object {
        self._capi.LLVMPY_DisposeAttributeSetIter(self);
    }
    def _next(self: _AttributeSetIterator) -> object {
        return ffi.ret_bytes(ffi.lib.LLVMPY_AttributeSetIterNext(self));
    }
}
class _BlocksIterator(_ValueIterator) {
    with entry {
        kind = 'block';
    }

    def _dispose(self: _BlocksIterator) -> object {
        self._capi.LLVMPY_DisposeBlocksIter(self);
    }
    def _next(self: _BlocksIterator) -> object {
        return ffi.lib.LLVMPY_BlocksIterNext(self);
    }
}
class _ArgumentsIterator(_ValueIterator) {
    with entry {
        kind = 'argument';
    }

    def _dispose(self: _ArgumentsIterator) -> object {
        self._capi.LLVMPY_DisposeArgumentsIter(self);
    }
    def _next(self: _ArgumentsIterator) -> object {
        return ffi.lib.LLVMPY_ArgumentsIterNext(self);
    }
}
class _InstructionsIterator(_ValueIterator) {
    with entry {
        kind = 'instruction';
    }

    def _dispose(self: _InstructionsIterator) -> object {
        self._capi.LLVMPY_DisposeInstructionsIter(self);
    }
    def _next(self: _InstructionsIterator) -> object {
        return ffi.lib.LLVMPY_InstructionsIterNext(self);
    }
}
class _OperandsIterator(_ValueIterator) {
    with entry {
        kind = 'operand';
    }

    def _dispose(self: _OperandsIterator) -> object {
        self._capi.LLVMPY_DisposeOperandsIter(self);
    }
    def _next(self: _OperandsIterator) -> object {
        return ffi.lib.LLVMPY_OperandsIterNext(self);
    }
}
class _IncomingBlocksIterator(_ValueIterator) {
    with entry {
        kind = 'block';
    }

    def _dispose(self: _IncomingBlocksIterator) -> object {
        self._capi.LLVMPY_DisposeIncomingBlocksIter(self);
    }
    def _next(self: _IncomingBlocksIterator) -> object {
        return ffi.lib.LLVMPY_IncomingBlocksIterNext(self);
    }
}
with entry {
    ffi.lib.LLVMPY_PrintValueToString.argtypes = [ffi.LLVMValueRef, POINTER(c_char_p)];
    ffi.lib.LLVMPY_GetGlobalParent.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_GetGlobalParent.restype = ffi.LLVMModuleRef;
    ffi.lib.LLVMPY_GetValueName.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_GetValueName.restype = c_char_p;
    ffi.lib.LLVMPY_SetValueName.argtypes = [ffi.LLVMValueRef, c_char_p];
    ffi.lib.LLVMPY_TypeOf.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_TypeOf.restype = ffi.LLVMTypeRef;
    ffi.lib.LLVMPY_GlobalGetValueType.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_GlobalGetValueType.restype = ffi.LLVMTypeRef;
    ffi.lib.LLVMPY_GetTypeName.argtypes = [ffi.LLVMTypeRef];
    ffi.lib.LLVMPY_GetTypeName.restype = c_void_p;
    ffi.lib.LLVMPY_GetLinkage.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_GetLinkage.restype = c_int;
    ffi.lib.LLVMPY_SetLinkage.argtypes = [ffi.LLVMValueRef, c_int];
    ffi.lib.LLVMPY_GetVisibility.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_GetVisibility.restype = c_int;
    ffi.lib.LLVMPY_SetVisibility.argtypes = [ffi.LLVMValueRef, c_int];
    ffi.lib.LLVMPY_GetDLLStorageClass.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_GetDLLStorageClass.restype = c_int;
    ffi.lib.LLVMPY_SetDLLStorageClass.argtypes = [ffi.LLVMValueRef, c_int];
    ffi.lib.LLVMPY_GetEnumAttributeKindForName.argtypes = [c_char_p, c_size_t];
    ffi.lib.LLVMPY_GetEnumAttributeKindForName.restype = c_uint;
    ffi.lib.LLVMPY_AddFunctionAttr.argtypes = [ffi.LLVMValueRef, c_uint];
    ffi.lib.LLVMPY_IsDeclaration.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_IsDeclaration.restype = c_int;
    ffi.lib.LLVMPY_FunctionAttributesIter.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_FunctionAttributesIter.restype = ffi.LLVMAttributeListIterator;
    ffi.lib.LLVMPY_CallInstAttributesIter.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_CallInstAttributesIter.restype = ffi.LLVMAttributeListIterator;
    ffi.lib.LLVMPY_InvokeInstAttributesIter.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_InvokeInstAttributesIter.restype = ffi.LLVMAttributeListIterator;
    ffi.lib.LLVMPY_GlobalAttributesIter.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_GlobalAttributesIter.restype = ffi.LLVMAttributeSetIterator;
    ffi.lib.LLVMPY_ArgumentAttributesIter.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_ArgumentAttributesIter.restype = ffi.LLVMAttributeSetIterator;
    ffi.lib.LLVMPY_FunctionBlocksIter.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_FunctionBlocksIter.restype = ffi.LLVMBlocksIterator;
    ffi.lib.LLVMPY_FunctionArgumentsIter.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_FunctionArgumentsIter.restype = ffi.LLVMArgumentsIterator;
    ffi.lib.LLVMPY_BlockInstructionsIter.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_BlockInstructionsIter.restype = ffi.LLVMInstructionsIterator;
    ffi.lib.LLVMPY_InstructionOperandsIter.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_InstructionOperandsIter.restype = ffi.LLVMOperandsIterator;
    ffi.lib.LLVMPY_PhiIncomingBlocksIter.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_PhiIncomingBlocksIter.restype = ffi.LLVMIncomingBlocksIterator;
    ffi.lib.LLVMPY_DisposeAttributeListIter.argtypes = [ffi.LLVMAttributeListIterator];
    ffi.lib.LLVMPY_DisposeAttributeSetIter.argtypes = [ffi.LLVMAttributeSetIterator];
    ffi.lib.LLVMPY_DisposeBlocksIter.argtypes = [ffi.LLVMBlocksIterator];
    ffi.lib.LLVMPY_DisposeInstructionsIter.argtypes = [ffi.LLVMInstructionsIterator];
    ffi.lib.LLVMPY_DisposeOperandsIter.argtypes = [ffi.LLVMOperandsIterator];
    ffi.lib.LLVMPY_DisposeIncomingBlocksIter.argtypes = [
        ffi.LLVMIncomingBlocksIterator
    ];
    ffi.lib.LLVMPY_AttributeListIterNext.argtypes = [ffi.LLVMAttributeListIterator];
    ffi.lib.LLVMPY_AttributeListIterNext.restype = c_void_p;
    ffi.lib.LLVMPY_AttributeSetIterNext.argtypes = [ffi.LLVMAttributeSetIterator];
    ffi.lib.LLVMPY_AttributeSetIterNext.restype = c_void_p;
    ffi.lib.LLVMPY_BlocksIterNext.argtypes = [ffi.LLVMBlocksIterator];
    ffi.lib.LLVMPY_BlocksIterNext.restype = ffi.LLVMValueRef;
    ffi.lib.LLVMPY_ArgumentsIterNext.argtypes = [ffi.LLVMArgumentsIterator];
    ffi.lib.LLVMPY_ArgumentsIterNext.restype = ffi.LLVMValueRef;
    ffi.lib.LLVMPY_InstructionsIterNext.argtypes = [ffi.LLVMInstructionsIterator];
    ffi.lib.LLVMPY_InstructionsIterNext.restype = ffi.LLVMValueRef;
    ffi.lib.LLVMPY_OperandsIterNext.argtypes = [ffi.LLVMOperandsIterator];
    ffi.lib.LLVMPY_OperandsIterNext.restype = ffi.LLVMValueRef;
    ffi.lib.LLVMPY_IncomingBlocksIterNext.argtypes = [ffi.LLVMIncomingBlocksIterator];
    ffi.lib.LLVMPY_IncomingBlocksIterNext.restype = ffi.LLVMValueRef;
    ffi.lib.LLVMPY_GetOpcodeName.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_GetOpcodeName.restype = c_void_p;
    ffi.lib.LLVMPY_IsConstant.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_IsConstant.restype = c_bool;
    ffi.lib.LLVMPY_GetValueKind.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_GetValueKind.restype = c_int;
    ffi.lib.LLVMPY_GetConstantIntRawValue.argtypes = [
        ffi.LLVMValueRef,
        POINTER(c_bool)
    ];
    ffi.lib.LLVMPY_GetConstantIntRawValue.restype = POINTER(c_uint64);
    ffi.lib.LLVMPY_GetConstantIntNumWords.argtypes = [ffi.LLVMValueRef];
    ffi.lib.LLVMPY_GetConstantIntNumWords.restype = c_uint;
    ffi.lib.LLVMPY_GetConstantFPValue.argtypes = [ffi.LLVMValueRef, POINTER(c_bool)];
    ffi.lib.LLVMPY_GetConstantFPValue.restype = c_double;
}

