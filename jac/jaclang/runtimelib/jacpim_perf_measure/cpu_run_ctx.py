"""CPU-based execution context for JacPIM walkers, managing their lifecycle and DPU boundary crossings."""

from jaclang.runtimelib.archetype import (
    EdgeAnchor,
    NodeAnchor,
    NodeArchetype,
    WalkerArchetype,
)
from jaclang.runtimelib.jacpim_mapping_analysis import JacPIMMappingCtx
from jaclang.runtimelib.jacpim_mapping_analysis.data_mapper import DPU_NUM
from jaclang.runtimelib.jacpim_simulation_runtime.dpu_data_structs import (
    Container,
    ContainerObject,
    MAX_DPU_THREAD_NUM,
    Metadata,
)
from jaclang.runtimelib.jacpim_simulation_runtime.dpu_mem_layout import (
    DPUMemoryCtx,
    DPUObjMemoryCtx,
)
from jaclang.runtimelib.jacpim_simulation_runtime.upmem_codegen import (
    CodeGenContext,
    FunctionDef,
    TypeDef,
    gen_code,
)
from jaclang.runtimelib.jacpim_static_analysis.info_extract import extract_name
from jaclang.runtimelib.jacpim_static_analysis.static_ctx import JacPIMStaticCtx


class JacPIMCPURunCtx:
    """CPU-based execution context for JacPIM walkers."""

    pending_walkers: list[WalkerArchetype] = []
    active_walkers: list[list[WalkerArchetype]] | None = None
    all_walkers: list[WalkerArchetype] = []
    total_cross_dpu_jumps: int = 0

    @classmethod
    def setter(cls) -> None:
        """Initialize the CPU run context."""
        cls.pending_walkers = []
        cls.active_walkers = []
        for _ in range(DPU_NUM):
            cls.active_walkers.append([])

    @classmethod
    def add_pending_walker(
        cls, walker: WalkerArchetype, start_node: NodeArchetype
    ) -> None:
        """Add a walker to the pending list."""
        walker.__jac__.next = [start_node.__jac__]
        print(f"Adding pending walker: {extract_name(walker)} starting at node {extract_name(start_node)}")
        cls.pending_walkers.append(walker)
        cls.all_walkers.append(walker)

    @classmethod
    def get_pending_nodes_and_walkers(
        cls,
    ) -> list[tuple[NodeArchetype, WalkerArchetype]]:
        """Get the list of pending walkers along with their start nodes."""
        result = []
        for walker in cls.pending_walkers:
            if len(walker.__jac__.next) == 0:
                raise RuntimeError("Walker has no next node to visit.")
            start_node = walker.__jac__.next[0]
            if isinstance(start_node, EdgeAnchor):
                start_node = start_node.target
            if not isinstance(start_node, NodeAnchor):
                raise RuntimeError("Start node is not a NodeAnchor.")
            result.append((start_node.archetype, walker))
        return result

    @classmethod
    def get_active_walkers(cls) -> list[list[WalkerArchetype]]:
        """Get the list of active walkers per DPU."""
        if cls.active_walkers is None:
            raise RuntimeError("Active walkers not initialized.")
        return cls.active_walkers

    @classmethod
    def set_pending_walkers_to_active(cls) -> None:
        """Move pending walkers to active walkers if there is space in the target DPU."""
        new_pending_walkers: list[WalkerArchetype] = []
        print(f"{cls.active_walker_count()} walkers already active. Setting {len(cls.pending_walkers)} pending walkers to active")
        for walker in cls.pending_walkers:
            if len(walker.__jac__.next) == 0:
                raise RuntimeError("Walker has no next node to visit.")
            start_node = walker.__jac__.next[0]
            if isinstance(start_node, EdgeAnchor):
                start_node = start_node.target
            start_node_idx = JacPIMStaticCtx.get_all_nodes().index(start_node.archetype)
            dpu_id = JacPIMMappingCtx.get_partitioning().get(start_node_idx)
            if dpu_id is None:
                raise RuntimeError("DPU ID not found for node.")
            if len(cls.get_active_walkers()[dpu_id]) >= MAX_DPU_THREAD_NUM:
                new_pending_walkers.append(walker)
                continue
            cls.get_active_walkers()[dpu_id].append(walker)
        cls.pending_walkers = new_pending_walkers

    @classmethod
    def run_one_walker(cls, walker: WalkerArchetype) -> bool:
        """
        Run one walker until completion or DPU boundary.

        Return True if walker is done (nothing is left to visit).
        Return False if the walker wants to jump to another DPU.
        """
        walker_anchor = walker.__jac__
        warch = walker_anchor.archetype
        # print(f"Running walker: {extract_name(warch)}")
        # print(f" Next number of next anchors: {len(walker_anchor.next)}")

        # Get static context and partitioning once
        all_nodes = JacPIMStaticCtx.get_all_nodes()
        partitioning = JacPIMMappingCtx.get_partitioning()

        # Determine current DPU
        current_dpu = None

        # Main execution loop - continue until done or DPU boundary
        while walker_anchor.next and len(walker_anchor.next) > 0:

            # Get the next location
            next_anchor = walker_anchor.next[0]
            if isinstance(next_anchor, EdgeAnchor):
                next_anchor = next_anchor.target

            next_node = next_anchor.archetype

            # Check if it's a valid node
            if not isinstance(next_node, NodeArchetype):
                # Skip non-node archetypes
                walker_anchor.next.pop(0)
                continue

            # Get DPU mapping for next node
            try:
                next_node_idx = all_nodes.index(next_node)
                target_dpu = partitioning.get(next_node_idx)

                if target_dpu is None:
                    raise RuntimeError(
                        f"Node index {next_node_idx} not mapped to any DPU"
                    )

            except ValueError:
                raise RuntimeError(f"Node {next_node} not found in static context")

            # Determine current DPU if not set yet
            if current_dpu is None:
                current_dpu = target_dpu  # First move

            # DPU BOUNDARY CHECK
            if target_dpu != current_dpu:
                # Walker wants to cross DPU boundary - stop here
                cls.total_cross_dpu_jumps += 1
                return False

            # Same DPU - execute one step
            # Pop the next location and process it
            current_loc = walker_anchor.next.pop(0).archetype
            current_node = (
                current_loc
                if isinstance(current_loc, NodeArchetype)
                else current_loc.__jac__.target.archetype
            )
            current_node_idx = all_nodes.index(current_node)
            walker_idx = cls.all_walkers.index(walker)
            # Log the visit
            DPUAllMemoryCtx.record_walker_trace(walker_idx, current_node_idx)

            # Execute walker abilities on this location (same pattern as spawn_call)
            # walker ability with loc entry
            for i in warch._jac_entry_funcs_:
                if i.trigger and isinstance(current_loc, i.trigger):
                    i.func(warch, current_loc)
                if walker_anchor.disengaged:
                    return True  # Walker is done

            # loc ability with any entry
            for i in current_loc._jac_entry_funcs_:
                if not i.trigger:
                    i.func(current_loc, warch)
                if walker_anchor.disengaged:
                    return True  # Walker is done

            # loc ability with walker entry
            for i in current_loc._jac_entry_funcs_:
                if i.trigger and isinstance(warch, i.trigger):
                    i.func(current_loc, warch)
                if walker_anchor.disengaged:
                    return True  # Walker is done

            # loc ability with walker exit
            for i in current_loc._jac_exit_funcs_:
                if i.trigger and isinstance(warch, i.trigger):
                    i.func(current_loc, warch)
                if walker_anchor.disengaged:
                    return True  # Walker is done

            # loc ability with any exit
            for i in current_loc._jac_exit_funcs_:
                if not i.trigger:
                    i.func(current_loc, warch)
                if walker_anchor.disengaged:
                    return True  # Walker is done

            # walker ability with loc exit
            for i in warch._jac_exit_funcs_:
                if i.trigger and isinstance(current_loc, i.trigger):
                    i.func(warch, current_loc)
                if walker_anchor.disengaged:
                    return True  # Walker is done

        # Walker has no more moves - it's done
        return True

    @classmethod
    def run_all_active_walkers(cls) -> None:
        """
        Run all active walkers once.

        If a walker wants to jump to another DPU, it will be moved to the pending list.
        A walker that finishes will be removed.
        """
        active_walkers = cls.get_active_walkers()
        print(f"Running all {cls.active_walker_count()} active walkers")
        DPUAllMemoryCtx.start_running()
        for dpu_id in range(DPU_NUM):
            for walker in active_walkers[dpu_id]:
                is_done = cls.run_one_walker(walker)
                if not is_done:
                    # Move to pending list
                    cls.pending_walkers.append(walker)
            # A walker is either done or moved to pending - clear active list
        DPUAllMemoryCtx.finish_running()
        for dpu_id in range(DPU_NUM):
            active_walkers[dpu_id] = []

    @classmethod
    def has_pending_walkers(cls) -> bool:
        """Check if there are pending walkers."""
        return len(cls.pending_walkers) > 0
    
    @classmethod
    def active_walker_count(cls) -> int:
        """Get the total count of active walkers across all DPUs."""
        return sum(len(dpu_walkers) for dpu_walkers in cls.get_active_walkers())

    @classmethod
    def has_active_walkers(cls) -> bool:
        """Check if there are active walkers."""
        return any(len(dpu_walkers) > 0 for dpu_walkers in cls.get_active_walkers())

    @classmethod
    def run_until_all_done(cls) -> None:
        """Run until all walkers are done."""
        while cls.has_pending_walkers() or cls.has_active_walkers():
            cls.set_pending_walkers_to_active()
            cls.run_all_active_walkers()
    
    @classmethod
    def stop_walker(cls, walker: WalkerArchetype) -> None:
        """Stop a walker."""
        # Remove from active walkers
        walker.__jac__.disengaged = True
        for dpu_walkers in cls.get_active_walkers():
            if walker in dpu_walkers:
                print(f"Found walker to stop: {extract_name(walker)}")
                
                dpu_walkers.remove(walker)
                print(f"Stopped active walker: {extract_name(walker)}")
                print(f"  Remaining active walkers: {cls.active_walker_count()}")
                return
        # Remove from pending walkers
        if walker in cls.pending_walkers:
            cls.pending_walkers.remove(walker)
            print(f"Stopped pending walker: {extract_name(walker)}")
            return
        print(f"Walker {extract_name(walker)} not found among active or pending walkers.")

    @classmethod
    def get_all_active_walkers(cls) -> list[WalkerArchetype]:
        """Get a flat list of all active walkers across all DPUs."""
        if cls.active_walkers is None:
            raise RuntimeError("Active walkers not initialized.")
        all_active = []
        for dpu_walkers in cls.active_walkers:
            all_active.extend(dpu_walkers)
        return all_active

    @classmethod
    def get_all_walkers(cls) -> list[WalkerArchetype]:
        """Get a list of all walkers that have been added to the context."""
        return cls.all_walkers


