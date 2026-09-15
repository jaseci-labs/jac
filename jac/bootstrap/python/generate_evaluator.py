"""Lower the pinned instruction generator's structured output into native Jac.

This is a source generator, not a C interpreter or a runtime fallback. CPython's
own analyzer and stack generator remain the authority for instruction families,
cache offsets, spills and error edges. Jac owns every branch, loop and transfer.
C adapters contain individual ABI expressions operating on typed activation
storage; they never choose an opcode or execute a handler body.

The activation's scratch union is allocated by the outer C evaluation entry.
It survives native tail transfers, retains C-stack-root addresses, and is not
copied or allocated per instruction. Its linear Jac handle owns the active
frame chain and the in-flight reference obligations in that storage. The
trusted adapters preserve the upstream slot-transfer protocol, including
transient aliases which are not independent refcount obligations.

Only the pinned, 64-bit, non-debug GIL representation is supported. Tier-two
and statistics branches remain explicit build configuration branches. Unknown
syntax fails generation; no handler is quarantined into a C fallback.

PSF-licensed instruction source: Python/bytecodes.c in CPython 3.14.6.
See jaclang/runtime/python/LICENSE.cpython.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, field
import hashlib
from io import StringIO
import json
from pathlib import Path
import re
import sys


PROTOCOL = '@foreign_call(requires=["gil"], errors="python", reentrant=True)'
PURE = '@foreign_call(requires=["gil"], errors="none", reentrant=False)'
PARAMETERS = 'storage: &JacPyVMStorage, tstate: &JacPyThreadState, vm: lin PyVMRef from (storage, tstate)'
ARGUMENTS = 'storage, tstate, vm'
GLOBAL_TYPES = {
    'frame': '_PyInterpreterFrame *',
    'stack_pointer': '_PyStackRef *',
    'tstate': 'PyThreadState *',
    'next_instr': '_Py_CODEUNIT *',
    'oparg': 'int',
    'opcode': 'int',
    'lastopcode': 'int',
    'next_uop': 'const _PyUOpInstruction *',
    'current_executor': '_PyExecutorObject *',
    'uopcode': 'uint16_t',
    'lastuop': 'int',
    'trace_uop_execution_counter': 'uint64_t',
    '_oparg': 'uint16_t', '_operand0': 'uint64_t', '_operand1': 'uint64_t', '_target': 'uint32_t',
}
# These are representation choices enforced by evaluator_refs.h, not guesses
# about optional optimizers. Native handlers always use tail-entry semantics.
FIXED_CONFIG = {
    'Py_DEBUG': False, 'Py_STACKREF_DEBUG': False, 'Py_GIL_DISABLED': False,
    'Py_TAIL_CALL_INTERP': True,
}
C_TYPES = {
    'void', 'char', 'short', 'int', 'long', 'unsigned', 'signed', 'double',
    'float', 'bool', 'size_t', 'ssize_t', 'ptrdiff_t', 'uintptr_t', 'intptr_t',
    'uint8_t', 'uint16_t', 'uint32_t', 'uint64_t', 'int8_t', 'int16_t',
    'int32_t', 'int64_t', 'binaryfunc', 'unaryfunc', 'ternaryfunc',
    'vectorcallfunc', 'inquiry', 'destructor', 'jit_func',
}
QUALIFIERS = {'const', 'volatile', 'static', 'struct', 'enum'}


def split_top(tokens, separator):
    result, part, depth = [], [], 0
    for token in tokens:
        if token.text in {'(', '[', '{'}:
            depth += 1
        elif token.text in {')', ']', '}'}:
            depth -= 1
        if token.text == separator and depth == 0:
            result.append(part)
            part = []
        else:
            part.append(token)
    result.append(part)
    return result


def text_tokens(tokens):
    # Whitespace between tokens is safe even for adjacent C string literals.
    # Tokenization has already preserved multi-character operators and strings.
    return ' '.join(t.text for t in tokens if t.kind != 'COMMENT')


@dataclass
class Slot:
    declaration: str
    guard: tuple[str, ...]


@dataclass
class Handler:
    name: str
    tier: int
    block: object
    slots: list[Slot] = field(default_factory=list)
    jac: list[str] = field(default_factory=list)
    adapters: list[str] = field(default_factory=list)
    declarations: list[str] = field(default_factory=list)
    source_operations: list[dict] = field(default_factory=list)
    jit: bool = False


class Lowerer:
    def __init__(self, handler, parser_module, lexer_module):
        self.handler = handler
        self.parsing = parser_module
        self.lexer = lexer_module
        self.scopes = [{}]
        self.guard = ('defined(_Py_TIER2)',) if handler.tier == 2 else ()
        self.indent = 1
        self.serial = 0
        self.slot_serial = 0
        self.loops = []

    def emit(self, line):
        self.handler.jac.append('    ' * self.indent + line)

    def tokens(self, source):
        return list(self.lexer.tokenize(source, filename='<native-evaluator-macro>'))

    def parse(self, source):
        return self.parsing.Parser('{' + source + '}', filename='<native-evaluator-macro>').block()

    def binding(self, name):
        for scope in reversed(self.scopes):
            if name in scope:
                return scope[name]
        return name

    def expression(self, tokens):
        result = []
        previous = None
        for token in tokens:
            if token.kind == 'COMMENT':
                continue
            value = token.text
            if token.kind == 'IDENTIFIER' and previous not in {'.', '->'}:
                value = self.binding(value)
            result.append(value)
            previous = token.text
        return ' '.join(result)

    def guarded(self, body, inactive='Py_UNREACHABLE();'):
        if not self.guard:
            return body
        condition = ' && '.join('(' + g + ')' for g in self.guard)
        return '#if ' + condition + '\n' + body + '\n#else\n' + inactive + '\n#endif'

    def adapter(self, tokens=None, *, condition=False, source=None, result=False, pure=False, scalar=False):
        self.serial += 1
        name = 'jacpy_abi_' + self.handler.name + '_' + str(self.serial)
        expression = self.expression(tokens) if source is None else source
        readable = text_tokens(tokens) if tokens is not None else expression
        readable = re.sub(r'vm->scratch\.\w+\.s\d+_(\w+)', r'\1', readable)
        for line in readable.splitlines():
            self.emit('# ' + line.strip())
        c_result = 'PyObject *' if result else 'int32_t' if condition or scalar else 'void'
        jac_result = ' -> own PyObjectRef' if result else ' -> i32' if condition or scalar else ''
        param = 'vm: lin PyVMRef from (storage, tstate), storage: &JacPyVMStorage, tstate: &JacPyThreadState' if result else 'vm: &PyVMRef'
        c_params = 'JacPyVMRef vm, JacPyVMStorage *storage, PyThreadState *owner_thread' if result else 'JacPyVMRef vm'
        if self.handler.jit:
            param = param.replace('PyVMRef', 'PyJITStepRef')
        self.handler.declarations.append(('    ' + (PURE if pure else PROTOCOL)) + '\n    def ' + name + '(' + param + ')' + jac_result + ';')
        # Macros in the pinned headers refer to these registers implicitly.
        # Reentrant operations publish the frame stack at the upstream points,
        # not indiscriminately at every adapter call.
        loads = '    JAC_VM_REGISTERS(vm);'
        stores = '    JAC_VM_SAVE_REGISTERS(vm);'
        if result:
            action = '    PyObject *jac_result = (' + expression.rstrip(';') + ');\n'
            action += '    vm->frame = NULL;\n    return jac_result;'
        elif condition or scalar:
            action = '    int32_t jac_condition = ' + ('!!' if condition else '') + '(' + expression + ');\n' + stores + '\n    return jac_condition;'
        else:
            action = '    ' + expression + '\n' + stores
        self.handler.adapters.append('__attribute__((always_inline)) ' + c_result + ' ' + name + '(' + c_params + ') {\n' + self.guarded(loads + '\n' + action) + '\n}\n')
        origin = tokens[0] if tokens else None
        self.handler.source_operations.append({
            'symbol': name, 'operation': expression, 'guard': list(self.guard),
            'kind': 'return-owner' if result else 'condition' if condition else 'expression',
            'line': origin.begin[0] if origin is not None else None,
        })
        call_args = '&vm' if not result else 'vm, storage, tstate'
        return name + '(' + call_args + ')'

    def transfer(self, destination):
        if self.handler.jit:
            if destination != 'tier2_dispatch':
                raise ValueError('unsupported JIT continuation: ' + destination)
            self.jit_finish(0)
            return
        self.emit('return __musttail(jacpy_vm_' + destination + '(' + ARGUMENTS + '));')

    def jit_finish(self, action):
        self.serial += 1
        name = 'jacpy_abi_' + self.handler.name + '_' + str(self.serial)
        self.handler.declarations.append('    ' + PURE + '\n    def ' + name +
            '(storage: &JacPyVMStorage, tstate: &JacPyThreadState, vm: lin PyJITStepRef from (storage, tstate)) -> i32;')
        self.handler.adapters.append('__attribute__((always_inline)) int32_t ' + name +
            '(JacPyVMStorage *storage, PyThreadState *tstate, JacPyVMRef vm) {\n'
            '    (void)storage; (void)tstate; (void)vm;\n    return ' + str(action) + ';\n}\n')
        label = {0: 'continue', 1: 'jump', 2: 'error', 3: 'tier-one return', 4: 'executor chain'}[action]
        self.handler.source_operations.append({'symbol': name, 'kind': 'jit-continuation', 'action': action, 'meaning': label})
        self.emit('# Publish ' + label + ' and release the one-step permission.')
        self.emit('return ' + name + '(' + ARGUMENTS + ');')

    def config(self, token):
        directive = token.text.strip()
        if directive.startswith('#ifdef '):
            condition = 'defined(' + directive.split()[1] + ')'
        elif directive.startswith('#ifndef '):
            condition = '!defined(' + directive.split()[1] + ')'
        elif directive.startswith('#if '):
            condition = directive[4:].strip()
        else:
            raise ValueError('unsupported configuration directive: ' + directive)
        condition = re.sub(r'/\*.*?\*/', '', condition).strip()
        values = dict(FIXED_CONFIG, TIER_ONE=self.handler.tier == 1, TIER_TWO=self.handler.tier == 2)
        reduced = condition
        for key, value in values.items():
            reduced = re.sub(r'\bdefined\s*\(\s*' + key + r'\s*\)', str(int(value)), reduced)
            reduced = re.sub(r'\b' + key + r'\b', str(int(value)), reduced)
        if not re.search(r'[A-Za-z_]', reduced):
            # Evaluate only this fixed boolean grammar, never arbitrary input.
            words = re.findall(r'\!|\&\&|\|\||\(|\)|[01]', reduced)
            if ''.join(words) != re.sub(r'\s', '', reduced):
                raise ValueError('unsupported fixed condition: ' + condition)
            expression = reduced.replace('&&', ' and ').replace('||', ' or ').replace('!', ' not ')
            return bool(eval(expression, {'__builtins__': {}}, {})), condition
        return None, reduced

    def config_call(self, condition):
        self.serial += 1
        name = 'jacpy_config_' + self.handler.name + '_' + str(self.serial)
        self.handler.declarations.append('    ' + PURE + '\n    def ' + name + '() -> i32;')
        self.handler.adapters.append('__attribute__((always_inline)) int32_t ' + name + '(void) {\n#if ' + condition + '\n    return 1;\n#else\n    return 0;\n#endif\n}\n')
        return name + '() != 0'

    def declare(self, tokens):
        parts = split_top(tokens, ',')
        first = parts[0]
        if not first:
            return False
        raw = [t.text for t in first]
        head = 0
        while head < len(raw) and raw[head] in QUALIFIERS:
            head += 1
        if head == len(raw):
            return False
        if 'static' in raw[:head]:
            raise ValueError('static storage needs an explicit ABI binding: ' + text_tokens(tokens))
        typename = raw[head]
        if typename not in C_TYPES and not re.fullmatch(r'(?:_?Py)[A-Za-z_0-9]+', typename):
            return False
        # A call beginning with PySomething(...) is an expression, not a type.
        if head + 1 < len(raw) and raw[head + 1] == '(':
            if head + 2 < len(raw) and raw[head + 2] == '*':
                raise ValueError('function-pointer declarator needs an ABI typedef: ' + text_tokens(tokens))
            return False
        cursor = head + 1
        while cursor < len(raw) and raw[cursor] in C_TYPES | {'const', 'volatile'}:
            cursor += 1
        if cursor == len(first) or (first[cursor].text not in {'*', 'const', 'volatile'}
                and first[cursor].kind != 'IDENTIFIER'):
            return False
        base = first[:cursor]
        declarators = [first[cursor:]] + parts[1:]
        if not declarators[0]:
            return False
        for declarator in declarators:
            pieces = split_top(declarator, '=')
            lhs = pieces[0]
            init = [token for piece in pieces[1:] for token in piece]
            if len(pieces) > 2:
                # Preserve chained assignments in an initializer.
                equal = self.tokens('=')[0]
                init = []
                for index, piece in enumerate(pieces[1:]):
                    if index:
                        init.append(equal)
                    init.extend(piece)
            ni = next((index for index, token in enumerate(lhs) if token.kind == 'IDENTIFIER' and token.text not in {'const', 'volatile'}), None)
            if ni is None or any(t.text == '(' for t in lhs[:ni]):
                raise ValueError('unsupported C declarator: ' + text_tokens(tokens))
            original = lhs[ni].text
            suffix = lhs[ni + 1:]
            if suffix and suffix[0].text != '[':
                raise ValueError('unsupported C declarator suffix: ' + text_tokens(tokens))
            if len(suffix) == 2:
                if not init or init[0].text != '{' or init[-1].text != '}':
                    raise ValueError('incomplete scratch array without a braced initializer: ' + text_tokens(tokens))
                elements = [part for part in split_top(init[1:-1], ',') if part]
                if not elements or any(part[0].text in {'[', '.'} for part in elements):
                    raise ValueError('scratch array needs a positional initializer: ' + text_tokens(tokens))
                suffix = self.tokens('[' + str(len(elements)) + ']')
            if suffix and any(t.text in GLOBAL_TYPES or self.binding(t.text) != t.text for t in suffix if t.kind == 'IDENTIFIER'):
                raise ValueError('variable scratch array: ' + text_tokens(tokens))
            # Opcode declarations from the tier-one prelude are the VM register;
            # inner opcode temporaries remain distinct C scratch places.
            if original == 'opcode' and len(self.scopes) <= 2:
                location = 'opcode'
            else:
                self.slot_serial += 1
                name = 's' + str(self.slot_serial) + '_' + original
                location = 'vm->scratch.' + self.handler.name + '.' + name
                prefix = base + lhs[:ni]
                pointer = any(t.text == '*' for t in prefix)
                last_star = max((i for i, t in enumerate(prefix) if t.text == '*'), default=-1)
                decl = ' '.join(t.text for i, t in enumerate(prefix)
                    if t.text != 'static' and not (t.text == 'const' and (not pointer or i > last_star)))
                self.handler.slots.append(Slot(decl + ' ' + name + self.expression(suffix) + ';', self.guard))
            # C declarations enter scope before evaluating their initializer.
            self.scopes[-1][original] = location
            if init:
                expr = self.expression(init)
                if suffix:
                    # Array initialization preserves stack-slot addresses; the
                    # temporary initializer's values are copied into that array.
                    element_type = text_tokens(base + lhs[:ni]).replace('static ', '')
                    action = 'memcpy(' + location + ', (' + element_type + '[] )' + expr + ', sizeof(' + location + '));'
                elif init[0].text == '{':
                    action = location + ' = (' + text_tokens(base + lhs[:ni]) + ')' + expr + ';'
                else:
                    action = location + ' = ' + expr + ';'
                self.emit(self.adapter(source=action) + ';')
        return True

    def macro(self, name, args):
        raw = [text_tokens(arg) for arg in args]
        if name in {'DISPATCH', 'DISPATCH_SAME_OPARG'}:
            if name == 'DISPATCH':
                self.emit(self.adapter(source='assert(frame->stackpointer == NULL); NEXTOPARG();') + ';')
            else:
                self.emit(self.adapter(source='opcode = next_instr->op.code;') + ';')
            self.transfer('dispatch')
        elif name == 'JUMP_TO_LABEL':
            self.transfer(raw[0])
        elif name == 'JUMP_TO_PREDICTED':
            self.emit(self.adapter(source='next_instr = ' + self.binding('this_instr') + ';') + ';')
            self.transfer('op_' + raw[0])
        elif name == 'DISPATCH_INLINED':
            expr = self.expression(args[0])
            self.emit(self.adapter(source='assert(tstate->interp->eval_frame == NULL); _PyFrame_SetStackPointer(frame, stack_pointer); assert((' + expr + ')->previous == frame); frame = tstate->current_frame = (' + expr + '); CALL_STAT_INC(inlined_py_calls);') + ';')
            self.transfer('start_frame')
        elif name == 'INSTRUMENTED_JUMP':
            src, dest, event = raw
            self.block(self.parse('''
                if (tstate->tracing) { next_instr = (''' + dest + '''); }
                else {
                    _PyFrame_SetStackPointer(frame, stack_pointer);
                    next_instr = _Py_call_instrumentation_jump(this_instr, tstate, ''' + event + ''', frame, ''' + src + ''', ''' + dest + ''');
                    stack_pointer = _PyFrame_GetStackPointer(frame);
                    if (next_instr == NULL) { next_instr = (''' + dest + ''') + 1; JUMP_TO_LABEL(error); }
                }
            '''))
        elif name == 'STACKREFS_TO_PYOBJECTS':
            source, count, var = raw
            self.simple(self.tokens('PyObject *' + var + '_temp[11];'))
            self.simple(self.tokens('PyObject **' + var + ' = _PyObjectArray_FromStackRefArray(' + source + ', ' + count + ', ' + var + '_temp + 1);'))
        elif name == 'STACKREFS_TO_PYOBJECTS_CLEANUP':
            var = raw[0]
            self.simple(self.tokens('_PyObjectArray_Free(' + var + ' - 1, ' + var + '_temp);'))
        elif name == 'LOAD_IP':
            if self.handler.tier == 1:
                self.emit(self.adapter(source='next_instr = frame->instr_ptr + (' + self.expression(args[0]) + ');') + ';')
        elif name in {'LLTRACE_RESUME_FRAME', 'PRE_DISPATCH_GOTO'}:
            # Py_DEBUG is rejected by the representation boundary.
            pass
        elif name == 'GOTO_TIER_TWO':
            executor = self.expression(args[0])
            if self.handler.jit:
                self.emit(self.adapter(source='OPT_STAT_INC(traces_executed); current_executor = (' + executor + '); tstate->current_executor = (PyObject *)current_executor;') + ';')
                self.jit_finish(4)
                return True
            self.emit(self.adapter(source='OPT_STAT_INC(traces_executed); tstate->current_executor = (PyObject *)(' + executor + ');') + ';')
            self.emit('if ' + self.config_call('defined(_Py_JIT)') + ' {')
            self.indent += 1
            old = self.guard
            self.guard += ('defined(_Py_JIT)',)
            self.emit(self.adapter(source='_PyExecutorObject *executor = (_PyExecutorObject *)tstate->current_executor; jit_func jitted = executor->jit_code; Py_INCREF(executor); next_instr = jitted(frame, stack_pointer, tstate); Py_DECREF(executor); frame = tstate->current_frame; stack_pointer = _PyFrame_GetStackPointer(frame);') + ';')
            self.emit('if ' + self.adapter(source='next_instr == NULL', condition=True) + ' != 0 {')
            self.indent += 1
            self.emit(self.adapter(source='next_instr = frame->instr_ptr + 1;') + ';')
            self.transfer('error')
            self.indent -= 1
            self.emit('}')
            self.macro('DISPATCH', [])
            self.guard = old
            self.indent -= 1
            self.emit('} else {')
            self.indent += 1
            self.guard += ('defined(_Py_TIER2) && !defined(_Py_JIT)',)
            self.emit(self.adapter(source='next_uop = ((_PyExecutorObject *)tstate->current_executor)->trace; assert(next_uop->opcode == _START_EXECUTOR); lastuop = 0; trace_uop_execution_counter = 0;') + ';')
            self.transfer('tier2_dispatch')
            self.guard = old
            self.indent -= 1
            self.emit('}')
        elif name == 'GOTO_TIER_ONE':
            if self.handler.jit:
                self.emit(self.adapter(source='tstate->current_executor = NULL; _PyFrame_SetStackPointer(frame, stack_pointer); next_instr = (' + self.expression(args[0]) + ');') + ';')
                self.jit_finish(3)
                return True
            self.emit(self.adapter(source='tstate->current_executor = NULL; next_instr = (' + self.expression(args[0]) + '); OPT_HIST(trace_uop_execution_counter, trace_run_length_hist); _PyFrame_SetStackPointer(frame, stack_pointer); stack_pointer = _PyFrame_GetStackPointer(frame);') + ';')
            self.emit('if ' + self.adapter(source='next_instr == NULL', condition=True) + ' != 0 {')
            self.indent += 1
            self.emit(self.adapter(source='next_instr = frame->instr_ptr + 1;') + ';')
            self.transfer('error')
            self.indent -= 1
            self.emit('}')
            self.macro('DISPATCH', [])
        elif name in {'JUMP_TO_JUMP_TARGET', 'JUMP_TO_ERROR'}:
            if self.handler.jit:
                self.jit_finish(1 if name == 'JUMP_TO_JUMP_TARGET' else 2)
                return True
            target = 'uop_get_jump_target' if name == 'JUMP_TO_JUMP_TARGET' else 'uop_get_error_target'
            self.emit(self.adapter(source='assert(next_uop[-1].format == UOP_FORMAT_JUMP); next_uop = current_executor->trace + ' + target + '(&next_uop[-1]);') + ';')
            self.transfer('tier2_dispatch')
        else:
            return False
        return True

    def simple(self, tokens):
        tokens = [t for t in tokens if t.kind != 'COMMENT']
        if not tokens:
            return
        if tokens[-1].text == ';':
            tokens = tokens[:-1]
        if not tokens:
            return
        if (len(tokens) in {4, 6} and [t.text for t in tokens[:3]] == ['(', 'void', ')']
                and (tokens[3].kind == 'IDENTIFIER' if len(tokens) == 4 else
                     tokens[3].text == '(' and tokens[4].kind == 'IDENTIFIER' and tokens[5].text == ')')):
            # The pinned generator emits void casts solely to silence unused
            # C-local warnings. All scratch places are fields after lowering.
            return
        if tokens[0].text in {'static_assert', '_Static_assert'}:
            self.handler.adapters.append(self.guarded(self.expression(tokens) + ';', inactive=''))
            return
        if len(tokens) >= 2 and tokens[1].text == ':':
            if not tokens[0].text.startswith('PREDICTED_'):
                raise ValueError('unsupported local label: ' + text_tokens(tokens))
            return self.simple(tokens[2:])
        if tokens[0].text == 'break':
            if self.loops:
                self.emit('break;')
            elif self.handler.tier == 2:
                self.transfer('tier2_dispatch')
            else:
                raise ValueError('break outside a native loop')
            return
        if tokens[0].text == 'continue':
            if not self.loops:
                raise ValueError('continue outside a native loop')
            increment = self.loops[-1]
            if increment:
                self.simple(increment)
            self.emit('continue;')
            return
        if tokens[0].text == 'return':
            self.emit('return ' + self.adapter(tokens[1:], result=True) + ';')
            return
        if tokens[0].text in {'goto', 'switch', 'do'}:
            raise ValueError('unlowered control flow: ' + text_tokens(tokens))
        if len(tokens) >= 3 and tokens[1].text == '(' and tokens[-1].text == ')':
            if self.macro(tokens[0].text, split_top(tokens[2:-1], ',')):
                return
        if self.declare(tokens):
            return
        if tokens[0].text.startswith('#'):
            raise ValueError('unsupported directive: ' + text_tokens(tokens))
        self.emit(self.adapter(tokens + self.tokens(';')) + ';')

    def block(self, block, new_scope=True):
        if new_scope:
            self.scopes.append({})
        self.sequence(block.body)
        if new_scope:
            self.scopes.pop()

    def sequence(self, statements):
        for statement in statements:
            self.statement(statement)
            if self.handler.jac and (self.handler.jac[-1].lstrip().startswith('return ')
                    or self.handler.jac[-1].strip() in {'break;', 'continue;'}):
                # Upstream macros such as GOTO_TIER_TWO are followed by a
                # syntactic break in some uops. The native transfer has already
                # consumed the activation; do not emit unreachable uses of it.
                break

    def statement(self, stmt):
        p = self.parsing
        if isinstance(stmt, p.BlockStmt):
            self.block(stmt)
        elif isinstance(stmt, p.SimpleStmt):
            self.simple(stmt.contents)
        elif isinstance(stmt, p.IfStmt):
            self.emit('if ' + self.adapter(stmt.condition[1:-1], condition=True) + ' != 0 {')
            self.indent += 1
            self.statement(stmt.body)
            self.indent -= 1
            if stmt.else_body is not None:
                self.emit('} else {')
                self.indent += 1
                self.statement(stmt.else_body)
                self.indent -= 1
            self.emit('}')
        elif isinstance(stmt, (p.ForStmt, p.WhileStmt)):
            self.scopes.append({})
            if isinstance(stmt, p.ForStmt):
                init, cond, increment = split_top(stmt.header[1:-1], ';')
                self.simple(init)
            else:
                cond, increment = stmt.condition[1:-1], []
            check = self.adapter(cond, condition=True) + ' != 0' if cond else 'True'
            self.emit('while ' + check + ' {')
            self.indent += 1
            self.loops.append(increment)
            self.statement(stmt.body)
            self.loops.pop()
            if increment and not (self.handler.jac[-1].lstrip().startswith('return ')
                    or self.handler.jac[-1].strip() in {'break;', 'continue;'}):
                self.simple(increment)
            self.indent -= 1
            self.emit('}')
            self.scopes.pop()
        elif isinstance(stmt, p.MacroIfStmt):
            selected, condition = self.config(stmt.condition)
            if selected is not None:
                self.sequence(stmt.body if selected else stmt.else_body or [])
                return
            self.emit('if ' + self.config_call(condition) + ' {')
            old = self.guard
            self.guard += (condition,)
            self.indent += 1
            self.sequence(stmt.body)
            self.indent -= 1
            if stmt.else_body:
                self.emit('} else {')
                self.guard = old + ('!(' + condition + ')',)
                self.indent += 1
                self.sequence(stmt.else_body)
                self.indent -= 1
            self.emit('}')
            self.guard = old
        else:
            raise ValueError('unsupported statement ' + type(stmt).__name__)

    def lower(self):
        self.block(self.handler.block)
        if self.handler.jit and (not self.handler.jac or not self.handler.jac[-1].lstrip().startswith('return ')):
            # Only explicit upstream fatal/unreachable paths can fall through.
            self.emit(self.adapter(source='Py_UNREACHABLE();') + ';')
            self.jit_finish(0)
        return self.handler


def generated_blocks(source, parsing, tier):
    parser = parsing.Parser(source, filename='tier' + str(tier) + '-stack-generator')
    result = []
    while token := parser.next():
        if tier == 1 and token.text in {'TARGET', 'LABEL'}:
            parser.require('LPAREN')
            name = parser.require('IDENTIFIER').text
            parser.require('RPAREN')
            result.append(Handler(('op_' if token.text == 'TARGET' else '') + name, tier, parser.block()))
        elif tier == 2 and token.text == 'case':
            name = parser.require('IDENTIFIER').text
            parser.require('COLON')
            result.append(Handler('uop_' + name, tier, parser.block()))
    return result


def generate(source: Path, output: Path):
    sys.path.insert(0, str(source / 'Tools/cases_generator'))
    import analyzer
    import lexer
    import parsing
    import tier1_generator
    import tier2_generator

    if not re.search(r'^#define\s+PY_VERSION\s+"3\.14\.6"$', (source / 'Include/patchlevel.h').read_text(), re.M):
        raise ValueError('native evaluator generator requires CPython 3.14.6')
    bytecodes = source / 'Python/bytecodes.c'
    analysis = analyzer.analyze_files([str(bytecodes)])
    tier1, tier2 = StringIO(), StringIO()
    tier1_generator.generate_tier1([str(bytecodes)], analysis, tier1, False)
    tier2_generator.generate_tier2([str(bytecodes)], analysis, tier2, False)
    handlers = generated_blocks(tier1.getvalue(), parsing, 1) + generated_blocks(tier2.getvalue(), parsing, 2)
    jit_handlers = generated_blocks(tier2.getvalue(), parsing, 2)
    for handler in jit_handlers:
        handler.name = handler.name.replace('uop_', 'jit_', 1)
        handler.jit = True
    handlers += jit_handlers
    for handler in handlers:
        try:
            Lowerer(handler, parsing, lexer).lower()
        except Exception as exc:
            raise RuntimeError('native evaluator source lowering failed in ' + handler.name) from exc
    output.mkdir(parents=True, exist_ok=True)
    write_sources(source, output, handlers, analysis)


def write_sources(source, output, handlers, analysis):
    jit_handlers = [handler for handler in handlers if handler.jit]
    handlers = [handler for handler in handlers if not handler.jit]
    jac = ['"""Generated from CPython 3.14.6 Python/bytecodes.c. PSF licensed.',
           'Regenerate with bootstrap/python/generate_evaluator.py; do not hand edit.',
           'C adapters are typed storage/API expressions; control flow is native Jac.',
           '"""',
           'import from jaclang.runtime.python.references { PyObjectRef, JacPyThreadState }',
           'import from jaclang.runtime.python.evaluator_activation { PyVMRef, JacPyVMStorage }',
           '', 'import from c {']
    for handler in handlers:
        jac.extend(handler.declarations)
    jac.append('}')
    for handler in handlers:
        jac += ['', PROTOCOL, 'def jacpy_vm_' + handler.name + '(' + PARAMETERS + ') -> own PyObjectRef {']
        jac.extend(handler.jac)
        if not handler.jac or not handler.jac[-1].lstrip().startswith('return '):
            jac.append('    return jacpy_vm_unreachable(vm, storage, tstate);')
        jac.append('}')
    # Exact byte values come from the pinned analyzer, never a handwritten list.
    for tier, name, opcode, prefix in [(1, 'dispatch', 'opcode', 'op_'), (2, 'tier2_dispatch', 'uopcode', 'uop_')]:
        candidates = [h for h in handlers if h.name.startswith(prefix)]
        dispatch = Handler(name, tier, None)
        lowerer = Lowerer(dispatch, __import__('parsing'), __import__('lexer'))
        if tier == 2:
            lowerer.emit(lowerer.adapter(source='uopcode = next_uop->opcode; next_uop++; OPT_STAT_INC(uops_executed); UOP_STAT_INC(uopcode, execution_count); UOP_PAIR_INC(uopcode, lastuop);') + ';')
            lowerer.emit('if ' + lowerer.config_call('defined(Py_STATS)') + ' {')
            lowerer.indent += 1
            lowerer.guard += ('defined(Py_STATS)',)
            lowerer.emit(lowerer.adapter(source='trace_uop_execution_counter++; ((_PyUOpInstruction *)next_uop)[-1].execution_count++;') + ';')
            lowerer.guard = ('defined(_Py_TIER2)',)
            lowerer.indent -= 1
            lowerer.emit('}')
        # Read the opcode once. LLVM can lower this literal match to a jump
        # table; no per-opcode C predicates or interpreted dispatch structure.
        lowerer.emit('instruction = ' + lowerer.adapter(source=opcode, scalar=True, pure=True) + ';')
        lowerer.emit('match instruction {')
        lowerer.indent += 1
        if tier == 1:
            ids = analysis.opmap
        else:
            import uop_id_generator
            buffer = StringIO()
            uop_id_generator.generate_uop_ids(['Python/bytecodes.c'], analysis, buffer, False)
            ids = dict(analysis.opmap)
            for constant, value in re.findall(r'^#define\s+(\w+)\s+(\w+)$', buffer.getvalue(), re.M):
                if value.isdigit():
                    ids[constant] = int(value)
                elif value in ids:
                    ids[constant] = ids[value]
                else:
                    raise ValueError('unresolved generated uop ID: ' + constant)
        for candidate in candidates:
            constant = candidate.name[len(prefix):]
            lowerer.emit('case ' + str(ids[constant]) + ':')
            lowerer.indent += 1
            lowerer.transfer(candidate.name)
            lowerer.indent -= 1
        lowerer.indent -= 1
        lowerer.emit('}')
        if tier == 1:
            lowerer.emit(lowerer.adapter(source='opcode = next_instr->op.code; _PyErr_Format(tstate, PyExc_SystemError, "%U:%d: unknown opcode %d", _PyFrame_GetCode(frame)->co_filename, PyUnstable_InterpreterFrame_GetLine(frame), opcode);') + ';')
            lowerer.transfer('error')
        else:
            lowerer.emit(lowerer.adapter(source='Py_FatalError("Unknown uop");') + ';')
            lowerer.emit('return jacpy_vm_unreachable(vm, storage, tstate);')
        jac += ['', 'import from c {'] + dispatch.declarations + ['}', '', PROTOCOL,
                'def jacpy_vm_' + name + '(' + PARAMETERS + ') -> own PyObjectRef {'] + dispatch.jac + ['}']
        handlers.append(dispatch)
    jac += ['', 'import from c {', '    ' + PURE,
            '    def jacpy_vm_unreachable(vm: lin PyVMRef from (storage, tstate), storage: &JacPyVMStorage, tstate: &JacPyThreadState) -> own PyObjectRef;', '}']
    (output / 'evaluator_handlers.jac').write_text('\n'.join(jac) + '\n')
    fields = ['/* Generated typed scratch storage, CPython 3.14.6; PSF licensed. */', 'union JacPyVMScratch {']
    for handler in handlers + jit_handlers:
        fields.append('    struct {')
        fields.append('        unsigned char empty;')
        for slot in handler.slots:
            if slot.guard:
                fields.append('#if ' + ' && '.join('(' + g + ')' for g in slot.guard))
            fields.append('        ' + slot.declaration)
            if slot.guard:
                fields.append('#endif')
        fields.append('    } ' + handler.name + ';')
    fields.append('};')
    (output / 'evaluator_scratch.h').write_text('\n'.join(fields) + '\n')
    for tier in (1, 2):
        c = ['/* Generated single-expression adapters; CPython 3.14.6, PSF licensed. */',
             '#include "evaluator_activation.h"', '#include "evaluator_operations.h"']
        if tier == 2:
            c += ['#undef LOAD_IP', '#define LOAD_IP(UNUSED) ((void)0)',
                  '#undef STAT_INC', '#define STAT_INC(opname, name) ((void)0)',
                  '#undef STAT_DEC', '#define STAT_DEC(opname, name) ((void)0)',
                  '#undef ENABLE_SPECIALIZATION', '#define ENABLE_SPECIALIZATION 0',
                  '#undef ENABLE_SPECIALIZATION_FT', '#define ENABLE_SPECIALIZATION_FT 0']
        for handler in handlers:
            if handler.tier == tier:
                c.extend(handler.adapters)
        (output / ('evaluator_tier' + str(tier) + '_abi.c')).write_text('\n'.join(c) + '\n')
    # JIT bodies consume a one-step permission and return an ABI continuation.
    # The C patch-point trampoline resumes only after the native body returns.
    jit_jac = ['"""Generated native JIT uop policies; CPython 3.14.6, PSF licensed."""',
        'import from jaclang.runtime.python.references { JacPyThreadState }',
        'import from jaclang.runtime.python.evaluator_activation { PyJITStepRef, JacPyVMStorage }',
        'import from c {']
    for handler in jit_handlers:
        jit_jac.extend(handler.declarations)
    jit_jac.append('}')
    jit_c = ['/* Generated JIT ABI expressions, CPython 3.14.6; PSF licensed. */',
        '#include "evaluator_activation.h"',
        '#undef CURRENT_OPARG', '#define CURRENT_OPARG() (_oparg)',
        '#undef CURRENT_OPERAND0', '#define CURRENT_OPERAND0() (_operand0)',
        '#undef CURRENT_OPERAND1', '#define CURRENT_OPERAND1() (_operand1)',
        '#undef CURRENT_TARGET', '#define CURRENT_TARGET() (_target)']
    for handler in jit_handlers:
        jit_jac += ['', PROTOCOL, 'def jacpy_vm_' + handler.name + '(' +
            PARAMETERS.replace('PyVMRef', 'PyJITStepRef') + ') -> i32 {'] + handler.jac + ['}']
        jit_c.append('#if _JIT_OPCODE == ' + handler.name[len('jit_'):])
        jit_c.extend(handler.adapters)
        jit_c.append('#endif')
    (output / 'evaluator_jit.jac').write_text('\n'.join(jit_jac) + '\n')
    (output / 'evaluator_jit_abi.c').write_text('\n'.join(jit_c) + '\n')
    inputs = sorted((source / 'Tools/cases_generator').glob('*.py')) + [source / 'Python/bytecodes.c']
    manifest = {
        'schema': 1, 'cpython': '3.14.6',
        'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'inputs': {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
        'handlers': {h.name: {'tier': h.tier, 'jit': h.jit, 'operations': h.source_operations} for h in handlers + jit_handlers},
        'instruction_definitions': sorted(analysis.instructions),
        'families': sorted(analysis.families),
        'configuration': FIXED_CONFIG,
        'ownership': 'linear activation aggregate with trusted typed slot-transfer adapters',
        'native_exports': ['jacpy_vm_' + h.name for h in handlers],
        'jit_exports': {h.name[len('jit_'):]: 'jacpy_vm_' + h.name for h in jit_handlers},
        'outputs': {name: hashlib.sha256((output / name).read_bytes()).hexdigest() for name in [
            'evaluator_handlers.jac', 'evaluator_jit.jac', 'evaluator_scratch.h', 'evaluator_tier1_abi.c', 'evaluator_tier2_abi.c', 'evaluator_jit_abi.c',
        ]},
        'validation': 'not performed by source generation',
    }
    (output / 'evaluator-generation.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='unmodified pinned CPython source tree')
    parser.add_argument('output', type=Path, help='generated source destination')
    arguments = parser.parse_args()
    generate(arguments.source.resolve(), arguments.output.resolve())
