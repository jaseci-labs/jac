"""Base module with generic classes."""

import from abc { ABC }

class Node {}

class BaseContainer[T](ABC) {
    def init(self: BaseContainer[T], data: T) -> None {
        self.data: T = data;
    }
}

class TypedContainer[T: Node](BaseContainer[T]) {}

class NodeContainer(TypedContainer[Node]) {}
