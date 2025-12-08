node BFSNode {
    has id: int;
    has jac_node_size: int = 8;
}

edge JunkEdge {}

walker BFS {
    has visited_512: list[bool] = [False] * 512;

    can run with BFSNode entry {
        print("Visited node ID: %d" % here.id);
        if (self.visited_512[here.id]) {
            return;
        }
        self.visited_512[here.id] = True;
        visit [-->];
        visit [->:JunkEdge:->];
    }
}

with entry {
    nodes = [BFSNode(id=0), BFSNode(id=1), BFSNode(id=2), BFSNode(id=3), BFSNode(id=4)];
    junk = BFSNode(id=5);  # To ensure IDs are not reused
    root ++> nodes[0];
    nodes[0] ++> nodes[1];
    nodes[0] ++> nodes[2];
    nodes[1] ++> nodes[3];
    nodes[1] ++> nodes[4];
    BFS();
    wlk = BFS() spawn nodes[0];
    print(wlk.__ttg__);
}
