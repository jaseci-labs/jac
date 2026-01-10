# Jac Client Import System - Frontend Project Checklist

This document provides a comprehensive checklist of all import patterns needed in modern frontend projects, showing implementation status and Jac patterns.

## Quick Reference

- **Working** - Fully implemented and tested
- **In Progress** - Partially implemented or under development
- **Not Implemented** - Not yet supported
- ️ **Generates Invalid** - Generates code but produces invalid JavaScript
- **Proposed** - Design proposed, not yet implemented

> **Note on useState:** When using `has` variables in Jac client code, `useState` is automatically injected. You only need to explicitly import `useState` from React when using the hooks pattern directly (e.g., `[value, setValue] = useState(initial)`).

---

## Category 1: JavaScript Module Imports

### 1.1 Named Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import { useState } from 'react'` | `cl import from react { useState }` |  Working | `import { useState } from "react";` | Single named import (auto-injected for `has` vars) |
| `import { map, filter } from 'lodash'` | `cl import from lodash { map, filter }` |  Working | `import { map, filter } from "lodash";` | Multiple named imports |
| `import { get as httpGet } from 'axios'` | `cl import from axios { get as httpGet }` |  Working | `import { get as httpGet } from "axios";` | Named with alias |
| `import { createApp, ref as reactive } from 'vue'` | `cl import from vue { createApp, ref as reactive }` |  Working | `import { createApp, ref as reactive } from "vue";` | Mixed named + aliases |

### 1.2 Default Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import React from 'react'` | `cl import from react { default as React }` |  Working | `import React from "react";` | Default import |
| `import Component from './Button'` | `cl import from .Button { default as Component }` |  Working | `import Component from "./Button";` | Default with relative path |

### 1.3 Namespace Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import * as React from 'react'` | `cl import from react { * as React }` |  Working | `import * as React from "react";` | Namespace import |
| `import * as utils from './utils'` | `cl import from .utils { * as utils }` |  Working | `import * as utils from "./utils";` | Namespace with relative path |

### 1.4 Mixed Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import React, { useState } from 'react'` | `cl import from react { default as React, useState }` |  Working | `import React, { useState } from "react";` | Default + Named |
| `import React, * as All from 'react'` | `cl import from react { default as React, * as All }` |  Working | `import React, * as All from "react";` | Default + Namespace (rare) |
| `import * as _, { map } from 'lodash'` | `cl import from lodash { * as _, map }` | ️ Generates Invalid | `import * as _, { map } from "lodash";` | Named + Namespace - **Invalid JS** |

### 1.5 String Literal Imports (Hyphenated Packages)

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import { render } from 'react-dom'` | `cl import from "react-dom" { render }` |  Working | `import { render } from "react-dom";` | Hyphenated packages |
| `import { BrowserRouter } from 'react-router-dom'` | `cl import from "react-router-dom" { BrowserRouter }` |  Working | `import { BrowserRouter } from "react-router-dom";` | Multiple hyphens |
| `import styled from 'styled-components'` | `cl import from "styled-components" { default as styled }` |  Working | `import styled from "styled-components";` | Default with hyphens |

### 1.6 Relative Path Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import { helper } from './utils'` | `cl import from .utils { helper }` |  Working | `import { helper } from "./utils";` | Current directory |
| `import { format } from '../lib'` | `cl import from ..lib { format }` |  Working | `import { format } from "../lib";` | Parent directory |
| `import { settings } from '../../config'` | `cl import from ...config { settings }` |  Working | `import { settings } from "../../config";` | Grandparent directory |

---

## Category 2: Asset Imports (CSS, Images, Fonts)

### 2.1 CSS Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import './styles.css'` |  `cl import from ".styles.css"` |  Not Implemented | `import "./styles.css";` | Side-effect only import |
| `import styles from './Button.module.css'` |  `cl import from ".Button.module.css" { default as styles }` |  Not Implemented | `import styles from "./Button.module.css";` | CSS Modules |
| `import './global.css'` |  `cl import from ".global.css"` |  Not Implemented | `import "./global.css";` | Global CSS |
| `import 'tailwindcss/tailwind.css'` |  `cl import from "tailwindcss/tailwind.css"` |  Not Implemented | `import "tailwindcss/tailwind.css";` | Package CSS |

### 2.2 Image Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import logo from './logo.png'` |  `cl import from ".logo.png" { default as logo }` |  Not Implemented | `import logo from "./logo.png";` | PNG images |
| `import icon from './icon.svg'` |  `cl import from ".icon.svg" { default as icon }` |  Not Implemented | `import icon from "./icon.svg";` | SVG as URL/data |
| `import { ReactComponent as Icon } from './icon.svg'` |  `cl import from ".icon.svg" { ReactComponent as Icon }` |  Not Implemented | `import { ReactComponent as Icon } from "./icon.svg";` | SVG as React component (CRA/Vite) |
| `import hero from './hero.jpg'` |  `cl import from ".hero.jpg" { default as hero }` |  Not Implemented | `import hero from "./hero.jpg";` | JPEG images |
| `import banner from './banner.webp'` |  `cl import from ".banner.webp" { default as banner }` |  Not Implemented | `import banner from "./banner.webp";` | WebP images |
| `import gif from './animation.gif'` |  `cl import from ".animation.gif" { default as gif }` |  Not Implemented | `import gif from "./animation.gif";` | GIF images |

