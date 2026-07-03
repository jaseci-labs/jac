//! Owning-wrapper mechanism demo — M4 Phase B, vertical 1 ("rescues `captures`").
//!
//! Borrowed returns (`Regex::find`/`captures` borrow the haystack) can't cross
//! the boundary as-is: the ABI only carries owned, `Send`, lifetime-free values.
//! The rule (D6, IMPLEMENTATION.md §D6.2) is an *owning wrapper*: a synthesized
//! opaque resource that owns a copy of the borrowed-from input **plus** the
//! borrowing value, with the value's lifetime erased to `'static`
//! (ouroboros-style). This is mechanical — a rule the binder applies, not a skip.
//!
//! This crate is the hand-written exemplar of exactly that shape, so the
//! mechanism is proven and regression-tested on the Rust side before the binder
//! generates it. The haystack is held as `Arc<String>` so a *nested* wrapper — a
//! `Match` produced from a `Captures` (`OwnedCaptures::name_match`) — can SHARE
//! the parent's buffer via an Arc clone instead of re-owning a copy, and remain
//! valid after the parent drops. Three things make the `'static` erasure sound:
//!   1. the `String`'s heap buffer is never mutated or moved-out for the
//!      wrapper's whole life (we only ever read through `inner`),
//!   2. field declaration order is borrower-before-owner, so `inner` drops
//!      before the `Arc<String>` it points into, and
//!   3. every wrapper aliasing the buffer holds its own Arc clone, so the buffer
//!      outlives the last borrower regardless of drop order between wrappers.
//!
//! Producers take `&str` and clone internally, so the wrapper owns its haystack
//! without needing an owned-`String` param at the ABI. `find`/`captures` return
//! `Option<Wrapper>` — `None` (no match) crosses in-band as a null handle.

#![allow(clippy::missing_safety_doc)]

use jac_bridge::bridge;

#[bridge(module = "owning")]
mod bridge_impl {
    /// Opaque handle wrapping a compiled `regex::Regex`.
    pub struct Regex(pub regex::Regex);

    /// Named error type for D2 metadata (error handles are `Box<String>`).
    #[jac_error]
    pub struct OwningError;

    /// Owning wrapper around `regex::Match<'h>` — rescues `Regex::find`.
    pub struct OwnedMatch {
        // Field order == drop order: the borrower (`inner`) drops before the
        // owner (`_haystack`) whose heap buffer it points into.  The haystack is
        // an `Arc<String>` so a child match produced FROM a `Captures` can SHARE
        // this exact buffer (an Arc clone) rather than re-owning a copy — keeping
        // it alive independently of whichever wrapper produced it.
        inner: regex::Match<'static>,
        _haystack: std::sync::Arc<String>,
    }

    /// Owning wrapper around `regex::Captures<'h>` — rescues `Regex::captures`.
    pub struct OwnedCaptures {
        inner: regex::Captures<'static>,
        _haystack: std::sync::Arc<String>,
    }

    impl Regex {
        /// Compile `pattern`. Returns STATUS_ERR on invalid syntax.
        pub fn new(pattern: &str) -> Result<Self, String> {
            regex::Regex::new(pattern).map(Self).map_err(|e| e.to_string())
        }

        pub fn is_match(&self, text: &str) -> bool {
            self.0.is_match(text)
        }

        /// Leftmost-first match. `None` (no match) crosses as a null handle.
        pub fn find(&self, text: &str) -> Option<OwnedMatch> {
            OwnedMatch::wrap(&self.0, text)
        }

        /// Capture groups for the leftmost-first match, or `None`.
        pub fn captures(&self, text: &str) -> Option<OwnedCaptures> {
            OwnedCaptures::wrap(&self.0, text)
        }
    }

