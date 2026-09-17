"""Native storage qualifiers that retain language semantics in LLVM values."""
import from jaclang.compiler.backends.native.llvm.ir.types { _TypedPointerType }

"""An unmanaged typed address, with the same LLVM spelling and ABI as a pointer.

Keep this qualifier in the type carried by loads, parameters, and phi nodes.
A raw byte address and a managed string must not share ownership operations
just because both have the LLVM spelling i8*.
"""
class RawPointerType(_TypedPointerType) {
    def __eq__(self: RawPointerType, other: object) -> bool {
        return isinstance(other, RawPointerType)
            and self.pointee == other.pointee
            and self.addrspace == other.addrspace;
    }

    def __hash__(self: RawPointerType) -> int {
        return hash((RawPointerType, self.pointee, self.addrspace));
    }
}
