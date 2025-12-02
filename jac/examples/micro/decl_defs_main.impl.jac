"""Definitions of the walker and abilities."""

impl travelor.say_hello{
    "Hello" |> print;  # |> is a pipe forward operator
}

# :w: and :c: are aliases for :walker: and :abilitiy:
impl travelor.say_whatever(
    msg: str
) -> None {
    msg |> print;
}
