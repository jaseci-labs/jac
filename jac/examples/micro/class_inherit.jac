"""Super simple example of inheritance."""

obj Parent {
    def init {
    # Parent initialization
    }

    def speak -> None {
    # Parent speaking
    }
}

obj Child(Parent) {
    def init {
        # Child initialization
        Parent.init();  # Initialize parent, :o: is alias for :obj
    }
}
