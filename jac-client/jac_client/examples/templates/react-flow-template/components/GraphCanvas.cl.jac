cl import from react { useState, useCallback }
cl import from "@xyflow/react" {
    ReactFlow,
    Background,
    Controls,
    addEdge,
    applyNodeChanges,
    applyEdgeChanges
}


cl import from "..graph.initial_nodes" { nodes as initialNodes }
cl import from "..graph.initial_edges" { edges as initialEdges }

cl import "@xyflow/react/dist/style.css";

cl {
    def:pub GraphCanvas() -> any {

        [nodes, setNodes] = useState(initialNodes);
        [edges, setEdges] = useState(initialEdges);

        # Handle node drag / resize / delete
        onNodesChange = useCallback(
            lambda changes:any -> None {
                setNodes(lambda prev:any -> None {
                    return applyNodeChanges(changes, prev);
                });
            },
            []
        );

        # Handle edge updates
        onEdgesChange = useCallback(
            lambda changes:any -> None {
                setEdges(lambda prev:any -> None {
                    return applyEdgeChanges(changes, prev);
                });
            },
            []
        );

        # Handle new connections
        onConnect = useCallback(
            lambda connection:any -> None {
                setEdges(lambda prev:any -> None {
                    return addEdge(connection, prev);
                });
            },
            []
        );

        return <ReactFlow
            nodes={nodes}
            edges={edges}
            onNodesChange={onNodesChange}
            onEdgesChange={onEdgesChange}
            onConnect={onConnect}
            fitView
        >
            <Background />
            <Controls />
        </ReactFlow>;
    }
}
