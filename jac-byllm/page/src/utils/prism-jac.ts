import Prism from 'prismjs';

Prism.languages.jac = {
    'comment': [
        {
            pattern: /(^|[^\\])\/\*[\s\S]*?(?:\*\/|$)/,
            lookbehind: true,
            greedy: true
        },
        {
            pattern: /(^|[^\\:])\/\/.*/,
            lookbehind: true,
            greedy: true
        }
    ],
    'string': {
        pattern: /("|')(?:\\(?:\r\n|[\s\S])|(?!\1)[^\\\r\n])*\1/,
        greedy: true
    },
    'class-name': {
        pattern: /(\b(?:walker|node|edge|type|ability|can)\s+)\w+/i,
        lookbehind: true
    },
    'keyword': /\b(?:walker|node|edge|graph|spawn|with|entry|exit|disengage|take|ignore|visit|revisit|type|has|can|report|by|anchor|private|public|import|include|for|while|if|else|elif|skip|strict|hybrid|async|sync|test|assert|global|yield)\b/,
    'builtin': /\b(?:int|str|list|dict|bool|float|object|edge|node|walker|true|false|null|uuid|context|info|details|bool|dict|list|int|str|edge|node|walker)\b/,
    'boolean': /\b(?:true|false)\b/,
    'function': /\b\w+(?=\()/,
    'number': /(?:\b\d+\.?\d*|\B\.\d+)(?:e[+-]?\d+)?/i,
    'operator': /[<>]=?|[!=]=?=?|--?|\+\+?|&&?|\|\|?|[?*/~^%]/,
    'punctuation': /[{}[\];(),.:]/
};
