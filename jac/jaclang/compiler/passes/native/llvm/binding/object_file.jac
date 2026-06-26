import from jaclang.compiler.passes.native.llvm.binding { ffi }
import from ctypes { c_bool, c_char_p, c_char, c_size_t, string_at, c_uint64, POINTER }
class SectionIteratorRef(ffi.ObjectRef) {
    def name(self: SectionIteratorRef) -> object {
        return ffi.lib.LLVMPY_GetSectionName(self);
    }
    def is_text(self: SectionIteratorRef) -> object {
        return ffi.lib.LLVMPY_IsSectionText(self);
    }
    def size(self: SectionIteratorRef) -> object {
        return ffi.lib.LLVMPY_GetSectionSize(self);
    }
    def address(self: SectionIteratorRef) -> object {
        return ffi.lib.LLVMPY_GetSectionAddress(self);
    }
    def data(self: SectionIteratorRef) -> object {
        return string_at(ffi.lib.LLVMPY_GetSectionContents(self), self.size());
    }
    def is_end(self: SectionIteratorRef, object_file: Any) -> object {
        return ffi.lib.LLVMPY_IsSectionIteratorAtEnd(object_file, self);
    }
    def next(self: SectionIteratorRef) -> object {
        ffi.lib.LLVMPY_MoveToNextSection(self);
    }
    def _dispose(self: SectionIteratorRef) -> object {
        ffi.lib.LLVMPY_DisposeSectionIterator(self);
    }
}
class ObjectFileRef(ffi.ObjectRef) {
    @classmethod
    def from_data(cls: Any, data: Any) -> object {
        return cls(ffi.lib.LLVMPY_CreateObjectFile(data, len(data)));
    }
    @classmethod
    def from_path(cls: Any, path: Any) -> object {
        with open(path, 'rb') as f {
            data = f.read();
        }
        return cls(ffi.lib.LLVMPY_CreateObjectFile(data, len(data)));
    }
    def sections(self: ObjectFileRef) -> object {
        it = SectionIteratorRef(ffi.lib.LLVMPY_GetSections(self));
        while not it.is_end(self) {
            yield it;
            it.next();
        }
    }
    def _dispose(self: ObjectFileRef) -> object {
        ffi.lib.LLVMPY_DisposeObjectFile(self);
    }
}
with entry {
    ffi.lib.LLVMPY_CreateObjectFile.argtypes = [c_char_p, c_size_t];
    ffi.lib.LLVMPY_CreateObjectFile.restype = ffi.LLVMObjectFileRef;
    ffi.lib.LLVMPY_DisposeObjectFile.argtypes = [ffi.LLVMObjectFileRef];
    ffi.lib.LLVMPY_GetSections.argtypes = [ffi.LLVMObjectFileRef];
    ffi.lib.LLVMPY_GetSections.restype = ffi.LLVMSectionIteratorRef;
    ffi.lib.LLVMPY_DisposeSectionIterator.argtypes = [ffi.LLVMSectionIteratorRef];
    ffi.lib.LLVMPY_MoveToNextSection.argtypes = [ffi.LLVMSectionIteratorRef];
    ffi.lib.LLVMPY_IsSectionIteratorAtEnd.argtypes = [
        ffi.LLVMObjectFileRef,
        ffi.LLVMSectionIteratorRef
    ];
    ffi.lib.LLVMPY_IsSectionIteratorAtEnd.restype = c_bool;
    ffi.lib.LLVMPY_GetSectionName.argtypes = [ffi.LLVMSectionIteratorRef];
    ffi.lib.LLVMPY_GetSectionName.restype = c_char_p;
    ffi.lib.LLVMPY_GetSectionSize.argtypes = [ffi.LLVMSectionIteratorRef];
    ffi.lib.LLVMPY_GetSectionSize.restype = c_uint64;
    ffi.lib.LLVMPY_GetSectionAddress.argtypes = [ffi.LLVMSectionIteratorRef];
    ffi.lib.LLVMPY_GetSectionAddress.restype = c_uint64;
    ffi.lib.LLVMPY_GetSectionContents.argtypes = [ffi.LLVMSectionIteratorRef];
    ffi.lib.LLVMPY_GetSectionContents.restype = POINTER(c_char);
    ffi.lib.LLVMPY_IsSectionText.argtypes = [ffi.LLVMSectionIteratorRef];
    ffi.lib.LLVMPY_IsSectionText.restype = c_bool;
}