    impl OwnedMatch {
        // Non-`pub` → not bridged: the ouroboros constructor.
        fn wrap(re: &regex::Regex, text: &str) -> Option<OwnedMatch> {
            let haystack = std::sync::Arc::new(text.to_owned());
            let m = re.find(haystack.as_str())?;
            // SAFETY: `m` borrows the heap buffer of the `String` inside `haystack`,
            // whose `Arc` is stored next to `m` and never mutated or moved-out. The
            // buffer lives as long as any Arc clone does, so erasing the haystack
            // lifetime to `'static` is sound for the whole life of the struct — and
            // of any child wrapper that clones this Arc (see module docs, inv. 1 & 2).
            let inner: regex::Match<'static> = unsafe { std::mem::transmute(m) };
            Some(OwnedMatch { inner, _haystack: haystack })
        }

        /// The matched substring.
        pub fn as_str(&self) -> String {
            self.inner.as_str().to_owned()
        }
    }

    impl OwnedCaptures {
        fn wrap(re: &regex::Regex, text: &str) -> Option<OwnedCaptures> {
            let haystack = std::sync::Arc::new(text.to_owned());
            let caps = re.captures(haystack.as_str())?;
            // SAFETY: same invariant as OwnedMatch::wrap.
            let inner: regex::Captures<'static> = unsafe { std::mem::transmute(caps) };
            Some(OwnedCaptures { inner, _haystack: haystack })
        }

        /// The text matched by the named group `name`, or `None` if the group
        /// did not participate. (Positional `get(i)` needs an integer param —
        /// tracked as a skip until the ABI carries integers.)
        pub fn name(&self, name: &str) -> Option<String> {
            self.inner.name(name).map(|m| m.as_str().to_owned())
        }

        /// The `Match` for the named group `name`, or `None` if the group did not
        /// participate — the NESTED owning-wrapper case: a reader on one wrapper
        /// (`OwnedCaptures`) produces another (`OwnedMatch`). The child shares the
        /// haystack via an `Arc` clone, so it owns its data independently and stays
        /// valid after the parent `OwnedCaptures` is dropped. This is the faithful
        /// shape of `regex::Captures::name -> Option<Match>` (the sibling `name`
        /// above is a text shortcut); the binder synthesizes exactly this producer.
        pub fn name_match(&self, name: &str) -> Option<OwnedMatch> {
            // `self.inner` is `Captures<'static>`, so its `Match` is already
            // `'static` — no transmute; the Arc clone is what upholds that erased
            // lifetime for the child's whole life.
            let m = self.inner.name(name)?;
            Some(OwnedMatch { inner: m, _haystack: std::sync::Arc::clone(&self._haystack) })
        }
    }
}

// ─── tests ──────────────────────────────────────────────────────────────────
//
// Exercise the owning-wrapper ABI end to end against the generated shims: the
// wrapper handle round-trips, borrowed data survives the producing call's
// return (the haystack is owned, not dangling), `None` crosses as a null
// handle / null JacBuf, and every handle drops cleanly.

#[cfg(test)]
mod tests {
    use std::mem::MaybeUninit;

    use super::{
        jac_owning_Regex_new, jac_owning_Regex_find, jac_owning_Regex_captures,
        jac_owning_Regex_drop, jac_owning_OwnedMatch_as_str, jac_owning_OwnedMatch_drop,
        jac_owning_OwnedCaptures_name, jac_owning_OwnedCaptures_name_match,
        jac_owning_OwnedCaptures_drop,
        jac_owning_error_drop, jac_owning_free_buf,
        __jac_bridge_owning_rt::JacBuf,
    };

    const STATUS_OK: i32 = 0;

    unsafe fn compile(pattern: &str) -> u64 {
        let mut h = 0u64;
        let mut e = 0u64;
        let st = jac_owning_Regex_new(pattern.as_ptr(), pattern.len() as u32, &mut h, &mut e);
        assert_eq!(st, STATUS_OK, "compile failed");
        assert_ne!(h, 0);
        h
    }

    unsafe fn read_buf(buf: &JacBuf) -> String {
        assert!(!buf.ptr.is_null(), "expected Some, got null JacBuf (None)");
        std::str::from_utf8(std::slice::from_raw_parts(buf.ptr, buf.len as usize))
            .unwrap()
            .to_owned()
    }

