import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0 { compile_jac }

glob FIXTURES = os.path.join(
    str(Path(jaclang.__file__).parent.parent), "tests", "compiler", "fixtures"
);

test "jac0 orphan impl is not emitted" {
    main_src = open(os.path.join(FIXTURES, "jac0_orphan_impl.jac")).read();
    impl_src = open(os.path.join(FIXTURES, "jac0_orphan_impl.impl.jac")).read();
    result = compile_jac(
        main_src,
        "jac0_orphan_impl.jac",
        impl_sources=[(impl_src, "jac0_orphan_impl.impl.jac")]
    );
    assert "make_fake" not in result;
}

test "jac0 valid impl is not duplicated" {
    main_src = open(os.path.join(FIXTURES, "jac0_orphan_impl.jac")).read();
    impl_src = open(os.path.join(FIXTURES, "jac0_orphan_impl.impl.jac")).read();
    result = compile_jac(
        main_src,
        "jac0_orphan_impl.jac",
        impl_sources=[(impl_src, "jac0_orphan_impl.impl.jac")]
    );
    assert result.count("def make") == 1;
}
