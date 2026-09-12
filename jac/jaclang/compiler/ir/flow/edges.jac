import from jaclang.compiler.ir.flow.nodes { UniCFGNode }

edge CfgSucc: UniCFGNode --> UniCFGNode {}

edge CfgTrue: UniCFGNode --> UniCFGNode {}

edge CfgFalse: UniCFGNode --> UniCFGNode {}
