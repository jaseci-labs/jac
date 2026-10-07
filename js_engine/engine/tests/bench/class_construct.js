require("./_h.js");
// Derived-class construction (rollup-style AST nodes): base classes with fields,
// subclasses with implicit constructors, explicit super() calls, instance fields.
class NodeBase { included = false; constructor(type, start) { this.type = type; this.start = start; this.end = start + 1; } get size() { return this.end - this.start; } }
class Expression extends NodeBase { deoptimized = false; }
class Identifier extends Expression { constructor(name, start) { super("Identifier", start); this.name = name; } }
class Literal extends Expression { value = 0; }
class CallExpression extends Expression { constructor(callee, args, start) { super("CallExpression", start); this.callee = callee; this.arguments = args; this.end = start + args.length + 2; } }
class MemberExpression extends Expression { computed = false; constructor(object, property, start) { super("MemberExpression", start); this.object = object; this.property = property; } }
class Statement extends NodeBase {}
class ExpressionStatement extends Statement { constructor(expression) { super("ExpressionStatement", expression.start); this.expression = expression; } }
function run(n) {
  let s = 0;
  for (let i = 0; i < n; i++) {
    const id = new Identifier("x" + (i & 7), i);
    const lit = new Literal("Literal", i + 1); lit.value = i & 255;
    const mem = new MemberExpression(id, new Identifier("y", i + 2), i);
    const call = new CallExpression(mem, [lit, id], i);
    const st = new ExpressionStatement(call);
    s = (s + st.expression.callee.object.name.length + call.arguments.length + st.size + (call.deoptimized ? 1 : 0) + (lit.included ? 1 : 0) + lit.value) & 0xffffff;
  }
  return s;
}
done("class_construct", run(N(150000)));
