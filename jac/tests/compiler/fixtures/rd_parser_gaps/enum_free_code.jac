# Test free_code (with entry block) inside enum blocks.
# Lark grammar: enum_block: LBRACE assignment_list (py_code_block | free_code)* RBRACE

enum Status {
  ACTIVE = 1,
  INACTIVE = 2
  with entry {
    print("Status enum loaded");
  }
}
