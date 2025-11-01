from jaclang.runtimelib.jacpim_simulation_runtime.upmem_codegen import MemoryRange
from jaclang.runtimelib.archetype import NodeArchetype, WalkerArchetype
import struct


class MemoryBlock:
    def __init__(
        self, reg: "MemoryBlockRegister", prev_block: "MemoryBlock | None"
    ) -> None:
        self.prev_block = prev_block
        self.reg = reg
        self.block_id = reg.register_block(self)

    """A memory block interface."""

    def get_size(self) -> int:
        """Get the size of the memory block."""
        raise NotImplementedError

    def get_ptr(self) -> int:
        """Get the pointer of the memory block."""
        if self.prev_block is None:
            return 0
        return self.prev_block.get_ptr() + self.prev_block.get_size()

    def get_mem_range(self) -> MemoryRange:
        """Get the memory range of the memory block."""
        return MemoryRange(self.get_ptr(), self.get_size())

    def get_dump(self) -> bytes:
        """Get the byte representation of the memory block."""
        raise NotImplementedError


class MemoryBlockRegister:
    """Register for memory blocks for one DPU core."""

    def __init__(self) -> None:
        """Initialize an empty register."""
        self.blocks: list[MemoryBlock] = []

    def register_block(self, block: MemoryBlock) -> int:
        self.blocks.append(block)
        return len(self.blocks) - 1

    def get_block(self, block_id: int) -> MemoryBlock:
        return self.blocks[block_id]

    def dump_all(self) -> bytes:
        """Dump all memory blocks into bytes, in order of their pointers."""
        dumps: dict[int, bytes] = {}
        for block in self.blocks:
            dumps[block.get_ptr()] = block.get_dump()
        # assert that the entire dumps cover continuous memory from 0 to end
        max_ptr = max(dumps.keys())
        assert all(
            ptr + len(dumps[ptr]) in dumps or ptr == max_ptr for ptr in dumps.keys()
        ), "Memory blocks do not cover continuous memory."
        assert 0 in dumps, "Memory blocks do not start from pointer 0."
        # Sort by pointer and concatenate all dumps
        return b"".join(dumps[ptr] for ptr in sorted(dumps))


class MemoryObjectBlock(MemoryBlock):
    """A memory block representing an object."""

    def __init__(
        self, reg: MemoryBlockRegister, prev_block: MemoryBlock, obj: bytes
    ) -> None:
        """Initialize the object memory block."""
        super().__init__(reg, prev_block)
        self.obj = obj

    def get_size(self) -> int:
        """Get the size of the object memory block."""
        return len(self.obj)

    def get_dump(self) -> bytes:
        """Get the byte representation of the object memory block."""
        return self.obj


class MemoryPointerBlock(MemoryBlock):
    """A memory block representing a pointer."""

    def __init__(
        self, reg: MemoryBlockRegister, prev_block: MemoryBlock, ptr_block_id: int
    ) -> None:
        """Initialize the pointer memory block."""
        super().__init__(reg, prev_block)
        self.ptr_block_id = ptr_block_id

    def get_size(self) -> int:
        """Get the size of the pointer memory block."""
        return 8  # Assuming 64-bit pointers

    def get_dump(self) -> bytes:
        # Get the byte representation of the pointer memory block.
        block = self.reg.get_block(self.ptr_block_id)
        ptr_value = block.get_ptr()
        return struct.pack("<Q", ptr_value)


class MemoryJacObjectBlock(MemoryObjectBlock):
    def __init__(
        self,
        reg: MemoryBlockRegister,
        prev_block: MemoryBlock,
        jac_obj: NodeArchetype | WalkerArchetype,
    ) -> None:
        """Initialize the jac object memory block."""
        super().__init__(reg, prev_block, jac_obj.get_byte_stream())
