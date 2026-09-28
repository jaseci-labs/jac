"""C pointer interop: foreign structs, borrows to C, `ptr[T]`, views and pins.

`test_native_clib_pointers.jac` builds `clib_pointers.c` into a shared library,
substitutes its path for CLIB_POINTERS_LIBRARY and runs this program under every
native memory profile and on the Python backend; the outputs must agree.
"""

import from "CLIB_POINTERS_LIBRARY" {
    obj CpVec3 {
        has x: f32,
            y: f32,
            z: f32;
    }  obj CpCamera {
        has position: CpVec3,
            target: CpVec3,
            fovy: f32,
            mode: i32;
    }  obj CpDb;  obj CpBatch {
        has draws: i32,
            last: i32,
            vbo: ptr,
            tint: CpVec3;
    }  obj CpPointList {
        has count: i32,
            items: ptr[CpVec3];
    }  def cp_camera_init(cam: &mut CpCamera, fovy: f32) -> None;  def cp_camera_orbit(
        cam: &mut CpCamera, dx: f32
    ) -> None;  def cp_camera_span(cam: &CpCamera) -> f32;  def cp_camera_sum(
        cam: CpCamera
    ) -> f32;  def cp_camera_make(fovy: f32) -> CpCamera;  def cp_window_size(
        w: &mut i32, h: &mut i32
    ) -> None;  def cp_bump(
        v: &mut i64, d: &mut f64, b: &mut u8, flag: &mut bool
    ) -> None;  def cp_buffer_new(n: i32) -> ptr[u8];  def cp_buffer_sum(
        buf: ptr[u8], n: i32
    ) -> i32;  def cp_buffer_free(buf: ptr[u8]) -> None;  def cp_points_new(
        n: i32
    ) -> ptr[CpVec3];  def cp_points_sum(pts: ptr[CpVec3], n: i32) -> f32;  def cp_points_sort(
        pts: ptr[CpVec3], n: i32, before: Callable[[ptr[CpVec3], ptr[CpVec3]], i32]
    ) -> None;  def cp_points_free(pts: ptr[CpVec3]) -> None;  def cp_find(
        key: i32
    ) -> ptr[CpVec3];  def cp_db_open(name: str, out: &mut ptr[CpDb]) -> i32;  def cp_db_put(
        db: ptr[CpDb], v: i32
    ) -> i32;  def cp_db_total(db: ptr[CpDb]) -> i32;  def cp_db_close(
        db: ptr[CpDb]
    ) -> None;  def cp_batch_set_active(batch: &mut Pinned[CpBatch] | None) -> None;  def cp_batch_is_active -> bool;  def cp_batch_draw(
        v: i32
    ) -> i32;  def cp_counter_retain(counter: &mut Pinned[i32] | None) -> None;  def cp_counter_tick -> None;  def cp_maybe_count(out: &mut i64 | None) -> i32;  def cp_pointlist_fill(
        pl: &mut CpPointList, n: i32
    ) -> None;  def cp_global_read -> i32;  glob cp_global_count: i32,
         cp_global_flag: bool,
         cp_global_origin: CpVec3,
         cp_global_origin_ref: ptr[CpVec3]; obj CpRecipe {
        has count: i32,
            scale: Callable[[i32], i32],
            label: ptr[u8],
            origin: ptr[CpVec3];
    }  def cp_recipe_run(r: ptr[CpRecipe], v: i32) -> i32;  def cp_label_len(
        s: ptr[u8]
    ) -> i32;  glob cp_jac_origin: CpVec3 = CpVec3(
             x=f32(4.0), y=f32(5.0), z=f32(6.0)
         ),
         cp_jac_recipe: CpRecipe = CpRecipe(
             count=i32(3),
             scale=triple,
             label=ptr[u8]("recipe"),
             origin=addressof(cp_jac_origin)
         ),
         cp_jac_limit: i64 = 99,
         cp_jac_points: list[CpVec3] = [
             CpVec3(x=f32(1.0), y=f32(2.0), z=f32(3.0)),
             CpVec3(x=f32(10.0))
         ],
         cp_jac_bytes: list[u8] = [u8(7), u8(8), u8(9)];
}

obj Session {
    has db: ptr[CpDb] = ptr[CpDb](),
        opened: list[ptr[CpDb]] = [];
}

obj Renderer {
    has batch: own Pinned[CpBatch];

    def activate {
        cp_batch_set_active(&mut self.batch);
    }
}

