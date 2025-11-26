<!-- <a id="define-node-question" style="display: none;"></a> -->
??? question "What is node and how to define a node?"
    - Nodes are archetypes forming part of a graph, holding properties. You can define nodes with attributes and values:
    ```jac
      node node_name{
          has node_property: int;
      }
      node node_name{
          has node_property: int = 10;
      }
    ```

??? question "How to delete a node? "
    - You can delete a node using:
    ```jac
        del node_name;
    ```

??? question "How to connect two nodes?"
    - Nodes can be connected with generic edges (default) or custom edges (defined with specific properties).
    ```jac
      node_1 ++> node_2; # uni directional edge
      node_1 <++> node_2; # bidirectional edge
    ```

??? question "What is custom edge?"
    - Custom edges allow defining specific properties and behaviors for relationships between nodes
    ```jac
      edge edge_name{
          has edge_property: int = 10;
      }
    ```

??? question "How to connect nodes with custom edge?"
    - Nodes can be connected with a custom edge as follows:
    ```jac
      node_1 +: edge_name :+> node_2;
      node_1 +: edge_name :edge_property= 15: +> node_2; # connect with specific property value
    ```

??? question "How to delete connection or edge between two nodes?"
    - To delete a connection between nodes:
    ```jac
      node_1 del --> node_2;
    ```

