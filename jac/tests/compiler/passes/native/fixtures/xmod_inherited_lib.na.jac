"""Native cross-module inherited-field fixture (issue #6659 Bug 2): the library
declares a base `node` with two fields and an empty subtype. A consumer that
imports the subtype and WRITES one of the inherited fields (`p.yaw = ...`,
`p.pitch += ...`) must resolve the inherited field's offset through the imported
MRO the same way a read does -- a write that cannot find the inherited field
slot wrongly raised E5090."""

node Entity { has yaw: float = 0.0, pitch: float = 0.0; }

node Player(Entity) {}