### 2.3 Font Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import './fonts/CustomFont.woff2'` |  `cl import from ".fonts.CustomFont.woff2"` |  Not Implemented | `import "./fonts/CustomFont.woff2";` | WOFF2 fonts |
| `import font from './fonts/Font.ttf'` |  `cl import from ".fonts.Font.ttf" { default as font }` |  Not Implemented | `import font from "./fonts/Font.ttf";` | TTF fonts |

### 2.4 Other Asset Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import video from './demo.mp4'` |  `cl import from ".demo.mp4" { default as video }` |  Not Implemented | `import video from "./demo.mp4";` | Video files |
| `import audio from './sound.mp3'` |  `cl import from ".sound.mp3" { default as audio }` |  Not Implemented | `import audio from "./sound.mp3";` | Audio files |
| `import pdf from './document.pdf'` |  `cl import from ".document.pdf" { default as pdf }` |  Not Implemented | `import pdf from "./document.pdf";` | PDF files |

---

## Category 3: Special Data Imports

### 3.1 JSON Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import data from './data.json'` |  `cl import from ".data.json" { default as data }` |  Not Implemented | `import data from "./data.json";` | JSON default import |
| `import config from './config.json' assert { type: 'json' }` |  `cl import from ".config.json" assert { type: 'json' } { default as config }` |  Not Implemented | `import config from "./config.json" assert { type: "json" };` | Import assertions (Stage 3) |
| `import { version } from './package.json'` |  `cl import from ".package.json" { version }` |  Not Implemented | `import { version } from "./package.json";` | Named JSON imports (some bundlers) |

### 3.2 Text/Raw File Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import text from './readme.txt?raw'` |  `cl import from ".readme.txt?raw" { default as text }` |  Not Implemented | `import text from "./readme.txt?raw";` | Raw text (Vite) |
| `import shader from './shader.glsl?raw'` |  `cl import from ".shader.glsl?raw" { default as shader }` |  Not Implemented | `import shader from "./shader.glsl?raw";` | Shader files |
| `import markdown from './doc.md?raw'` |  `cl import from ".doc.md?raw" { default as markdown }` |  Not Implemented | `import markdown from "./doc.md?raw";` | Markdown files |

---

## Category 4: Dynamic and Conditional Imports

### 4.1 Dynamic Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `const mod = await import('./module')` |  `mod = await cl.import(".module")` |  Not Implemented | `const mod = await import("./module");` | Async dynamic import |
| `import('./lazy').then(m => m.default)` |  `cl.import(".lazy").then((m) => m.default)` |  Not Implemented | `import("./lazy").then(m => m.default);` | Promise-based import |
| `const { Component } = await import('./Comp')` |  `{ Component } = await cl.import(".Comp")` |  Not Implemented | `const { Component } = await import("./Comp");` | Destructured dynamic import |

### 4.2 Conditional Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `if (dev) { await import('./devTools') }` |  `if dev { await cl.import(".devTools") }` |  Not Implemented | `if (dev) { await import("./devTools"); }` | Conditional dynamic import |
| `const mod = await import(isDev ? './dev' : './prod')` |  `mod = await cl.import(isDev ? ".dev" : ".prod")` |  Not Implemented | `const mod = await import(isDev ? "./dev" : "./prod");` | Ternary dynamic import |

---

## Category 5: Side-Effect Imports

### 5.1 Pure Side-Effect Imports

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import 'polyfills'` |  `cl import from polyfills` |  Not Implemented | `import "polyfills";` | Package side-effect |
| `import './init'` |  `cl import from .init` |  Not Implemented | `import "./init";` | Local side-effect |
| `import 'core-js/stable'` |  `cl import from "core-js/stable"` |  Not Implemented | `import "core-js/stable";` | Polyfill imports |
| `import '@testing-library/jest-dom'` |  `cl import from "@testing-library/jest-dom"` |  Not Implemented | `import "@testing-library/jest-dom";` | Test library augmentation |

---

## Category 6: Advanced/Special Patterns

### 6.1 Web Workers

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import Worker from './worker?worker'` |  `cl import from ".worker?worker" { default as Worker }` |  Not Implemented | `import Worker from "./worker?worker";` | Vite worker import |
| `new Worker(new URL('./worker.js', import.meta.url))` |  TBD |  Not Implemented | `new Worker(new URL("./worker.js", import.meta.url));` | Standard worker pattern |

