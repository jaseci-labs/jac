"""Memory layout generator."""

import copy

from .upmem_codegen import MemoryRange


class DPUObjMemoryCtx:
    """Memory layout generator for a single type of object."""

    def __init__(self) -> None:
        """Initialize an empty memory layout."""
        self.obj_memory: bytes = b""
        self.obj_id_to_range: dict[int, MemoryRange] = {}

    def download_obj(self, obj_id: int, obj_stream: bytes) -> None:
        """Add a new object to the memory layout."""
        self.obj_id_to_range[obj_id] = MemoryRange(
            ptr=len(self.obj_memory), size=len(obj_stream)
        )
        self.obj_memory += obj_stream

    def get_obj_range(self, obj_id: int) -> MemoryRange:
        """Get the range of a certain object."""
        return self.obj_id_to_range[obj_id]

    def change_obj_stream(self, obj_id: int, obj_stream: bytes) -> None:
        """Change the value of an object."""
        buf = bytearray(self.obj_memory)
        mem_range = self.obj_id_to_range[obj_id]
        ptr = mem_range.ptr
        assert mem_range.size == len(obj_stream)
        buf[ptr : ptr + len(obj_stream)] = obj_stream
        self.obj_memory = bytes(buf)

    def __len__(self) -> int:
        """Size of the mem."""
        return len(self.obj_memory)


class DPUMemoryCtx:
    """Generator for the entire memory layout."""

    def __init__(
        self,
        metadata_mem_ctx: DPUObjMemoryCtx,
        container_mem_ctx: DPUObjMemoryCtx,
        node_mem_ctx: DPUObjMemoryCtx,
        walker_mem_ctx: DPUObjMemoryCtx,
    ) -> None:
        """Initialize to combine all memory contexts."""
        self.metadata_mem_ctx = metadata_mem_ctx
        self.node_mem_ctx = node_mem_ctx
        self.walker_mem_ctx = walker_mem_ctx
        self.container_mem_ctx = container_mem_ctx

    def get_metadata_range(self) -> MemoryRange:
        """Get the metadata memory range."""
        return MemoryRange(0, len(self.metadata_mem_ctx))

    def get_node_range(self, node_id: int) -> MemoryRange:
        """Get the node memory range."""
        return self.node_mem_ctx.obj_id_to_range[node_id].add_offset(
            len(self.container_mem_ctx) + len(self.metadata_mem_ctx)
        )

    def get_walker_range(self, walker_id: int) -> MemoryRange:
        """Get the walker memory range."""
        return self.walker_mem_ctx.obj_id_to_range[walker_id].add_offset(
            len(self.container_mem_ctx)
            + len(self.node_mem_ctx)
            + len(self.metadata_mem_ctx)
        )

    def get_container_range(self, walker_id: int) -> MemoryRange:
        """Get the container memory range."""
        return self.container_mem_ctx.obj_id_to_range[walker_id].add_offset(
            len(self.metadata_mem_ctx)
        )

    def dump(self) -> bytes:
        """Sum up all the memory context contents."""
        return (
            self.metadata_mem_ctx.obj_memory
            + self.node_mem_ctx.obj_memory
            + self.walker_mem_ctx.obj_memory
            + self.container_mem_ctx.obj_memory
        )

    def clone(self) -> "DPUMemoryCtx":
        """Deep copy the object."""
        return copy.deepcopy(self)
