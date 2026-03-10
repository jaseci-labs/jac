"""MTIR generation pass tests – migrated from test_mtir_gen_pass.py."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang { JacRuntime as Jac }
import from jaclang.jac0core.mtp { ClassInfo, FunctionInfo, MethodInfo }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent),
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures"
     );

test "mtir gen basic" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "mtir_gen.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    assert Jac.program is not None;
    mtir_map = Jac.program.mtir_map;
    assert mtir_map , "MTIR map should not be empty";
    scopes = list(mtir_map.keys());
    assert len(scopes) > 0 , "Should have at least one MTIR entry";
}

test "mtir gen standalone function" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "mtir_gen.jac"));
    assert not prog.errors_had;
    assert Jac.program is not None;
    mtir_map = Jac.program.mtir_map;
    analyze_person_scope = None;
    for scope in mtir_map {
        if "analyze_person" in scope {
            analyze_person_scope = scope;
            break;
        }
    }
    assert analyze_person_scope is not None , "analyze_person should be in mtir_map";
    func_info = mtir_map[analyze_person_scope];
    assert isinstance(func_info, FunctionInfo);
    assert func_info.name == "analyze_person";
    assert func_info.params is not None;
    assert len(func_info.params) == 2;
    param_names = [p.name for p in func_info.params];
    assert "person" in param_names;
    assert "detail_level" in param_names;
    assert func_info.return_type == "str";
}

test "mtir gen method" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "mtir_gen.jac"));
    assert not prog.errors_had;
    assert Jac.program is not None;
    mtir_map = Jac.program.mtir_map;
    summarize_scope = None;
    for scope in mtir_map {
        if "summarize" in scope {
            summarize_scope = scope;
            break;
        }
    }
    assert summarize_scope is not None , "Project.summarize should be in mtir_map";
    method_info = mtir_map[summarize_scope];
    assert isinstance(method_info, MethodInfo);
    assert method_info.name == "summarize";
    assert method_info.params is not None;
    param_names = [p.name for p in method_info.params];
    assert "query" in param_names;
    assert method_info.parent_class is not None;
    assert isinstance(method_info.parent_class, ClassInfo);
    assert method_info.parent_class.name == "Project";
}

test "mtir gen complex return type" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "mtir_gen.jac"));
    assert not prog.errors_had;
    assert Jac.program is not None;
    mtir_map = Jac.program.mtir_map;
    create_team_scope = None;
    for scope in mtir_map {
        if "create_team" in scope {
            create_team_scope = scope;
            break;
        }
    }
    assert create_team_scope is not None , "create_team should be in mtir_map";
    func_info = mtir_map[create_team_scope];
    assert isinstance(func_info, FunctionInfo);
    assert func_info.return_type is not None;
    if isinstance(func_info.return_type, ClassInfo) {
        assert func_info.return_type.name == "Team";
    } elif isinstance(func_info.return_type, str) {
        assert func_info.return_type == "Team";
    }
}

test "mtir gen list return type" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "mtir_gen.jac"));
    assert not prog.errors_had;
    assert Jac.program is not None;
    mtir_map = Jac.program.mtir_map;
    find_people_scope = None;
    for scope in mtir_map {
        if "find_people" in scope {
            find_people_scope = scope;
            break;
        }
    }
    assert find_people_scope is not None , "find_people should be in mtir_map";
    func_info = mtir_map[find_people_scope];
    assert isinstance(func_info, FunctionInfo);
    assert func_info.return_type is not None;
    if isinstance(func_info.return_type, tuple) {
        assert func_info.return_type[0] == "list";
    }
}

test "mtir gen semstrings" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "mtir_gen.jac"));
    assert not prog.errors_had;
    assert Jac.program is not None;
    mtir_map = Jac.program.mtir_map;
    analyze_person_scope = None;
    for scope in mtir_map {
        if "analyze_person" in scope {
            analyze_person_scope = scope;
            break;
        }
    }
    assert analyze_person_scope is not None;
    func_info = mtir_map[analyze_person_scope];
    assert isinstance(func_info, FunctionInfo);
    assert func_info.semstr is not None;
    assert "Analyze" in func_info.semstr;
    assert func_info.params is not None;
    person_param = None;
    for p in func_info.params {
        if p.name == "person" {
            person_param = p;
            break;
        }
    }
    if person_param and person_param.semstr {
        assert "person" in person_param.semstr.lower();
    }
}

test "mtir gen class info extraction" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "mtir_gen.jac"));
    assert not prog.errors_had;
    assert Jac.program is not None;
    mtir_map = Jac.program.mtir_map;
    analyze_person_scope = None;
    for scope in mtir_map {
        if "analyze_person" in scope {
            analyze_person_scope = scope;
            break;
        }
    }
    assert analyze_person_scope is not None;
    func_info = mtir_map[analyze_person_scope];
    assert isinstance(func_info, FunctionInfo);
    assert func_info.params is not None;
    person_param = None;
    for p in func_info.params {
        if p.name == "person" {
            person_param = p;
            break;
        }
    }
    assert person_param is not None;
    if isinstance(person_param.type_info, ClassInfo) {
        assert person_param.type_info.name == "Person";
        field_names = [f.name for f in person_param.type_info.fields];
        assert "name" in field_names;
        assert "age" in field_names;
    }
}

test "mtir gen all genai abilities captured" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "mtir_gen.jac"));
    assert not prog.errors_had;
    assert Jac.program is not None;
    mtir_map = Jac.program.mtir_map;
    expected_abilities = ["summarize", "analyze_person", "create_team", "find_people"];
    found_abilities: set = set();
    for scope in mtir_map {
        for ability in expected_abilities {
            if ability in scope {
                found_abilities.add(ability);
            }
        }
    }
    assert len(found_abilities) == len(expected_abilities) , f"Expected all GenAI abilities to be captured. Found: {found_abilities}, Expected: {set(
        expected_abilities
    )}";
}