    /// `find` returns a wrapper whose borrowed data outlives the call: the
    /// haystack is owned by the wrapper, so `as_str` is valid after `find`
    /// returns even though the original text was a transient `&str`.
    #[test]
    fn find_owns_its_haystack() {
        unsafe {
            let re = compile(r"\d+");
            // Build the haystack in a scope that ends before we read the match.
            let mut mh = 0u64;
            let mut e = 0u64;
            {
                let text = String::from("abc 12345 xyz");
                let st = jac_owning_Regex_find(
                    re, text.as_ptr(), text.len() as u32, &mut mh, &mut e,
                );
                assert_eq!(st, STATUS_OK);
                assert_ne!(mh, 0, "expected a match handle");
            } // `text` dropped here — the wrapper must have its own copy.

            let mut buf = MaybeUninit::<JacBuf>::uninit();
            let mut be = 0u64;
            let st = jac_owning_OwnedMatch_as_str(mh, buf.as_mut_ptr(), &mut be);
            assert_eq!(st, STATUS_OK);
            let buf = buf.assume_init();
            assert_eq!(read_buf(&buf), "12345");

            jac_owning_free_buf(buf);
            jac_owning_OwnedMatch_drop(mh);
            jac_owning_Regex_drop(re);
        }
    }

    /// No match → `None` crosses as a null (0) handle on an OK status, never an error.
    #[test]
    fn find_no_match_is_null_handle() {
        unsafe {
            let re = compile(r"\d+");
            let text = "no digits here";
            let mut mh = 12345u64; // poison to prove the shim zeroes it
            let mut e = 0u64;
            let st = jac_owning_Regex_find(re, text.as_ptr(), text.len() as u32, &mut mh, &mut e);
            assert_eq!(st, STATUS_OK, "no-match must be OK, not an error");
            assert_eq!(mh, 0, "None must be a null handle");
            assert_eq!(e, 0);
            jac_owning_Regex_drop(re);
        }
    }

    /// Named-group access: present group → Some(text); absent group → null JacBuf (None).
    #[test]
    fn captures_named_groups() {
        unsafe {
            let re = compile(r"(?P<year>\d{4})-(?P<month>\d{2})");
            let text = "date 2026-07";
            let mut ch = 0u64;
            let mut e = 0u64;
            let st = jac_owning_Regex_captures(
                re, text.as_ptr(), text.len() as u32, &mut ch, &mut e,
            );
            assert_eq!(st, STATUS_OK);
            assert_ne!(ch, 0);

            // Present group.
            let mut buf = MaybeUninit::<JacBuf>::uninit();
            let mut be = 0u64;
            let name = b"year";
            let st = jac_owning_OwnedCaptures_name(
                ch, name.as_ptr(), name.len() as u32, buf.as_mut_ptr(), &mut be,
            );
            assert_eq!(st, STATUS_OK);
            let buf = buf.assume_init();
            assert_eq!(read_buf(&buf), "2026");
            jac_owning_free_buf(buf);

            // Absent group → None (null JacBuf).
            let mut buf2 = MaybeUninit::<JacBuf>::uninit();
            let nope = b"day";
            let st = jac_owning_OwnedCaptures_name(
                ch, nope.as_ptr(), nope.len() as u32, buf2.as_mut_ptr(), &mut be,
            );
            assert_eq!(st, STATUS_OK);
            let buf2 = buf2.assume_init();
            assert!(buf2.ptr.is_null(), "absent group must be a null JacBuf (None)");
            jac_owning_free_buf(buf2); // null-safe

            jac_owning_OwnedCaptures_drop(ch);
            jac_owning_Regex_drop(re);
        }
    }