class DPUAllMemoryCtx:
    """Generator for all DPUs' memory layout."""

    # Initialize all DPUs' memory contexts (NUM_DPU)
    dpu_metadata_ctxs: list[DPUObjMemoryCtx] = [
        DPUObjMemoryCtx() for _ in range(DPU_NUM)
    ]
    dpu_node_ctxs: list[DPUObjMemoryCtx] = [DPUObjMemoryCtx() for _ in range(DPU_NUM)]
    dpu_walker_ctxs: list[DPUObjMemoryCtx] = [DPUObjMemoryCtx() for _ in range(DPU_NUM)]
    dpu_container_ctxs: list[DPUObjMemoryCtx] = [
        DPUObjMemoryCtx() for _ in range(DPU_NUM)
    ]
    walker_traces: dict[int, list[int]] = {}
    all_memory_dumps: list[list[DPUMemoryCtx]] = []

    @classmethod
    def node_snapshot_one_dpu(cls, dpu_id: int) -> DPUObjMemoryCtx:
        """Create a memory context for node snapshot."""
        node_mem_ctx = DPUObjMemoryCtx()
        for node_idx, node in enumerate(JacPIMStaticCtx.get_all_nodes()):
            if JacPIMMappingCtx.get_partitioning().get(node_idx) != dpu_id:
                continue
            node_mem_ctx.download_obj(node_idx, node.get_byte_stream())
        return node_mem_ctx

    @classmethod
    def node_snapshot_all_dpu(cls) -> list[DPUObjMemoryCtx]:
        """Create a memory context for node snapshot."""
        cls.dpu_node_ctxs = [
            cls.node_snapshot_one_dpu(dpu_id) for dpu_id in range(DPU_NUM)
        ]
        return cls.dpu_node_ctxs

    @classmethod
    def walker_snapshot_one_dpu(cls, dpu_id: int) -> DPUObjMemoryCtx:
        """Create a memory context for all active walkers on a DPU."""
        walker_mem_ctx = DPUObjMemoryCtx()
        for walker in JacPIMCPURunCtx.get_active_walkers()[dpu_id]:
            walker_id = JacPIMCPURunCtx.get_all_walkers().index(walker)
            walker_mem_ctx.download_obj(walker_id, walker.get_byte_stream())
        return walker_mem_ctx

    @classmethod
    def walker_snapshot_all_dpu(cls) -> list[DPUObjMemoryCtx]:
        """Create a memory context for all active walkers on all DPUs."""
        cls.dpu_walker_ctxs = [
            cls.walker_snapshot_one_dpu(dpu_id) for dpu_id in range(DPU_NUM)
        ]
        return cls.dpu_walker_ctxs

    @classmethod
    def container_snapshot_one_dpu(
        cls, dpu_id: int, walker_traces: dict[int, list[int]]
    ) -> DPUObjMemoryCtx:
        """Create a memory context for all containers on a DPU."""
        for walker_idx, walker_trace in walker_traces.items():
            if JacPIMMappingCtx.get_partitioning().get(walker_trace[0]) != dpu_id:
                continue
            container_objects: list[ContainerObject] = []
            walker = JacPIMCPURunCtx.get_all_walkers()[walker_idx]
            walker_id = JacPIMCPURunCtx.get_all_walkers().index(walker)
            walker_size = len(walker.get_byte_stream())
            for node_idx in walker_trace:
                node = JacPIMStaticCtx.get_all_nodes()[node_idx]
                node_size = len(node.get_byte_stream())
                edge_num = len(node.__jac__.edges)
                container_objects.append(
                    ContainerObject(
                        walker_ptr=cls.dpu_walker_ctxs[dpu_id].get_obj_range(walker_id).add_offset(Metadata.get_metadata_size()).add_offset(len(cls.dpu_node_ctxs[dpu_id])).ptr,
                        walker_size=walker_size,
                        node_ptr=cls.dpu_node_ctxs[dpu_id].get_obj_range(node_idx).add_offset(Metadata.get_metadata_size()).ptr,
                        node_size=node_size,
                        edge_num=edge_num,
                        func_call=JacPIMSimulationCtx.index_function_defs(
                            extract_name(node), extract_name(walker)
                        ),
                    )
                )
            cls.dpu_container_ctxs[dpu_id].download_obj(
                walker_id, Container(container_objects).get_byte_stream()
            )

        return cls.dpu_container_ctxs[dpu_id]

    @classmethod
    def container_snapshot_all_dpu(
        cls, walker_traces: dict[int, list[int]]
    ) -> list[DPUObjMemoryCtx]:
        """Create a memory context for all containers on all DPUs."""
        cls.dpu_container_ctxs = [
            cls.container_snapshot_one_dpu(dpu_id, walker_traces)
            for dpu_id in range(DPU_NUM)
        ]
        return cls.dpu_container_ctxs

    @classmethod
    def metadata_snapshot_one_dpu(cls, dpu_id: int) -> DPUObjMemoryCtx:
        """Create a memory context for metadata on a DPU."""
        metadata = Metadata(
            walker_num=0,  # to be filled later
            walker_container_ptrs=[0] * MAX_DPU_THREAD_NUM,  # to be filled later
            extra_mram_space_ptr=0,  # to be filled later
            trace_lengths=[0] * MAX_DPU_THREAD_NUM,  # to be filled later
        )
        extra_mram_space_ptr = (
            len(metadata.get_byte_stream())
            + len(cls.dpu_node_ctxs[dpu_id])
            + len(cls.dpu_walker_ctxs[dpu_id])
            + len(cls.dpu_container_ctxs[dpu_id])
        )
        mem_ctx = DPUMemoryCtx(
            metadata_mem_ctx=DPUObjMemoryCtx(),
            node_mem_ctx=cls.dpu_node_ctxs[dpu_id],
            walker_mem_ctx=cls.dpu_walker_ctxs[dpu_id],
            container_mem_ctx=cls.dpu_container_ctxs[dpu_id],
        )
        metadata.extra_mram_space_ptr = extra_mram_space_ptr
        metadata.walker_num = len(JacPIMCPURunCtx.get_active_walkers()[dpu_id])
        # print(f"DEBUG: DPU {dpu_id} has {metadata.walker_num} active walkers")
        metadata.walker_container_ptrs = [
            mem_ctx.get_container_range(
                JacPIMCPURunCtx.get_all_walkers().index(walker)
            ).add_offset(Metadata.get_metadata_size()).add_offset(len(cls.dpu_node_ctxs[dpu_id])).add_offset(len(cls.dpu_walker_ctxs[dpu_id])).ptr
            for walker in JacPIMCPURunCtx.get_active_walkers()[dpu_id]
        ]
        metadata.trace_lengths = [
            len(cls.walker_traces[JacPIMCPURunCtx.get_all_walkers().index(walker_arch)])
            for walker_arch in JacPIMCPURunCtx.get_active_walkers()[dpu_id]
        ]
        metadata_mem_ctx = DPUObjMemoryCtx()
        # print("DEBUG: Downloading metadata")
        metadata_mem_ctx.download_obj(0, metadata.get_byte_stream())
        # print(metadata.get_byte_stream())
        return metadata_mem_ctx

    @classmethod
    def metadata_snapshot_all_dpu(cls) -> list[DPUObjMemoryCtx]:
        """Create a memory context for metadata on all DPUs."""
        cls.dpu_metadata_ctxs = [
            cls.metadata_snapshot_one_dpu(dpu_id) for dpu_id in range(DPU_NUM)
        ]
        return cls.dpu_metadata_ctxs

    @classmethod
    def start_running(cls) -> None:
        """Snapshot nodes and walkers for all DPUs."""
        # Clear previous memory contexts
        cls.dpu_node_ctxs = [DPUObjMemoryCtx() for _ in range(DPU_NUM)]
        cls.dpu_walker_ctxs = [DPUObjMemoryCtx() for _ in range(DPU_NUM)]
        cls.dpu_metadata_ctxs = [DPUObjMemoryCtx() for _ in range(DPU_NUM)]
        cls.dpu_container_ctxs = [DPUObjMemoryCtx() for _ in range(DPU_NUM)]
        cls.walker_traces = {}

        cls.node_snapshot_all_dpu()
        cls.walker_snapshot_all_dpu()

    @classmethod
    def record_walker_trace(cls, walker_id: int, node_idx: int) -> None:
        """Record the trace of a walker visiting nodes."""
        if walker_id not in cls.walker_traces:
            cls.walker_traces[walker_id] = []
        # print(f"DEBUG: Recording walker {walker_id} visiting node {node_idx}")
        cls.walker_traces[walker_id].append(node_idx)

    @classmethod
    def finish_running(cls) -> list[DPUMemoryCtx]:
        """Snapshot containers and metadata for all DPUs."""
        cls.container_snapshot_all_dpu(cls.walker_traces)
        cls.metadata_snapshot_all_dpu()
        res = [
            DPUMemoryCtx(
                metadata_mem_ctx=cls.dpu_metadata_ctxs[dpu_id],
                node_mem_ctx=cls.dpu_node_ctxs[dpu_id],
                walker_mem_ctx=cls.dpu_walker_ctxs[dpu_id],
                container_mem_ctx=cls.dpu_container_ctxs[dpu_id],
            ).clone()
            for dpu_id in range(DPU_NUM)
        ]
        cls.all_memory_dumps.append(res)
        return res


