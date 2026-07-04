//! Owning-wrapper mechanism demo — M4 Phase B ("rescues `find`/`captures`,
//! plus the iterator/cursor and `Vec`-as-drain classes").
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
//!
//! The same owning discipline scales to the two remaining borrowed-return classes,
//! and both reduce to "one more opaque handle + a pull method" — no new ABI tag:
//!   * ITERATORS/CURSORS (`Regex::find_iter -> Matches<'r,'h>`): the cursor owns
//!     the regex and haystack via `Arc`, erases the iterator's lifetimes, and
//!     exposes `next -> Option<OwnedMatch>` (a pull-queue). Each pulled match
//!     clones the haystack `Arc`, so it outlives the cursor.
//!   * `Vec`-AS-DRAIN (`Regex::split -> Split<'h>`): the pieces are copied into an
//!     owned `Vec<String>` up front (no lifetime survives) and drained via
//!     `next -> Option<String>`.
//!
//! The last class is CALLBACKS (`Regex::replace_all` with a closure `Replacer`),
//! where Rust calls BACK into Jac once per match.  The callback crosses as a
//! pointer to a two-word `{call, ctx}` closure record (`JacCallback`): `call` is
//! the C-ABI thunk's address and `ctx` an opaque environment pointer (null when
//! the callback captures nothing).  On the na runtime the backend builds the
//! record from a `lambda` — a synthesized trampoline is `call`, and any captured
//! variables are packed into the `ctx` env struct; on CPython it is a
//! `CFUNCTYPE`-wrapped callable with a null `ctx`.  The callback returns its
//! replacement through an owned `JacBuf` allocated Jac-side via the generated
//! `jac_owning_make_buf` and freed here after copying — the same allocator both
//! ways, so no cross-heap free.

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

    /// Owning CURSOR over `regex::Matches<'r,'h>` — rescues `Regex::find_iter`.
    /// The iterator borrows BOTH the compiled regex AND the haystack, so the
    /// cursor owns each via an `Arc` and erases the iterator's two lifetimes to
    /// `'static`. `next` pulls one match at a time (a pull-queue), each item an
    /// `OwnedMatch` sharing this cursor's haystack `Arc` — the nested-wrapper
    /// rule applied to the iterator's items. Field order is borrower(`iter`)-
    /// before-owners so the iterator drops before the buffers it points into.
    pub struct OwnedMatches {
        iter: regex::Matches<'static, 'static>,
        _re: std::sync::Arc<regex::Regex>,
        _haystack: std::sync::Arc<String>,
    }

    /// Owning DRAIN cursor over an eagerly-collected `Vec<String>` — rescues
    /// `Regex::split`, whose native form yields `&str` slices borrowing the
    /// haystack. We copy each piece into an owned `String` up front (no
    /// lifetimes survive), then `next` drains them front-to-back. This is the
    /// `Vec<T>`-as-drain-cursor shape: an owned collection reduced to a handle +
    /// a pull method, no new ABI tag needed (`next -> Option<String>`).
    pub struct OwnedSplit {
        // Stored reversed so `next` is an O(1) `pop()` while draining front-to-back.
        items: Vec<String>,
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

        /// Cursor over every non-overlapping match — rescues `find_iter`. Unlike
        /// `find` (nullable, single), a cursor is always constructed (an empty
        /// stream is a live handle whose first `next` is `None`).
        pub fn find_iter(&self, text: &str) -> OwnedMatches {
            OwnedMatches::wrap(&self.0, text)
        }

        /// Drain cursor over the substrings between matches — rescues `split`.
        pub fn split(&self, text: &str) -> OwnedSplit {
            OwnedSplit::collect(&self.0, text)
        }

        /// Replace every match of `self` in `text` by invoking the Jac callback
        /// `rep` on each matched substring — the CALLBACK vertical, rescuing
        /// `Regex::replace_all` with a closure `Replacer`.  This is the one
        /// vertical where Rust calls BACK into Jac: for each match we hand the
        /// matched text to `rep` and splice in the `String` it returns.
        ///
        /// The callback crosses as a pointer to a two-word `{call, ctx}` closure
        /// record (`JacCallback`): `call` is the C-ABI thunk's address and `ctx`
        /// an opaque env pointer (null when nothing is captured).  On the na
        /// runtime the backend synthesizes the trampoline (`call`) and packs any
        /// captures into `ctx`; on CPython it is a `CFUNCTYPE`-wrapped callable
        /// with a null `ctx`.  A callback error aborts the replacement and
        /// surfaces as this method's `Err` (a thrown exception on both loaders).
        pub fn replace_all(&self, text: &str, rep: JacCallback) -> Result<String, String> {
            // `replace_all`'s closure must return a `String`, with no error
            // channel of its own; capture the first callback error and raise it
            // after the walk completes.
            let err: std::cell::RefCell<Option<String>> = std::cell::RefCell::new(None);
            let out = self
                .0
                .replace_all(text, |caps: &regex::Captures| {
                    let m = caps.get(0).map_or("", |x| x.as_str());
                    match rep.call(m) {
                        Ok(s) => s,
                        Err(e) => {
                            if err.borrow().is_none() {
                                *err.borrow_mut() = Some(e);
                            }
                            String::new()
                        }
                    }
                })
                .into_owned();
            match err.into_inner() {
                Some(e) => Err(e),
                None => Ok(out),
            }
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

    impl OwnedMatches {
        // Non-`pub` → not bridged: the ouroboros cursor constructor.
        fn wrap(re: &regex::Regex, text: &str) -> OwnedMatches {
            let re = std::sync::Arc::new(re.clone());
            let haystack = std::sync::Arc::new(text.to_owned());
            // SAFETY: `iter` borrows `*re` and `*haystack`, both owned via `Arc`
            // stored next to it and never mutated or moved-out for the cursor's
            // life. Erasing both lifetimes to `'static` is sound (module inv. 1-2);
            // each yielded item clones the haystack `Arc`, so a match outlives the
            // cursor (inv. 3). `Matches: Send` is asserted by the generated shims.
            let iter: regex::Matches<'static, 'static> =
                unsafe { std::mem::transmute(re.find_iter(haystack.as_str())) };
            OwnedMatches { iter, _re: re, _haystack: haystack }
        }

        /// Pull the next match, or `None` once the stream is exhausted. The item
        /// shares this cursor's haystack `Arc`, so it stays valid after the cursor
        /// is dropped — the nested-wrapper rule, applied per iteration.
        #[allow(clippy::should_implement_trait)] // a pull-queue method, not Iterator
        pub fn next(&mut self) -> Option<OwnedMatch> {
            // `self.iter` is `Matches<'static,'static>`, so its item is already
            // `Match<'static>` — no transmute; the Arc clone upholds that lifetime.
            let m = self.iter.next()?;
            Some(OwnedMatch { inner: m, _haystack: std::sync::Arc::clone(&self._haystack) })
        }
    }

    impl OwnedSplit {
        // Non-`pub` → not bridged: eagerly copy each &str piece into an owned
        // String so no haystack lifetime survives, then store reversed for O(1)
        // front-to-back draining.
        fn collect(re: &regex::Regex, text: &str) -> OwnedSplit {
            let mut items: Vec<String> = re.split(text).map(|s| s.to_owned()).collect();
            items.reverse();
            OwnedSplit { items }
        }

        /// Drain the next piece front-to-back, or `None` once exhausted.
        #[allow(clippy::should_implement_trait)] // a pull-queue method, not Iterator
        pub fn next(&mut self) -> Option<String> {
            self.items.pop()
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
        jac_owning_Regex_find_iter, jac_owning_Regex_split, jac_owning_Regex_replace_all,
        jac_owning_Regex_drop, jac_owning_OwnedMatch_as_str, jac_owning_OwnedMatch_drop,
        jac_owning_OwnedCaptures_name, jac_owning_OwnedCaptures_name_match,
        jac_owning_OwnedCaptures_drop,
        jac_owning_OwnedMatches_next, jac_owning_OwnedMatches_drop,
        jac_owning_OwnedSplit_next, jac_owning_OwnedSplit_drop,
        jac_owning_error_drop, jac_owning_free_buf, jac_owning_make_buf,
        __jac_bridge_owning_rt::JacBuf,
    };

    /// A hand-written C-ABI callback — exactly the shape a Jac `def:pub` na thunk
    /// (or a CPython `CFUNCTYPE`) presents to `replace_all`.  It uppercases the
    /// matched text and hands the replacement back as an owned `JacBuf` allocated
    /// via the bridge's own `make_buf` (so `replace_all` frees it with the same
    /// allocator).
    unsafe fn upper_cb(
        _ctx: *mut std::ffi::c_void, ptr: *const u8, len: u32,
        out_buf: *mut JacBuf, _out_err: *mut u64,
    ) -> i32 {
        let s = std::str::from_utf8(std::slice::from_raw_parts(ptr, len as usize)).unwrap();
        let up = s.to_uppercase();
        jac_owning_make_buf(up.as_ptr(), up.len() as u32, out_buf);
        0
    }

    /// A callback that always fails (nonzero status) — proves the error channel
    /// aborts the replacement and surfaces as `replace_all`'s Err.
    unsafe fn failing_cb(
        _ctx: *mut std::ffi::c_void, _ptr: *const u8, _len: u32,
        _out_buf: *mut JacBuf, _out_err: *mut u64,
    ) -> i32 {
        7
    }

    /// The callback crosses as a pointer to a `{call, ctx}` record (the ABI the
    /// na compiler and CPython loader build).  `cb_fn` is the thunk's address;
    /// module-level thunks like these carry a null `ctx`.
    unsafe fn call_replace_all(re: u64, text: &str, cb_fn: usize) -> Result<String, i32> {
        let rec: [usize; 2] = [cb_fn, 0];
        let cb = rec.as_ptr() as u64;
        let mut buf = MaybeUninit::<JacBuf>::uninit();
        let mut e = 0u64;
        let st = jac_owning_Regex_replace_all(
            re, text.as_ptr(), text.len() as u32, cb, buf.as_mut_ptr(), &mut e,
        );
        if st != 0 {
            if e != 0 {
                jac_owning_error_drop(e);
            }
            return Err(st);
        }
        let buf = buf.assume_init();
        let out = read_buf(&buf);
        jac_owning_free_buf(buf);
        Ok(out)
    }

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

    /// Cursor: `find_iter` yields a live handle; `next` pulls each match in order
    /// and finally `None`. The cursor owns its haystack (built in an inner scope
    /// that ends before we drain), and a pulled match outlives the cursor drop.
    #[test]
    fn find_iter_cursor_pulls_all_matches() {
        unsafe {
            let re = compile(r"\d+");
            let mut ch = 0u64;
            let mut e = 0u64;
            {
                let text = String::from("a1 b22 c333");
                let st =
                    jac_owning_Regex_find_iter(re, text.as_ptr(), text.len() as u32, &mut ch, &mut e);
                assert_eq!(st, STATUS_OK);
                assert_ne!(ch, 0, "find_iter always yields a live cursor handle");
            } // haystack dropped — the cursor owns its own Arc copy.

            let expected = ["1", "22", "333"];
            let mut last_match = 0u64;
            for want in expected {
                let mut mh = 0u64;
                let st = jac_owning_OwnedMatches_next(ch, &mut mh, &mut e);
                assert_eq!(st, STATUS_OK);
                assert_ne!(mh, 0, "expected a match handle for {want}");

                let mut buf = MaybeUninit::<JacBuf>::uninit();
                let mut be = 0u64;
                let st = jac_owning_OwnedMatch_as_str(mh, buf.as_mut_ptr(), &mut be);
                assert_eq!(st, STATUS_OK);
                let buf = buf.assume_init();
                assert_eq!(read_buf(&buf), want);
                jac_owning_free_buf(buf);

                if last_match != 0 {
                    jac_owning_OwnedMatch_drop(last_match);
                }
                last_match = mh; // keep the LAST match alive past the cursor drop
            }

            // Stream exhausted → None (null handle) on OK status, forever.
            let mut done = 42u64;
            let st = jac_owning_OwnedMatches_next(ch, &mut done, &mut e);
            assert_eq!(st, STATUS_OK);
            assert_eq!(done, 0, "exhausted cursor must yield None (null handle)");

            // Drop the cursor while the last pulled match still lives, then read it.
            jac_owning_OwnedMatches_drop(ch);
            let mut buf = MaybeUninit::<JacBuf>::uninit();
            let mut be = 0u64;
            let st = jac_owning_OwnedMatch_as_str(last_match, buf.as_mut_ptr(), &mut be);
            assert_eq!(st, STATUS_OK);
            let buf = buf.assume_init();
            assert_eq!(read_buf(&buf), "333", "last match must outlive the cursor");
            jac_owning_free_buf(buf);
            jac_owning_OwnedMatch_drop(last_match);

            jac_owning_Regex_drop(re);
        }
    }

    /// Drain cursor: `split` collects owned pieces up front; `next` drains them
    /// front-to-back and then `None`. The pieces are owned Strings, so the drain
    /// is valid after the original haystack is gone.
    #[test]
    fn split_drain_pulls_all_pieces() {
        unsafe {
            let re = compile(r",\s*");
            let mut dh = 0u64;
            let mut e = 0u64;
            {
                let text = String::from("a, bb,ccc, ");
                let st =
                    jac_owning_Regex_split(re, text.as_ptr(), text.len() as u32, &mut dh, &mut e);
                assert_eq!(st, STATUS_OK);
                assert_ne!(dh, 0);
            } // haystack dropped — the drain owns copies.

            // split on ",\s*" over "a, bb,ccc, " → ["a", "bb", "ccc", ""].
            let expected = ["a", "bb", "ccc", ""];
            for want in expected {
                let mut buf = MaybeUninit::<JacBuf>::uninit();
                let mut be = 0u64;
                let st = jac_owning_OwnedSplit_next(dh, buf.as_mut_ptr(), &mut be);
                assert_eq!(st, STATUS_OK);
                let buf = buf.assume_init();
                assert!(!buf.ptr.is_null(), "piece {want:?} must be Some, not None");
                assert_eq!(read_buf(&buf), want);
                jac_owning_free_buf(buf);
            }

            // Exhausted → None (null JacBuf) on OK status.
            let mut buf = MaybeUninit::<JacBuf>::uninit();
            let mut be = 0u64;
            let st = jac_owning_OwnedSplit_next(dh, buf.as_mut_ptr(), &mut be);
            assert_eq!(st, STATUS_OK);
            let buf = buf.assume_init();
            assert!(buf.ptr.is_null(), "exhausted drain must yield None (null JacBuf)");
            jac_owning_free_buf(buf); // null-safe

            jac_owning_OwnedSplit_drop(dh);
            jac_owning_Regex_drop(re);
        }
    }

    /// Callback: `replace_all` invokes the Jac callback once per match and
    /// splices in its result.  Rust calls BACK into (here, hand-written C) code
    /// per match; the replacement crosses as an owned JacBuf, freed after copy.
    #[test]
    fn replace_all_invokes_callback_per_match() {
        unsafe {
            let re = compile(r"\w+");
            let cb = upper_cb as *const () as usize;
            // Two matches — the callback fires for each, punctuation untouched.
            assert_eq!(call_replace_all(re, "hello world", cb).unwrap(), "HELLO WORLD");
            // No match — the callback never fires, text passes through verbatim.
            assert_eq!(call_replace_all(re, "!!! ???", cb).unwrap(), "!!! ???");
            // Empty haystack — no matches, empty result.
            assert_eq!(call_replace_all(re, "", cb).unwrap(), "");
            jac_owning_Regex_drop(re);
        }
    }

    /// A failing callback aborts the replacement: the nonzero status propagates
    /// out as `replace_all`'s error (a raised exception on both loaders).
    #[test]
    fn replace_all_propagates_callback_error() {
        unsafe {
            let re = compile(r"\w+");
            let cb = failing_cb as *const () as usize;
            // The callback fails on the first match -> the whole call errors.
            let r = call_replace_all(re, "abc def", cb);
            assert_eq!(r, Err(1), "callback error must surface as a status-1 error");
            jac_owning_Regex_drop(re);
        }
    }

    #[test]
    fn drops_are_zero_safe() {
        unsafe {
            jac_owning_Regex_drop(0);
            jac_owning_OwnedMatch_drop(0);
            jac_owning_OwnedCaptures_drop(0);
            jac_owning_OwnedMatches_drop(0);
            jac_owning_OwnedSplit_drop(0);
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
