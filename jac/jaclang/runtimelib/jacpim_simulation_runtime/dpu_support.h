void get(void * buf, uint32_t start, uint32_t size) {
    // Read the node from MRAM
    uint32_t addr = DPU_MRAM_HEAP_POINTER + start;
    mram_read((__mram_ptr void*)(addr), buf, size);
}

void save(void * buf, uint32_t start, uint32_t size) {
    // Write the walker back to MRAM
    uint32_t addr = DPU_MRAM_HEAP_POINTER + start;
    mram_write(buf, (__mram_ptr void*)(addr), size);
}


void run_thread(uint64_t walker_container_ptr, uint64_t trace_length, char * node_buffer, char * walker_buffer) {
    ContainerObject container_obj;
    for (uint32_t i = 0; i < trace_length; i++) {
        get(&container_obj, walker_container_ptr + i * sizeof(ContainerObject), sizeof(ContainerObject));
        #ifdef DEBUG
        printf("DPU Tasklet %u: Container Object - Walker ptr: %lu, Walker size: %lu, Node ptr: %lu, Node size: %lu, Edge num: %lu, Func call: %lu\n", me(), container_obj.walker_ptr, container_obj.walker_size, container_obj.node_ptr, container_obj.node_size, container_obj.edge_num, container_obj.func_call);
        #endif
        // Load node
        get(node_buffer, container_obj.node_ptr, container_obj.node_size);
        // Load walker
        if (i == 0) {
          get(walker_buffer, container_obj.walker_ptr, container_obj.walker_size);
        }
        // Run on node
        run_on_node(walker_buffer, node_buffer, container_obj.edge_num, container_obj.func_call);
        // Save walker
        if (i == trace_length - 1) {
          save(walker_buffer, container_obj.walker_ptr, container_obj.walker_size);
        }
        // Save node
        save(node_buffer, container_obj.node_ptr, container_obj.node_size);
    }
}
BARRIER_INIT(my_barrier, NR_TASKLETS);