"""Out-parameters, in-place mutation and a read-only borrow of a struct."""
def camera_demo {
    cam = CpCamera();
    cp_camera_init(&mut cam, f32(45.0));
    print("init", cam.position.y, cam.position.z, cam.fovy, cam.mode);
    cp_camera_orbit(&mut cam, f32(1.5));
    print("orbit", cam.position.x, cam.target.y, cam.mode);
    print("span", cp_camera_span(&cam));
    print("by value", cp_camera_sum(cam));
    made = cp_camera_make(f32(30.0));
    print("returned", made.position.z, made.fovy);
}

"""A nested struct is part of its parent's bytes: reads copy, writes go in place."""
def layout_demo {
    cam = cp_camera_make(f32(60.0));
    pos = cam.position;
    pos.x = f32(100.0);
    print("copy", cam.position.x, pos.x);
    cam.target = cam.position;
    print("store", cam.target.x, cam.target.y, cam.target.z);
    cam.position.z += f32(1.0);
    cam.target.x = f32(-2.5);
    print("in place", cam.position.z, cam.target.x, cp_camera_span(&cam));
}

"""Scalar out-parameters: C writes land in the Jac locals."""
def scalar_demo {
    w: i32 = i32(0);
    h: i32 = i32(0);
    cp_window_size(&mut w, &mut h);
    print("window", w, h);
    v: i64 = i64(41);
    d: f64 = f64(1.25);
    b: u8 = u8(7);
    flag = False;
    cp_bump(&mut v, &mut d, &mut b, &mut flag);
    print("bump", v, d, b, flag);
}

"""A C-owned byte buffer read and written through a bounds-checked view."""
def buffer_demo {
    buf = cp_buffer_new(i32(6));
    print("buffer null", buf.is_null());
    data = buf.view(6);
    print("buffer", len(data), data[0], data[5], data[-1]);
    data[2] = u8(200);
    data[1] += u8(1);
    print("buffer sum", cp_buffer_sum(buf, i32(6)));
    try {
        print(data[6]);
    } except IndexError as e {
        print("buffer index", e);
    }
    try {
        print(data[-7]);
    } except IndexError as e {
        print("buffer index", e);
    }
    cp_buffer_free(buf);
}

"""A callback C calls with pointers into its own array."""
def larger_x(a: ptr[CpVec3], b: ptr[CpVec3]) -> i32 {
    return i32(1) if a.view(1)[0].x > b.view(1)[0].x else i32(0);
}

"""A C array of structs: element reads copy, element places write through."""
def points_demo {
    pts = cp_points_new(i32(4));
    view = pts.view(4);
    first = view[1];
    first.x = f32(50.0);
    print("point copy", view[1].x, first.x);
    view[2].y = f32(10.0);
    view[3] = first;
    print("point sum", cp_points_sum(pts, i32(4)));
    cp_points_sort(pts, i32(4), larger_x);
    print("sorted", view[0].x, view[1].x, view[2].x, view[3].x);
    cp_points_free(pts);
}

"""Null pointers, pointer equality and the void* cast."""
def pointer_demo {
    missing = cp_find(i32(1));
    found = cp_find(i32(42));
    print("find", missing.is_null(), found.is_null(), found.view(1)[0].z);
    print("equal", found == cp_find(i32(42)), found == missing, found != missing);
    print("truth", bool(found), bool(missing));
    erased: ptr = found;
    back = ptr[CpVec3](erased);
    print("cast", back.view(1)[0].x);
    try {
        missing.view(1);
    } except ValueError as e {
        print("null view", e);
    }
    print("empty view", len(missing.view(0)));
}

"""An opaque handle produced by an out-parameter and kept in a Jac object."""
def db_demo {
    db = ptr[CpDb]();
    print("fresh", db.is_null());
    rc = cp_db_open("scores", &mut db);
    print("open", rc, db.is_null());
    cp_db_put(db, i32(5));
    print("put", cp_db_put(db, i32(7)), cp_db_total(db));
    session = Session();
    session.db = db;
    session.opened.append(db);
    print("session", session.db == db, session.opened[0] == db, len(session.opened));
    cp_db_close(session.db);
    bad = ptr[CpDb]();
    print("open empty", cp_db_open("", &mut bad), bad.is_null());
}