    /// Nested owning wrapper: a `Match` produced FROM a `Captures` shares the
    /// haystack via an Arc clone and stays readable after the parent `Captures`
    /// (and the original `&str`) are both dropped — the child owns its data.
    #[test]
    fn name_match_nested_outlives_parent() {
        unsafe {
            let re = compile(r"(?P<year>\d{4})-(?P<month>\d{2})");
            let mut mh = 0u64;
            let mut e = 0u64;
            {
                let text = String::from("date 2026-07");
                let mut ch = 0u64;
                let st = jac_owning_Regex_captures(
                    re, text.as_ptr(), text.len() as u32, &mut ch, &mut e,
                );
                assert_eq!(st, STATUS_OK);
                assert_ne!(ch, 0);

                let name = b"year";
                let st = jac_owning_OwnedCaptures_name_match(
                    ch, name.as_ptr(), name.len() as u32, &mut mh, &mut e,
                );
                assert_eq!(st, STATUS_OK);
                assert_ne!(mh, 0, "present group -> Some(match handle)");

                // Drop the PARENT captures while the child match still lives.
                jac_owning_OwnedCaptures_drop(ch);
            } // `text` dropped here too — only the child's Arc keeps the buffer alive.

            let mut buf = MaybeUninit::<JacBuf>::uninit();
            let mut be = 0u64;
            let st = jac_owning_OwnedMatch_as_str(mh, buf.as_mut_ptr(), &mut be);
            assert_eq!(st, STATUS_OK);
            let buf = buf.assume_init();
            assert_eq!(read_buf(&buf), "2026", "child match must still read its group");

            jac_owning_free_buf(buf);
            jac_owning_OwnedMatch_drop(mh);
            jac_owning_Regex_drop(re);
        }
    }

    /// Absent named group → `None` (null match handle) on OK status, never an error.
    #[test]
    fn name_match_absent_group_is_null() {
        unsafe {
            let re = compile(r"(?P<year>\d{4})");
            let text = "2026";
            let mut ch = 0u64;
            let mut e = 0u64;
            let st = jac_owning_Regex_captures(
                re, text.as_ptr(), text.len() as u32, &mut ch, &mut e,
            );
            assert_eq!(st, STATUS_OK);
            assert_ne!(ch, 0);

            let mut mh = 999u64; // poison to prove the shim zeroes it
            let nope = b"month";
            let st = jac_owning_OwnedCaptures_name_match(
                ch, nope.as_ptr(), nope.len() as u32, &mut mh, &mut e,
            );
            assert_eq!(st, STATUS_OK, "absent group must be OK None, not an error");
            assert_eq!(mh, 0, "absent group -> null match handle (None)");
            assert_eq!(e, 0);

            jac_owning_OwnedCaptures_drop(ch);
            jac_owning_Regex_drop(re);
        }
    }

    #[test]
    fn drops_are_zero_safe() {
        unsafe {
            jac_owning_Regex_drop(0);
            jac_owning_OwnedMatch_drop(0);
            jac_owning_OwnedCaptures_drop(0);
            jac_owning_error_drop(0);
        }
    }

    // ── D2 metadata: the wrappers are opaque types with the OPT return bit ──────

    /// `Regex::find` must carry `TAG_OPT_BIT | TAG_REF_BIT | <OwnedMatch idx>`.
    #[test]
    fn find_return_tag_is_optional_ref() {
        let blob = &super::__JAC_BRIDGE_META;
        let n_types = u32::from_le_bytes(blob[44..48].try_into().unwrap()) as usize;
        let n_fns = u32::from_le_bytes(blob[52..56].try_into().unwrap()) as usize;
        let fns_base = 56 + n_types * 32;

        let mut saw_find = false;
        for i in 0..n_fns {
            let fd = fns_base + i * 44;
            let no = u32::from_le_bytes(blob[fd + 4..fd + 8].try_into().unwrap()) as usize;
            let nl = u32::from_le_bytes(blob[fd + 8..fd + 12].try_into().unwrap()) as usize;
            if &blob[no..no + nl] != b"find" {
                continue;
            }
            saw_find = true;
            let ret = u32::from_le_bytes(blob[fd + 32..fd + 36].try_into().unwrap());
            assert_ne!(ret & 0x4000_0000, 0, "find ret must set TAG_OPT_BIT");
            assert_ne!(ret & 0x8000_0000, 0, "find ret must set TAG_REF_BIT");
        }
        assert!(saw_find, "no `find` fn in the blob");
    }
}
