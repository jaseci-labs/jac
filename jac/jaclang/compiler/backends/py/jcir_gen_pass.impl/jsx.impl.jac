impl JcirGenPass.exit_jsx_element with JsxElement exit {
    tag_arg: CgNode;
    if here.dynamic_tag is not None {
        tag_arg = self.val(here.dynamic_tag);
    } elif (here.is_fragment or not here.name) {
        tag_arg = self.const_of(None, jac_node=here);
    } else {
        tag_arg = self.val(here.name);
    }
    attrs_expr: CgNode;
    if not here.attributes {
        attrs_expr = self.nod('Dict', ['keys', 'values'], [[], []], jac_node=here);
    } elif any(isinstance(attr, JsxSpreadAttribute) for attr in here.attributes) {
        attrs_expr = self.nod('Dict', ['keys', 'values'], [[], []], jac_node=here);
        for attr in here.attributes {
            if isinstance(attr, JsxSpreadAttribute) {
                attrs_expr = self.nod(
                    'Dict',
                    ['keys', 'values'],
                    [[None, None], [attrs_expr, self.val(attr)]],
                    jac_node=attr
                );
            } elif isinstance(attr, JsxNormalAttribute) {
                attr_tuple = self.val(attr);
                attrs_expr = self.nod(
                    'Dict',
                    ['keys', 'values'],
                    [
                        [None, attr_tuple.get('elts')[0]],
                        [attrs_expr, attr_tuple.get('elts')[1]]
                    ],
                    jac_node=attr
                );
            }
        }
    } else {
        dkeys: list = [];
        dvalues: list = [];
        for attr in here.attributes {
            if isinstance(attr, JsxNormalAttribute) {
                attr_tuple = self.val(attr);
                dkeys.append(attr_tuple.get('elts')[0]);
                dvalues.append(attr_tuple.get('elts')[1]);
            }
        }
        attrs_expr = self.nod(
            'Dict', ['keys', 'values'], [dkeys, dvalues], jac_node=here
        );
    }
    children_arg: CgNode;
    if here.children {
        kept_children = [
            c
            for c in here.children
            if not isinstance(c, JsxComment)
                and not (isinstance(c, JsxText) and not c.get_normalized_text())
        ];
        children_arg = self.nod(
            'List',
            ['elts', 'ctx'],
            [
                [self.val(c) for c in kept_children],
                self.nod('Load', [], [], jac_node=here)
            ],
            jac_node=here
        );
    } else {
        children_arg = self.nod(
            'List',
            ['elts', 'ctx'],
            [[], self.nod('Load', [], [], jac_node=here)],
            jac_node=here
        );
    }
    self.set_out(
        here,
        [
            self.call_node(
                self.jaclib_obj('jsx'),
                [tag_arg, attrs_expr, children_arg],
                [],
                jac_node=here
            )
        ]
    );
}

impl JcirGenPass.exit_jsx_element_name with JsxElementName exit {
    name_str = '.'.join(part.value for part in here.parts);
    if (here.parts and here.parts[0].value[0].isupper()) {
        self.set_out(here, [self.name_load(name_str, jac_node=here)]);
    } else {
        self.set_out(here, [self.const_of(name_str, jac_node=here)]);
    }
}

impl JcirGenPass.exit_jsx_spread_attribute with JsxSpreadAttribute exit {
    self.set_out(here, [self.val(here.expr)]);
}

impl JcirGenPass.exit_jsx_normal_attribute with JsxNormalAttribute exit {
    if not here.name {
        self.set_out(here, []);
        return;
    }
    key_ast = self.const_of(here.name.value, jac_node=here.name);
    value_ast: CgNode;
    if (here.value and isinstance(here.value, String)) {
        import from html { unescape }
        literal = literal_string_value(here.value);
        assert literal is not None;
        value_ast = self.const_of(unescape(literal), jac_node=here.value);
    } elif (here.value and self.outs(here.value)) {
        value_ast = self.val(here.value);
    } else {
        value_ast = self.const_of(True, jac_node=here);
    }
    self.set_out(
        here,
        [
            self.nod(
                'Tuple',
                ['elts', 'ctx'],
                [[key_ast, value_ast], self.nod('Load', [], [], jac_node=here)],
                jac_node=here
            )
        ]
    );
}

impl JcirGenPass.exit_jsx_text with JsxText exit {
    import from html { unescape }
    self.set_out(
        here, [self.const_of(unescape(here.get_normalized_text()), jac_node=here)]
    );
}

impl JcirGenPass.exit_jsx_expression with JsxExpression exit {
    self.set_out(here, [self.val(here.expr)]);
}

impl JcirGenPass.exit_jsx_slot with JsxSlot exit {
    self.set_out(here, [self.const_of(None, jac_node=here)]);
}

impl JcirGenPass.exit_jsx_comment with JsxComment exit {
    self.set_out(here, []);
}