"""C keeps the pinned payload's address between calls."""
def batch_demo {
    fresh = pin(CpBatch());
    batch = fresh;
    cp_batch_set_active(&mut batch);
    print("active", cp_batch_is_active());
    cp_batch_draw(i32(3));
    cp_batch_draw(i32(9));
    print("batch", batch.value.draws, batch.value.last, batch.value.tint.x);
    batch.value.draws = i32(100);
    print("draw", cp_batch_draw(i32(1)), batch.value.draws);
    cp_batch_set_active(None);
    print("inactive", cp_batch_is_active(), cp_batch_draw(i32(5)));
}

"""A pinned scalar retained by C, read and written through `.value`."""
def counter_demo {
    counter = pin(i32(1));
    cp_counter_retain(&mut counter);
    cp_counter_tick();
    cp_counter_tick();
    print("counter", counter.value);
    counter.value = i32(5);
    cp_counter_tick();
    print("counter", counter.value);
    cp_counter_retain(None);
}

"""An optional scalar out-parameter: None passes NULL."""
def optional_out_demo {
    count: i64 = i64(0);
    print("optional none", cp_maybe_count(None));
    written = cp_maybe_count(&mut count);
    print("optional out", written, count);
}

"""A pin owned by a Jac object, registered from a method."""
def renderer_demo {
    renderer = Renderer(batch=pin(CpBatch()));
    renderer.activate();
    cp_batch_draw(i32(7));
    cp_batch_draw(i32(8));
    print("renderer", renderer.batch.value.draws, renderer.batch.value.last);
    cp_batch_set_active(None);
}

"""C pointer arithmetic: element steps, distances and integer addresses."""
def arithmetic_demo {
    pts = cp_points_new(i32(4));
    third = pts + 2;
    print("step", third.view(1)[0].x, (third - 1).view(1)[0].y);
    print("distance", third - pts, pts - third);
    cursor = pts;
    cursor += 3;
    cursor -= 1;
    print("aug", cursor == third, cursor.view(1)[0].x);
    print("bytes", ptr[u8](third) - ptr[u8](pts));
    address = int(third);
    print("address", ptr[CpVec3](address) == third, address - int(pts));
    erased = ptr(pts);
    print("void step", int(erased + 24) == address);
    cp_points_free(pts);
    buf = cp_buffer_new(i32(6));
    print("byte", (buf + 5).view(1)[0]);
    cp_buffer_free(buf);
}

"""Variables the C library defines: read and written in place, or by address."""
def globals_demo {
    print("global", cp_global_count, cp_global_flag);
    cp_global_count = i32(11);
    cp_global_count += i32(1);
    print("global write", cp_global_read());
    origin = addressof(cp_global_origin);
    print("global object", origin == cp_global_origin_ref, origin.view(1)[0].y);
    origin.view(1)[0].z = f32(9.0);
    print("global place", cp_global_origin_ref.view(1)[0].z);
    count = addressof(cp_global_count);
    count.view(1)[0] = i32(40);
    print("global address", cp_global_count);
    cp_global_flag = False;
    print("global flag", cp_global_flag);
}

def triple(v: i32) -> i32 {
    return v * i32(3);
}

"""C data Jac defines: C-layout storage with a constant initializer."""
def definitions_demo {
    recipe = addressof(cp_jac_recipe);
    fields = recipe.view(1)[0];
    print(
        "defined",
        cp_recipe_run(recipe, i32(5)),
        cp_label_len(fields.label),
        fields.origin.view(1)[0].y
    );
    cp_jac_limit += 1;
    print("defined scalar", cp_jac_limit, cp_label_len(ptr[u8]("hello")));
    points = addressof(cp_jac_points);
    print(
        "defined array",
        cp_points_sum(points, i32(2)),
        (points + 1).view(1)[0].x,
        cp_buffer_sum(addressof(cp_jac_bytes), i32(3))
    );
}

"""A struct holding a pointer that C fills in."""
def pointer_field_demo {
    pl = CpPointList();
    cp_pointlist_fill(&mut pl, i32(3));
    print("list", pl.count, pl.items.view(3)[2].y);
    cp_points_free(pl.items);
}

with entry {
    camera_demo();
    layout_demo();
    scalar_demo();
    buffer_demo();
    points_demo();
    pointer_demo();
    db_demo();
    batch_demo();
    counter_demo();
    optional_out_demo();
    renderer_demo();
    pointer_field_demo();
    arithmetic_demo();
    globals_demo();
    definitions_demo();
}
