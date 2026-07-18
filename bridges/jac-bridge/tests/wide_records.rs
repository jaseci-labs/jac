//! Blob record-table shape for nested-record / container / enum typed records
//! (2.9-followup). The macro collects every `#[jac_record]` struct/enum and emits a
//! RecordDesc (+ FieldDesc list) into the `.jac_bridge` blob. This test drives that
//! emission from a real bridge module and parses the blob back, asserting each
//! record's kind and every field/variant TAG — the exact contract the na and ctypes
//! loaders read. Nested/container field tags reuse the frozen ABI-v1 bits
//! (TAG_WIDE|id, TAG_LIST_BIT, TAG_OPT_BIT), so no new wire tag is minted.

use jac_bridge::bridge;
use jac_bridge_schema as sch;

#[bridge(module = "rectest")]
mod b {
    use serde::{Deserialize, Serialize};

    // Order fixes the 1-based record ids: Point=1, Region=2, Path=3, Shape=4.
    #[derive(Serialize, Deserialize)]
    #[jac_record]
    pub struct Point {
        pub x: i64,
        pub y: i64,
    }

    // Nested records: both fields are another typed record.
    #[derive(Serialize, Deserialize)]
    #[jac_record]
    pub struct Region {
        pub tl: Point,
        pub br: Point,
    }

    // Containers: a list of nested records + an optional scalar.
    #[derive(Serialize, Deserialize)]
    #[jac_record]
    pub struct Path {
        pub pts: Vec<Point>,
        pub name: Option<String>,
    }

    // An enum: a unit variant, a newtype scalar variant, and a newtype
    // nested-record variant.
    #[derive(Serialize, Deserialize)]
    #[jac_record]
    pub enum Shape {
        Dot,
        Circle(f64),
        At(Point),
    }

    #[jac_error]
    pub struct RecErr;

    pub struct Calc;

    impl Calc {
        pub fn new() -> Self {
            Calc
        }
        // A wide method keeps the module a "wide bridge" (pulls in serde/rmp) and
        // exercises a nested-record wide param + return.
        pub fn grow(&self, r: Wide<Region>) -> Wide<Region> {
            r
        }
    }
}

// ── minimal blob reader (mirrors _blob.jac; enough for the record table) ─────────

fn u32_at(blob: &[u8], o: usize) -> u32 {
    u32::from_le_bytes(blob[o..o + 4].try_into().unwrap())
}

/// Read a StrRef (abs u32 offset + u32 len) at `o` into a String.
fn str_at(blob: &[u8], o: usize) -> String {
    let off = u32_at(blob, o) as usize;
    let len = u32_at(blob, o + 4) as usize;
    String::from_utf8(blob[off..off + len].to_vec()).unwrap()
}

struct Rec {
    kind: u32,
    fields: Vec<(String, u32)>, // (name, tag)
}

fn parse_records(blob: &[u8]) -> std::collections::BTreeMap<String, Rec> {
    let rec_off = u32_at(blob, 32) as usize;
    let rec_cnt = u32_at(blob, 36) as usize;
    let mut out = std::collections::BTreeMap::new();
    let mut off = rec_off;
    for _ in 0..rec_cnt {
        let dsz = u32_at(blob, off) as usize;
        assert!(dsz >= 24, "RecordDesc should be >= 24 bytes now, got {dsz}");
        let name = str_at(blob, off + 4);
        let fld_off = u32_at(blob, off + 12) as usize;
        let fld_cnt = u32_at(blob, off + 16) as usize;
        let kind = u32_at(blob, off + 20);
        let mut fields = Vec::new();
        let mut foff = fld_off;
        for _ in 0..fld_cnt {
            let fname = str_at(blob, foff);
            let ftag = u32_at(blob, foff + 8);
            fields.push((fname, ftag));
            foff += 12;
        }
        out.insert(name, Rec { kind, fields });
        off += dsz;
    }
    out
}

#[test]
fn record_table_encodes_nested_container_and_enum_fields() {
    let blob_ptr = jac_bridge_init_rectest();
    let blob_len = unsafe { u32::from_le_bytes(std::slice::from_raw_parts(blob_ptr, 20)[16..20].try_into().unwrap()) } as usize;
    let blob = unsafe { std::slice::from_raw_parts(blob_ptr, blob_len) };

    let recs = parse_records(blob);
    assert_eq!(recs.len(), 4, "Point, Region, Path, Shape");

    // Nested-record field tag = TAG_WIDE | (Point's 1-based id << shift). Point is
    // the first record, so id = 1.
    let point_ref = sch::TAG_WIDE | (1u32 << sch::TAG_WIDE_REC_SHIFT);

    let point = &recs["Point"];
    assert_eq!(point.kind, sch::RECORD_KIND_STRUCT);
    assert_eq!(point.fields, vec![("x".into(), sch::TAG_INT), ("y".into(), sch::TAG_INT)]);

    let region = &recs["Region"];
    assert_eq!(region.kind, sch::RECORD_KIND_STRUCT);
    assert_eq!(
        region.fields,
        vec![("tl".into(), point_ref), ("br".into(), point_ref)],
        "nested-record fields carry TAG_WIDE|id"
    );

    let path = &recs["Path"];
    assert_eq!(path.kind, sch::RECORD_KIND_STRUCT);
    assert_eq!(
        path.fields,
        vec![
            ("pts".into(), sch::TAG_LIST_BIT | point_ref),
            ("name".into(), sch::TAG_OPT_BIT | sch::TAG_STR),
        ],
        "Vec<Point> = LIST|wide, Option<String> = OPT|str"
    );

    let shape = &recs["Shape"];
    assert_eq!(shape.kind, sch::RECORD_KIND_ENUM);
    assert_eq!(
        shape.fields,
        vec![
            ("Dot".into(), sch::TAG_VOID),
            ("Circle".into(), sch::TAG_F64),
            ("At".into(), point_ref),
        ],
        "enum variants: unit=VOID, newtype scalar=F64, newtype record=wide|id"
    );
}
