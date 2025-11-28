// Monarch syntax definition for Jaclang
window.jaclangMonarchSyntax = {
  defaultToken: '',
  tokenPostfix: '.jac',

  functionKeywords: ['can', 'def', 'impl', 'with'],
  variableKeywords: ['has', 'glob'],
  typeKeywords: ['class', 'node', 'edge', 'walker', 'enum', 'obj', 'test', 'root', 'here'],
  controlKeywords: [
    'import', 'include', 'from', 'as',
    'if', 'else', 'elif', 'while', 'for', 'in', 'match', 'case',
    'return', 'break', 'continue', 'spawn', 'ignore', 'visit', 'disengage',
    'entry', 'exit', 'pass', 'try', 'except', 'finally', 'raise', 'assert',
    'async', 'await', 'lambda', 'by', 'to', 'del', 'check'
  ],

  literalKeywords: ['True', 'False', 'None'],

  typeIdentifiers: [
    'str', 'int', 'float', 'list', 'tuple', 'set', 'dict',
    'bool', 'bytes', 'any', 'type'
  ],

  operators: [
    '=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>=', '**=',
    '+', '-', '*', '**', '/', '//', '%', '@',
    '==', '!=', '<', '<=', '>', '>=',
    '<<', '>>', '&', '|', '^', '~',
  ],

  logicalOperators: [
    'and', 'or', 'not', 'is', 'in', 'not in', 'is not'
  ],

  symbols: /[=><!~?:&|+\-*\/\^%]+/,

  escapes: /\\(?:[abfnrtv\\"']|x[0-9A-Fa-f]{2}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8})/,

  tokenizer: {
    root: [
      // Comments
      [/#.*$/, 'comment'],

      // Multi-line comment: #* ... *#
      [/#\*/, 'comment', '@comment'],

      [/\b(can|def|impl|with)\b(?=\s+[a-zA-Z_]\w*)/, 'keyword.function', '@function_decl'],
      [/\b(class|node|edge|walker|enum|obj|test)\b(?=\s+[a-zA-Z_]\w*)/, 'keyword.type', '@type_decl'],

      // Keywords and identifiers
      [/[a-zA-Z_]\w*/, {
        cases: {
          '@functionKeywords': 'keyword.function',
          '@variableKeywords': 'keyword.variable',
          '@typeKeywords': 'keyword.type',
          '@controlKeywords': 'keyword.control',
          '@literalKeywords': 'constant.language',
          '@typeIdentifiers': 'type.identifier',
          '@logicalOperators': 'operator.logical',
          '@default': 'identifier'
        }
      }],

      // Numbers
      [/\d*\.\d+([eE][\-+]?\d+)?[jJ]?/, 'number.float'],
      [/0[xX][0-9a-fA-F]+/, 'number.hex'],
      [/0[oO]?[0-7]+/, 'number.octal'],
      [/0[bB][01]+/, 'number.binary'],
      [/\d+[jJ]?/, 'number'],

      // Strings
      [/'([^'\\]|\\.)*$/, 'string.invalid'],
      [/'/, 'string', '@string_single'],
      [/"/, 'string', '@string_double'],

      // Brackets
      [/[{}]/, '@brackets'],
      [/[()\[\]]/, '@brackets'],

      // Operators
      [/@symbols/, {
        cases: {
          '@operators': 'operator',
          '@default': ''
        }
      }],

      // Whitespace
      [/\s+/, 'white'],
    ],

    comment: [
      [/\*#/, 'comment', '@pop'],
      [/[^*#]+/, 'comment'],
      [/./, 'comment']
    ],

    function_decl: [
      [/\s+/, 'white'],
      [/[a-zA-Z_]\w*/, 'function.identifier', '@pop']
    ],

    type_decl: [
      [/\s+/, 'white'],
      [/[a-zA-Z_]\w*/, 'type.identifier', '@pop']
    ],

    string_single: [
      [/[^\\']+/, 'string'],
      [/@escapes/, 'string.escape'],
      [/\\./, 'string.escape.invalid'],
      [/'/, 'string', '@pop']
    ],

    string_double: [
      [/[^\\"]+/, 'string'],
      [/@escapes/, 'string.escape'],
      [/\\./, 'string.escape.invalid'],
      [/"/, 'string', '@pop']
    ]
  }
};

// Define the theme rules and colors for Monaco Editor
window.jacThemeRules = [
  { token: 'keyword.function', foreground: '569CD6' },
  { token: 'keyword.variable', foreground: '569CD6' },
  { token: 'keyword.type', foreground: '569CD6' },
  { token: 'keyword.control', foreground: 'C586C0' },
  { token: 'function.identifier', foreground: '9CDCFE' },
  { token: 'type.identifier', foreground: '4EC9B0' },
  { token: 'operator.logical', foreground: '569CD6' },
  { token: 'string', foreground: 'CE9178' },
  { token: 'number', foreground: 'B5CEA8' },
  { token: 'comment', foreground: '6A9955' },
  { token: 'operator', foreground: 'D4D4D4' },
  { token: 'delimiter.bracket', foreground: 'D4D4D4' },
];

// Define the theme colors for Monaco Editor
window.jacThemeColors = {
  'editor.foreground': '#FFFFFF',
  'editor.background': '#1E1E1E'
}
