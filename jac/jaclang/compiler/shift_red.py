from jaclang.vendor.lark import Lark, exceptions

grammar_file = "jac.lark"

try:
    with open(grammar_file, "r") as f:
        grammar = f.read()

    parser = Lark(grammar, parser="lalr")   # LALR detects shift/reduce errors
    print("Grammar loaded successfully! No shift/reduce conflicts detected.")

except exceptions.GrammarError as e:
    print("GrammarError detected!")
    print(e)

except Exception as e:
    print("Other error occurred:")
    print(e)