??? question "What is walker and how to define a walker?"
    - A walker is an archetype that performs actions within the graph. It can traverse nodes through edges, performing operations at each step.
    ```jac
    walker walker_name {
      can walker_ability with `specific_node entry;
    }
    ```

??? question "How to visit all the Successor nodes of a node/ list of nodes?"
    - A walker can visit all successor nodes (directly connected nodes):
      ```jac
          visit [node_name -->];
      ```

??? question "How to get all the Successor nodes of a node/ list of nodes?"
    -  To retrieve all the successor nodes:
      ```jac
          print([node_name -->]);
      ```

??? question "How to get all edges that is connected with a node?"
    - You can retrieve all the edges connected to a node by using edge filtering expressions.
    ```jac
        print([edge node_a-->]);
        print([edge node_a<--]);
        print([edge node_list[0]-->]);
    ```

??? question "How to get all edges that is connected between two nodes?"
    - To get all edges between two nodes:
    ```jac
        print([edge node_1-->node_2]);
        print([edge node_list[0]-->node_list[1]]);

    ```

??? question "How do I connect a list of nodes to a single node, either in series or parallel?"
    - You can connect a list of nodes to a single node in both series (one after the other) or in parallel (all at once):
    ```jac
        # Series connection (one after the other)
        node_1 ++> node_list[0];
        for i to i < length(node_list) by i+=1 {
            node_list[i] ++> node_list[i+1];
        }

        # Parallel connection (all at once)
        node_1 ++> node_list;
    ```

??? question "How do I create a mesh connection between two lists of nodes?"
    - A mesh connection between two lists of nodes can be established, connecting each node in the first list to each node in the second list:
    ```jac
        node_list_1 ++> node_list_2;
    ```

??? question "How to spawn a walker from root?"
    - You can spawn a walker from a specific node or root:
    ```jac
        with entry {
          root spawn walker_name();
        }
    ```

??? question "How to setup special ability for a entry through a given node or root?"
    - You can set up special abilities for root or specific node entries in walkers:
    ```jac
        # Entry through root
        walker  walker_name {
          can walker_ability with `root entry;
        }
        # Entry through a given node
        walker  walker_name {
          can walker_ability with specific_node entry;
        }
        # Entry through root or a given node
        walker  walker_name {
          can walker_ability with `root | specific_node entry;
        }
    ```

??? question "How to set up special Object-Spatial abilities for a `root` or specific node entry in a walker?"
    - Walkers can have special DS abilities triggered through the `root` or a specific node. You can define such abilities based on where the walker starts its traversal:
    ```jac
        # Ability entry through the root
        walker walker_name {
          can walker_ability with `root entry;
        }

        # Ability entry through a specific node
        walker walker_name {
          can walker_ability with specific_node entry;
        }

        # Ability entry through either root or a specific node
        walker walker_name {
          can walker_ability with `root | specific_node entry;
        }
    ```
    - This allows you to specify different behavior depending on whether the walker enters the DS ability from the root or a particular node, or both.

??? question "What happens when using `can ability_name with entry` in a walker?"

    - The ability_name ability is called once at the start of the walker’s lifecycle. It is triggered when the walker is first spawned and acts as the initial entry point.
    - Key Point: This is executed only once at the beginning of the walker’s execution.
        jac

??? question "How to setup special ability of a node for a certain walker?"
    - You can setup special ability of a node for a certain walker using:
    ```jac
        node  node_name {
          can node_ability with walker_name entry;
        }
    ```

??? question "How can I access the current node instance in DS abilities of a walker?"
    - Current walker instance can be accessed using the `here` keyword within Object-Spatial abilities of the node.
    ```jac
    walker walker_name {

        can log_visit with test_node entry{
            print("Visiting node : ", here);
        }
    }
    ```

??? question "How to access the current walker inside DS abilities of a node?"
    - You can access the current walker instance inside Object-Spatial abilities of a node using the `self` keyword.
    ```jac
    node node_name {
        can node_ability with walker_name entry{
            print("Current walker : ", here);
        }
    }
    ```
??? question "How to access the current walker inside DS abilities of the current walker?"
    - You can access the current walker instance inside Object-Spatial abilities of the current walker using the `self` keyword.
    ```jac
    walker walker_name {
        can walker_ability with node_name entry{
            print("Current walker : ", self);
        }
    }
    ```

??? question "How to inherit walker?"
    - Walkers can inherit from other walkers and override their abilities:
    ```jac
        walker walker_1{
        }
        walker walker_2 : walker_1:{
        }
    ```

??? question "How to override walker ability?"
    - To override a walker’s ability:
    ```jac
        walker walker_1{
          can ability_1 with `root entry{
              print("write");
          }
        }
        walker walker_2 : walker_1:{
          override can ability_1 with `root entry{
              print("override");
          }
        }
    ```

??? question "How to filter nodes based on conditions?"
    - You can filter nodes by their type or properties when traversing the graph using filters like `(?Type)` or attribute conditions.
    ```jac
    print([root --> -:edge_type:-> (`?NodeType)]);
    print([root --> -:edge_type:-> (`?NodeType)](?attribute > value));
    ```

??? question "How do I traverse nodes in JacLang?"
    - You can traverse nodes using the visit operation, which allows you to move from one node to another along edges.
    ```jac
    visit [node_a -->];
    ```

??? question "Can I visualize my graph in JacLang?"
    - Yes, you can visualize your graph using built-in function `printgraph`.
    ```jac
    node a{
        has val:int;
    }
    with entry{
        end=root;
        for i in range(0,4){
            end++>(end:=[a(val=i) for i in range(0,3)]);
        }
        print(printgraph());  # Generates a DOT graph starting from the root node
    }
    ```

??? question "How to customize the visualization of the graph?"
    - You can use various parameters such as staring node,  depth, edge limit, node limit, and more to customize the output of `printgraph`. For example:
    ```jac
    print(printgraph(node_1, bfs=True, traverse=True, edge_type=["Edge1"], node_limit=100, edge_limit=900, depth=300, dot_file='graph.dot'));
    ```

??? question "What is BFS traversal in `printgraph`?"
    - By default, `printgraph` uses breadth-first search (BFS) to explore nodes. This can be controlled with the `bfs` flag.

??? question "Can I export the graph visualization to a file?"
    - Yes, you can specify a `dot_file` to save the output in a `.dot` file, which can be rendered using external graph visualization tools like Graphviz.

??? question "Can I exclude specific edge types from the visualization?"
    - Yes, using the `edge_type` parameter, you can exclude specific edge types from the visualization:
    ```jac
    print(printgraph(node_1, edge_type=["CustomEdge"]));
    ```

??? question " What parameters can I use with `printgraph`?"

    1. **Starting Node**:
    The node from where graph traversal or visualization begins.
    **Default**: Root.

    2. **Depth**:
    Limits how deep the traversal should go in the graph.
    **Default**: Infinity.

    3. **Edge Limit**:
    Sets a cap on the number of edges to include in the visualization.
    **Default**: 512.

    4. **Node Limit**:
    Specifies the maximum number of nodes to include.
    **Default**: 512.

    5. **BFS**:
    Enables Breadth-First Search (BFS) for node traversal.
    **Default**: True.

    6. **Edge Type**:
    Option to exclude specific edge types from the visualization.
    **Default**: An empty list (i.e., no exclusion).

    7. **dot_file**:
    Optional parameter to specify a file name for saving the DOT graph output. If provided, the visualization will be saved in this file.

??? question " How can I generate and visualize a graph from a `.jac` file using the CLI?"
    - You can use the `jac dot` command to generate a graph visualization from a `.jac` file. This command allows you to specify various options like depth, breadth traversal method, connection types, and node/edge limits. The generated graph is saved as a DOT file, which you can use with visualization tools like Graphviz.
    ```bash
    jac dot filename.jac
    ```

    - You can specify an initial node and limit the traversal depth:
    ```bash
    jac dot filename.jac --initial "StartNode" --depth 3
    ```

    - You can use the following file to customize the visualization:
        ```jac
        node a{
            has val:int;
        }
        with entry{
            x=[a(val=i) for i in range(0,3)];
            end=x[1];
            for i in range(0,8){
                locals()[chr(ord('b') + i)] = (values:=[a(val=j*i+5.2*i+6) for j in range(0,3)]);
                end ++> (end:=values);
            }
        }
        ```

??? question "What parameters can I use with the jac dot command?"

    - filename: The .jac file containing the graph definition.
    - initial: The initial node for traversal (default is root).
    - depth: The maximum depth for traversal (-1 for unlimited).
    - traverse: Flag to traverse the graph (False by default).
    - connection: List of edge types to include.
    - bfs: Use Breadth-First Search for traversal (False by default).
    - edge_limit: Maximum number of edges (512 by default).
    - node_limit: Maximum number of nodes (512 by default).
    - saveto: Specify a file path to save the generated DOT file.

    ```jac
    jac dot filename.jac --initial "StartNode" --depth 3 --traverse --connection "EdgeType1" --bfs --edge_limit 1000 --node_limit 1000 --saveto "output.dot"
    ```
