var parent = {};
parent.x = 42;
var child = Object.create(parent);
child.x = undefined;
if (child.x !== undefined) {
  throw new Error("expected undefined, got " + child.x);
}
console.log("undefined-own-prop ok");
