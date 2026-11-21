"""Client module that pulls both the lowerable and the unlowerable helper."""

import from infer_unlowerable_util { scale_by, shape_of }

def:pub app -> JsxElement {
    return <div>{str(scale_by(2.0))}{shape_of([1])}</div>;
}
