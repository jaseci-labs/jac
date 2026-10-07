// LET-004 fixture: redeclaring let in same scope must produce a SyntaxError
let x = 1;
let x = 2; // SyntaxError: Identifier 'x' has already been declared
