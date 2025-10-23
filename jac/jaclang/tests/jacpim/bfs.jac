import random;
import from jaclang.runtimelib.machine {JacMachine}
import struct;
node BFSNode {
  has id:int;
  has jac_node_size: int = 8;
  def get_byte_stream() {
    return struct.pack("<q", self.id);
  }
  static def get_type_def() {
    return "int id;";
  }
}

glob NODE_NUM = 50;

walker BFS {
  has visited_512: list[bool] = [False] * 512;
  can run with BFSNode entry {
    print("Visited node ID: %d" % here.id);
    if (self.visited_512[here.id]) {
      return;
    }
    self.visited_512[here.id] = True;
    visit [-->];
  }

  def get_impl_run_on_BFSNode() {
    # Return C code here
    # return """printf(\"Visited node ID: %d\\n\", here.id);""";
    # Use node_id for here.id.
    return """
    if (walker->visited_512[node_id]) {
      return;
    }
    walker->visited_512[node_id] = true;
    push_new_element_to_container(0);
    """;
  }
  def get_byte_stream() {
    return struct.pack("<512?", *self.visited_512);
  }
  def get_type_def() {
    return "bool visited_512[512];";
  }
}


with entry {
  random.seed(0);
nodes = [];
for i in range(NODE_NUM) {
  nodes.append(BFSNode(id = i));
  root ++> nodes[i];
}

for i in range(NODE_NUM) {
  for j in range(NODE_NUM) {
    if (i == j) {
      continue;
    }
    if ((random.uniform(0, 1)) <= 0.5){
      nodes[i] ++> nodes[j];
    }
  }
}
  JacMachine.jacpim_init();
  # wlk = nodes[0] spawn BFS();
  JacMachine.jacpim_spawn(BFS(), nodes[0]);
  JacMachine.jacpim_start();
}
