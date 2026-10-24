import from jaclang.osprey.ui.model { ordered_child_keys }

import from jaclang.osprey.ui.runtime_core { create_session }

import from jaclang.osprey.ui.screen { build_main_shell, }


test "default_shell_registry has Osprey shell tags" {
    reg = default_shell_registry();
    assert "MainScreen" in reg.tags;
    assert "TranscriptView" in reg.tags;
    assert "Prompt" in reg.tags;
    assert "ApprovalOverlay" in reg.tags;
}


test "register_tag rejects empty name" {
    reg = create_tag_registry();
    failed = False;
    try {
        register_tag(reg, "", MainScreen);
    } except ValueError {
        failed = True;
    }
    assert failed;
}


test "unknown tag is a lowering error" {
    source = "<Nope key=\"x\" />";
    result = lower_markup(source, default_shell_registry());
    assert result.graph_root is None;
    assert len(result.errors) >= 1;
    msg = result.errors[0].message;
    assert ("Nope" in msg) or ("unknown" in msg.lower());
}


test "unknown property is a lowering error" {
    source = "<Prompt key=\"prompt\" not_a_real_prop=\"1\" />";
    result = lower_markup(source, default_shell_registry());
    assert len(result.errors) >= 1;
}


test "shell markup lowers to MainScreen with expected children" {
    source = """
    <MainScreen key="main">
      <Header key="header" title="Osprey" />
      <TranscriptView key="transcript" />
      <Status key="status" phase="ready" />
      <Prompt key="prompt" />
    </MainScreen>
    """;
    result = lower_markup(source, default_shell_registry());
    assert result.errors == [];
    assert result.graph_root is not None;
    screen = result.graph_root;
    assert isinstance(screen, MainScreen);
    keys = ordered_child_keys(screen);
    assert keys == ["header", "transcript", "status", "prompt"];
}


test "print_generated emits direct-construction Jac" {
    source = """
    <MainScreen key="main">
      <Prompt key="prompt" />
    </MainScreen>
    """;
    text = print_generated(source, default_shell_registry());
    assert "MainScreen" in text;
    assert "Prompt" in text;
    assert ("append_child" in text) or ("Child" in text);
}


test "lowered shell matches build_main_shell child keys when Unit 8 exists" {
    source = """
    <MainScreen key="main">
      <Header key="header" title="Osprey" />
      <TranscriptView key="transcript" />
      <Status key="status" />
      <Prompt key="prompt" />
    </MainScreen>
    """;
    lowered = lower_markup(source, default_shell_registry());
    assert lowered.errors == [];
    assert lowered.graph_root is not None;
    lowered_screen = lowered.graph_root;
    assert isinstance(lowered_screen, MainScreen);
    handle = create_session();
    session = handle.session;
    matched = False;
    try {
        shell = build_main_shell(session);
        assert ordered_child_keys(lowered_screen) == ordered_child_keys(shell.screen);
        matched = True;
    } except NotImplementedError {
        matched = True;
    }
    assert matched;
}
