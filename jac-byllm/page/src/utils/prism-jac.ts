import Prism from 'prismjs';

Prism.languages.jac = {
  // ----------------------------
  // 1. Comments (Highest Priority)
  // ----------------------------
  comment: [
    {
      // Jac block comments: #* ... *#
      pattern: /#\*[\s\S]*?\*#/,
      greedy: true
    },
    {
      // Jac single-line comments: # ...
      pattern: /#.*/,
      greedy: true
    }
  ],

  // ----------------------------
  // 2. Strings
  // ----------------------------
  string: {
    // Triple quotes or normal quotes
    pattern: /("""|'''|("|'))(?:\\[\s\S]|(?!\1)[^\\])*\1/,
    greedy: true
  },

  // ----------------------------
  // 3. Numbers
  // ----------------------------
  number: {
    pattern: /\b(?:0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?[jJ]?)\b/,
    greedy: true
  },

  // ----------------------------
  // 4. Keywords
  // ----------------------------
  keyword: {
    pattern: /\b(?:async|await|continue|entry|exit|del|assert|check|break|finally|for|from|elif|else|if|except|pass|raise|return|try|while|with|to|by|spawn|ignore|visit|sem|disengage|lambda|priv|protect|pub|sem|static|override|let|abs|has|case|match|impl|can|def|walker|node|edge|class|test)\b/,
    lookbehind: false
  },

  // ----------------------------
  // 5. Built-in Types
  // ----------------------------
  builtin: {
    pattern: /\b(?:str|int|float|list|tuple|set|dict|bool|bytes|any|type)\b/,
    alias: 'class-name'
  },

  // ----------------------------
  // 6. Boolean Literals
  // ----------------------------
  boolean: {
    pattern: /\b(?:True|False|None)\b/,
    alias: 'keyword'
  },

  // ----------------------------
  // 7. Functions
  // ----------------------------
  function: {
    pattern: /\b\w+(?=\s*\()/,
    greedy: true
  },

  // ----------------------------
  // 8. Operators
  // ----------------------------
  operator: /[<>]=?|[!=]=?=?|--?|\+\+?|&&?|\|\|?|[*\/%^~]|<<|>>|:=|\?|@|\b(?:and|or|not|in|is)\b/,

  // ----------------------------
  // 9. Punctuation
  // ----------------------------
  punctuation: /[{}[\];(),.:]/
};

export default Prism.languages.jac;
