import random;
import from jaclang.runtimelib.machine {JacMachine}
import struct;
node Data {
   has id: int; 
   def get_byte_stream() {
       return struct.pack("<Q", self.id);
   }
    def get_type_def() {
        return "uint64_t id;";
    }
}

walker Finder {
    has id: int = 0;
    can up with Data entry {
        if (len([-->]) == 0) {
            print(f"Found Node {here.id}");
        } else {
            visit [-->];
        }
    }
    def get_type_def() {
        return "uint64_t id;";
    }
    def get_byte_stream() {
        return struct.pack("<Q", self.id);
    }
    def get_impl_up_on_Data() {
        return """
        #ifdef DEBUG
        printf("DPU Tasklet %u: Data Node - ID: %lu\\n", me(), node->id);
        #endif

        if (edge_num == 0) {
        #ifdef DEBUG
            printf("Found Node %lu\\n", node->id);
        #endif
        } else {
            for (uint32_t i = 0; i < edge_num; i++) {
                push_new_element_to_container(0);
            }
        }
        """;
    }
}

def random_tree(nodes: list) -> None {
    edges = [];
    for i in range(1, len(nodes)) {
        u = nodes[i];
        v = nodes[i // 2];
        u ++> v;
        print(f"{u.id} -> {v.id}"); }
}



with entry {
    NUM_NODES_PER_TREE = 128;
    NUM_TREE = 40;
    random.seed(0);
    all_nodes = [];
    for i in range(NUM_TREE) {
        nodes = [Data(id = id) for id in range(i * NUM_NODES_PER_TREE, (i + 1) * NUM_NODES_PER_TREE)];
        for node in nodes {
            root ++> node;
        }
        random_tree(nodes);
        all_nodes.extend(nodes);
    }
    print(f"Spawn on node {all_nodes[NUM_NODES_PER_TREE * NUM_TREE - 1].id}");
    JacMachine.jacpim_init();
    # JacMachine.jacpim_spawn(Finder(), all_nodes[NUM_NODES_PER_TREE * NUM_TREE - 1]);
    for i in range(NUM_TREE) {
        wlk = Finder();
        JacMachine.jacpim_spawn(wlk, all_nodes[i * NUM_NODES_PER_TREE + (random.randint(0, NUM_NODES_PER_TREE - 1))]);
    }
    JacMachine.jacpim_start();
}