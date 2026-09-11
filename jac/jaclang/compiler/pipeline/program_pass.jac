import type from jaclang.compiler.session.services { AnalysisServices }
import from jaclang.compiler.pipeline.pass_base { Transform }

walker ProgramTransform(Transform) {
    has prog: AnalysisServices;
}

walker QueryTransform[T](ProgramTransform) {
    has result: T postinit;

    def postinit -> None {
        super.postinit();
    }
}
