
import random;
import os;
import struct;
import from jaclang.runtimelib.machine {JacMachine}

node Start {
  has id: int = 0;
  def get_byte_stream() {
    res = struct.pack("<Q", self.id);
    return res;
  }
  static def get_type_def() {
    return "uint64_t id;";
  }
}

node Page {
  has id: int;
  has score: float = 0;
  has new_score: float = 0;
  def get_byte_stream() {
    return struct.pack("<Qdd", self.id, self.score, self.new_score);
  }
  static def get_type_def() {
    return "uint64_t id; double score; double new_score;";
  }
}

edge HyperLink {}

walker PageRank{
  has collected_score_8: float | None = None;
  can boot with Start entry {
    JacMachine.par_visit(self, PageRank(), [-->]);
  }
  def get_impl_boot_on_Start() {
    return """
    // printf("Starting load feed from user %d\\n", here->id);
    """;
  }
  can run with Page entry  {
    print(f"visit ID {here.id}");
    if (self.collected_score_8 is None) {
      if (len([->:HyperLink:->]) == 0) {
        return;
      }
      self.collected_score_8 = here.score / len([->:HyperLink:->]);
      visit [->:HyperLink:->];
    } else {
      here.new_score += self.collected_score_8;
    }
  }
  def get_type_def() {
    return "double collected_score_8;";
  }
  def get_byte_stream() {
    if self.collected_score_8 is None {

      return struct.pack("<d", -1.0);
    }
    else {

      return struct.pack("<d", self.collected_score_8);
    }
  }
  def get_impl_run_on_Page() {
    # Use node pointer here to access node (here) attributes
    # Use walker pointer here to access walker (self) attributes
    # No need to printf
    return """
    if (walker->collected_score_8 < 0) {
     walker->collected_score_8 = node->score / 100;
      for (int i = 0; i < edge_num; i++) {
        push_new_element_to_container(0);
      }
    } else {
      node->new_score += walker->collected_score_8;
    }
    """;
}
}

with entry {
  
  random.seed(0);
  nodes = [];
  NODE_NUM = 256;
  for i in range(NODE_NUM) {
    nodes.append(Page(id = i));
    root ++> nodes[i];
  }
  start_node = Start(id=0);
  root ++> start_node;
  for i in range(max(NODE_NUM, 25)) {
    start_node ++> nodes[i];
  }

  for i in range(NODE_NUM) {
    for j in range(NODE_NUM) {
      if (i == j) {
        continue;
      }
      if ((random.uniform(0, 1)) <= 0.5){
        nodes[i] +>:HyperLink:+> nodes[j];
      }
    }
  }
  JacMachine.jacpim_init();
  for i in range(NODE_NUM){
    wlk = PageRank();
    JacMachine.jacpim_spawn(wlk, nodes[i]);
  }
  JacMachine.jacpim_start();
}