class JacPIMSimulationCtx:
    """Simulation context for UPMEM codegen."""

    function_defs: list[FunctionDef] | None = None

    @classmethod
    def get_node_types(cls, all_nodes: list[NodeArchetype]) -> list[TypeDef]:
        """Extract node types from all nodes."""
        extracted_nodes: dict[str, str] = {}
        for node in all_nodes:
            type_name = extract_name(node)
            extracted_nodes[type_name] = node.get_type_def()
        res = [
            TypeDef(name=name, definition=definition)
            for name, definition in extracted_nodes.items()
        ]
        return res

    @classmethod
    def get_walker_types(cls, all_walkers: list[WalkerArchetype]) -> list[TypeDef]:
        """Extract walker types from all walkers."""
        extracted_walkers: dict[str, str] = {}
        for walker in all_walkers:
            type_name = extract_name(walker)
            extracted_walkers[type_name] = walker.get_type_def()
        res = [
            TypeDef(name=name, definition=definition)
            for name, definition in extracted_walkers.items()
        ]
        return res

    @classmethod
    def get_walker_abilities(
        cls,
        walkers: list[WalkerArchetype],
        walker_type: TypeDef,
        node_types: list[TypeDef],
    ) -> list[FunctionDef]:
        """Extract walker abilities from all walkers."""
        if cls.function_defs is not None:
            return cls.function_defs
        result: list[FunctionDef] = []
        for walker in walkers:
            object_methods = [
                method_name
                for method_name in dir(walker)
                if callable(getattr(walker, method_name))
                and method_name.startswith("get_impl_")
            ]
            for object_method in object_methods:
                name = object_method.split("_")[2]
                node_type_name = object_method.split("_")[4]
                node_type_def = [
                    node_type
                    for node_type in node_types
                    if node_type.name == node_type_name
                ][0]
                func_def = FunctionDef(
                    name=name,
                    body=getattr(walker, object_method)(),
                    walker_type=walker_type,
                    node_type=node_type_def,
                )
                if func_def not in result:
                    result.append(func_def)
        cls.function_defs = result
        return result

    @classmethod
    def context_gen(cls) -> CodeGenContext:
        """Generate the codegen context."""
        all_nodes = JacPIMStaticCtx.get_all_nodes()
        all_walkers = JacPIMCPURunCtx.get_all_walkers()
        node_types = cls.get_node_types(all_nodes)
        walker_types = cls.get_walker_types(all_walkers)
        walker_abilities = cls.get_walker_abilities(
            all_walkers, walker_types[0], node_types
        )

        max_node_size = max([len(node.get_byte_stream()) for node in all_nodes])
        max_walker_size = max([len(walker.get_byte_stream()) for walker in all_walkers])

        return CodeGenContext(
            max_node_size=max_node_size,
            max_walker_size=max_walker_size,
            node_types=node_types,
            walker_types=walker_types,
            run_ability_functions=walker_abilities,
            metadata_definition=Metadata.get_type_def(),
            container_object_definition=ContainerObject.get_type_def(),
        )

    @classmethod
    def index_function_defs(cls, node_type: str, walker_type: str) -> int:
        """Index function definitions by walker type and node type."""
        if cls.function_defs is None:
            cls.context_gen()
        if cls.function_defs is None:
            raise RuntimeError("Function defs not generated.")
        for idx, func_def in enumerate(cls.function_defs):
            if (
                func_def.node_type.name == node_type
                and func_def.walker_type.name == walker_type
            ):
                return idx
        raise ValueError(
            f"Function definition not found for {node_type} and {walker_type}."
        )

    @classmethod
    def save_codegen_file(cls, file_path: str) -> str:
        """Save the codegen file to the specified path."""
        context = cls.context_gen()
        code = gen_code(context)
        with open(file_path, "w") as f:
            f.write(code)
        return code
