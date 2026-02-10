# Test py_code_block (PYNLINE) inside enum blocks.
# Lark grammar: enum_block: LBRACE assignment_list (py_code_block | free_code)* RBRACE

enum Color {
  RED = 1,
  GREEN = 2,
  BLUE = 3
  ::py::
# Inline Python in enum block
print("Enum defined")
::py::
}