### 6.2 WebAssembly

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import init from './lib.wasm'` |  `cl import from ".lib.wasm" { default as init }` |  Not Implemented | `import init from "./lib.wasm";` | WASM module |
| `import './module.wasm' assert { type: 'webassembly' }` |  `cl import from ".module.wasm" assert { type: 'webassembly' }` |  Not Implemented | `import "./module.wasm" assert { type: "webassembly" };` | WASM with assertions |

### 6.3 Import Maps (Browser)

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import React from 'react'` (via import map) |  Works via bundler |  Working | `import React from "react";` | Resolved by bundler/import map |

### 6.4 Scoped Packages

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import { Button } from '@company/ui'` |  `cl import from "@company/ui" { Button }` |  Not Implemented | `import { Button } from "@company/ui";` | Scoped package with @ |
| `import styles from '@/styles/main.css'` |  `cl import from "@/styles/main.css" { default as styles }` |  Not Implemented | `import styles from "@/styles/main.css";` | Alias imports (@ = src) |

### 6.5 Export Re-exports (Barrel Files)

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `export { Button } from './Button'` |  TBD |  Not Implemented | `export { Button } from "./Button";` | Re-export named |
| `export * from './components'` |  TBD |  Not Implemented | `export * from "./components";` | Re-export all |
| `export { default as Button } from './Button'` |  TBD |  Not Implemented | `export { default as Button } from "./Button";` | Re-export default as named |

### 6.6 Import Attributes (Query Parameters)

| JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|-------------------|-------------|--------|---------------------|-------|
| `import image from './img.png?url'` |  `cl import from ".img.png?url" { default as image }` |  Not Implemented | `import image from "./img.png?url";` | URL import (Vite) |
| `import Component from './Comp?inline'` |  `cl import from ".Comp?inline" { default as Component }` |  Not Implemented | `import Component from "./Comp?inline";` | Inline import |
| `import svg from './icon.svg?component'` |  `cl import from ".icon.svg?component" { default as svg }` |  Not Implemented | `import svg from "./icon.svg?component";` | SVG as component |

---

## Implementation Summary

### Fully Implemented (9 patterns)

1. Named imports (single, multiple, with aliases)
2. Default imports
3. Namespace imports
4. Mixed imports (default + named, default + namespace)
5. Relative path imports (., .., ..., etc.)
6. String literal imports (hyphenated packages)

### Not Yet Implemented (45+ patterns)

1. **Asset imports**: CSS, images (PNG, JPG, SVG, WebP, GIF), fonts (WOFF2, TTF), videos, audio, PDFs
2. **Data imports**: JSON, raw text files, markdown, shaders
3. **Dynamic imports**: Async imports, conditional imports
4. **Side-effect imports**: Pure side-effect imports for polyfills, initialization, CSS
5. **Special patterns**: Web Workers, WebAssembly, scoped packages (@company/pkg), path aliases (@/)
6. **Re-exports**: Barrel file patterns, export forwarding
7. **Import attributes**: Query parameters (?url, ?raw, ?worker, ?inline, ?component)
8. **Import assertions**: JSON assertions, WebAssembly assertions

**Note**: TypeScript-specific type imports are not needed as JAC provides native type safety.

### ️ Known Issues

1. Named + Namespace mix generates invalid JavaScript

---

## Priority Recommendations

### High Priority (Essential for most FE projects)

1. **CSS imports** - Critical for styling
2. **Image imports** (PNG, JPG, SVG) - Essential for UI
3. **Side-effect imports** - Needed for polyfills and initialization
4. **JSON imports** - Common for configuration
5. **Dynamic imports** - Code splitting and lazy loading

### Medium Priority (Common in modern projects)

1. **SVG as React components** - Popular in React projects
2. **CSS Modules** - Modern styling approach
3. **Scoped packages** (@company/pkg) - Monorepos and private packages
4. **Path aliases** (@/) - Developer experience
5. **Re-exports/Barrel files** - Code organization

### Low Priority (Advanced/Specialized)

1. **Web Workers** - Performance optimization
2. **WebAssembly** - Specialized use cases
3. **Import assertions** - Emerging standard
4. **Raw text imports** - Specific bundler features
5. **Query parameter imports** - Bundler-specific features

---

### Validation Strategy

1. **File extension detection**: Determine import type from extension
2. **Bundler awareness**: Generate code compatible with Vite, Webpack, etc.
3. **Type safety**: Provide type hints for imported assets
4. **Path resolution**: Handle relative paths, aliases, and node_modules

---

## Related Documentation

- See `docs/docs/internals/jac_import_patterns.md` for detailed implementation status
- See test files in `jac-client/jac_client/tests/` for examples
- See `jac/jaclang/compiler/` for implementation details

---

**Last Updated**: 2025-11-17
**Status**: Initial comprehensive checklist created
