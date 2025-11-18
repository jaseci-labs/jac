from __future__ import annotations


def return_value() -> int:
    return 42


def return_expression() -> int:
    x = 10
    return x * 2


def return_none() -> None:
    print("executing")
    return


def no_return() -> None:
    print("implicit None return")


def conditional_return(x: int) -> int:
    if x > 0:
        return x
    else:
        return 0


def early_return(flag: bool) -> None:
    if flag:
        return
    print("after early return check")


def multiple_returns(val: str) -> int:
    if val == "high":
        return 100
    elif val == "medium":
        return 50
    elif val == "low":
        return 10
    else:
        return 0


print(return_value())
print(return_expression())
print(return_none())  # type: ignore[func-returns-value]
print(no_return())  # type: ignore[func-returns-value]
print(conditional_return(5))
print(conditional_return(-3))
early_return(True)
early_return(False)
print(multiple_returns("high"))
print(multiple_returns("low"))
print(multiple_returns("unknown"))
