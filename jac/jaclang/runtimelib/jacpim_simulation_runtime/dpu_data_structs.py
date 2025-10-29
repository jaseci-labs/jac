"""Define some data structures for DPU simulation runtime."""

import struct
from dataclasses import dataclass

MAX_DPU_THREAD_NUM = 12


@dataclass
class ContainerObject:
    """Container object to store walker state on DPU."""

    node_ptr: int
    node_size: int
    edge_num: int
    func_call: int  # Index of the function to call
    node_id: int

    def get_byte_stream(self) -> bytes:
        """Get the byte stream of the container object."""
        return struct.pack(
            "<IIIIQ",
            self.node_ptr,
            self.node_size,
            self.edge_num,
            self.func_call,
            self.node_id,
        )

    @classmethod
    def get_size(cls) -> int:
        """Get the size of the container object in bytes."""
        return 4 * 4 + 8

    @classmethod
    def get_type_def(cls) -> str:
        """Get the C type definition of the container object."""
        return "uint32_t node_ptr; uint32_t node_size; uint32_t edge_num; uint32_t func_call; uint64_t node_id;"  # noqa: E501


@dataclass
class Container:
    """Container to store multiple container objects."""

    container_objects: list[ContainerObject]

    def get_byte_stream(self) -> bytes:
        """Get the byte stream of the container object."""
        return b"".join([obj.get_byte_stream() for obj in self.container_objects])

    def get_type_def(self) -> str:
        """Get the C type definition of the container object."""
        return f"ContainerObject container_objects[{len(self.container_objects)}];"


@dataclass
class Metadata:
    """Metadata for DPU execution."""

    extra_mram_space_ptr: int  # Pointer to extra MRAM space
    walker_num: int
    walker_container_ptrs: list[int]  # Pointers to each walker's container
    trace_lengths: list[int]  # Lengths of each walker's trace
    walker_ptrs: list[int]
    walker_sizes: list[int]

    def get_byte_stream(self) -> bytes:
        """Get the C type definition of the metadata object."""
        # print(f"DEBUG: len(walker_container_ptrs) = {len(self.walker_container_ptrs)}, len(trace_lengths) = {len(self.trace_lengths)}")

        # Fill in with zeros if not enough walkers
        walker_container_ptrs = self.walker_container_ptrs + [0] * (
            MAX_DPU_THREAD_NUM - len(self.walker_container_ptrs)
        )
        trace_lengths = self.trace_lengths + [0] * (
            MAX_DPU_THREAD_NUM - len(self.trace_lengths)
        )
        walker_ptrs = self.walker_ptrs + [0] * (
            MAX_DPU_THREAD_NUM - len(self.walker_ptrs)
        )
        walker_sizes = self.walker_sizes + [0] * (
            MAX_DPU_THREAD_NUM - len(self.walker_sizes)
        )
        res = (
            struct.pack("<II", self.extra_mram_space_ptr, self.walker_num)
            + b"".join(struct.pack("<I", ptr) for ptr in walker_container_ptrs)
            + b"".join(struct.pack("<I", length) for length in trace_lengths)
            + b"".join(struct.pack("<I", ptr) for ptr in walker_ptrs)
            + b"".join(struct.pack("<I", size) for size in walker_sizes)
        )
        assert len(res) == self.get_metadata_size()
        return res

    @classmethod
    def get_metadata_size(cls) -> int:
        """Get the size of the metadata object in bytes."""
        return (
            4
            + 4
            + 4 * MAX_DPU_THREAD_NUM
            + 4 * MAX_DPU_THREAD_NUM
            + 4 * MAX_DPU_THREAD_NUM
            + 4 * MAX_DPU_THREAD_NUM
        )

    @classmethod
    def get_type_def(cls) -> str:
        """Get the C type definition of the metadata object."""
        return f"uint32_t extra_mram_space; uint32_t walker_num; uint32_t walker_container_ptrs[{MAX_DPU_THREAD_NUM}]; uint32_t trace_lengths[{MAX_DPU_THREAD_NUM}]; uint32_t walker_ptrs[{MAX_DPU_THREAD_NUM}]; uint32_t walker_sizes[{MAX_DPU_THREAD_NUM}];"  # noqa: E501
