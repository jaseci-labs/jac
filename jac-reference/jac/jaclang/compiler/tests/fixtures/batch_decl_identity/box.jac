"""Base type declaration; its impl lives in impl/box.impl.jac."""

obj Box {
    has value: int = 0;

    def clone -> Box;
}
