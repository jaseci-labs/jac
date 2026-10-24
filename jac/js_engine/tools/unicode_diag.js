// unicode_diag.js — temporary CI diagnostics for the js-engine unicode regressions.
// Run by the engine binary (zig-out/js/bin/node). Prints byte/unit-level facts for
// the failing test262 scenarios: isWellFormed/slice, decodeURI round-trip, and the
// RegExp @@replace coerce-unicode core. Removed together with its workflow step
// once the regressions are fixed.

function units(s) {
    var out = [];
    for (var i = 0; i < s.length; i++) {
        out.push(s.charCodeAt(i).toString(16));
    }
    return out.join(",");
}

var hi = "\uD83D";
var lo = "\uDCA9";
var whole = hi + lo;
console.log("A whole.length        =", whole.length, "(want 2)");
console.log("A whole.units         =", units(whole), "(want d83d,dca9)");
console.log("A whole.isWellFormed  =", whole.isWellFormed(), "(want true)");
var s01 = whole.slice(0, 1);
console.log("A s01.length          =", s01.length, "(want 1)");
console.log("A s01.units           =", units(s01), "(want d83d)");
console.log("A s01.isWellFormed    =", s01.isWellFormed(), "(want false)");
var s1 = whole.slice(1);
console.log("A s1.units            =", units(s1), "(want dca9)");
console.log("A s1.isWellFormed     =", s1.isWellFormed(), "(want false)");
console.log("A literal pair wf     =", "\uD83D\uDCA9".isWellFormed(), "(want true)");
console.log("A lone high wf        =", "\uD83D".isWellFormed(), "(want false)");
console.log("A charAt units        =", units(whole.charAt(0)), "(want d83d)");

var fcc0 = String.fromCharCode(0);
console.log("B fcc0.length         =", fcc0.length, "(want 1)");
console.log("B fcc0.code           =", fcc0.charCodeAt(0), "(want 0)");
console.log("B decodeURI===fcc0    =", decodeURI(fcc0) === fcc0, "(want true)");
console.log("B decodeURI.length    =", decodeURI(fcc0).length, "(want 1)");
var fccD834 = String.fromCharCode(0xd834);
console.log("B fccD834.units       =", units(fccD834), "(want d834)");
console.log("B fccD834 wf          =", fccD834.isWellFormed(), "(want false)");

var bad = -1;
for (var u = 0; u < 65536; u++) {
    if (u === 0x25) { continue; }
    var s = String.fromCharCode(u);
    if (decodeURI(s) !== s) { bad = u; break; }
}
console.log("B decodeURI first bad =", bad, "(want -1)");
var bad2 = -1;
for (var v = 0; v < 65536; v++) {
    if (v === 0x25) { continue; }
    var t = String.fromCharCode(v);
    if (decodeURIComponent(t) !== t) { bad2 = v; break; }
}
console.log("B decodeURIComp bad   =", bad2, "(want -1)");

var subj = "\ud834\udf06";
console.log("C subj.units          =", units(subj), "(want d834,df06)");
console.log("C subj.length         =", subj.length, "(want 2)");
var r = /^|\udf06/g;
console.log("C r.unicode default   =", r.unicode, "(want false)");
var outF = r[Symbol.replace](subj, "XXX");
console.log("C replace falsy units =", units(outF), "(want 78,78,78,d834,78,78,78)");
r.unicode = true;
var outT = r[Symbol.replace](subj, "XXX");
console.log("C replace true units  =", units(outT), "(want 78,78,78,d834,df06,78,78,78)");
var re2 = /\udf06/;
console.log("C exec d834df06       =", re2.exec(subj) === null ? "null" : units(re2.exec(subj)[0]), "(want df06)");
console.log("C indexOf df06        =", subj.indexOf("\udf06"), "(want 1)");
console.log("done");
