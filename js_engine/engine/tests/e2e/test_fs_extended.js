// test_fs_extended.js — Phase 5.10: Extended file system tests
// Tests: readdirSync, mkdirSync, rmdirSync, rmSync, renameSync,
//        copyFileSync, chmodSync, chownSync, symlinkSync, readlinkSync,
//        realpathSync, accessSync, lstatSync, createWriteStream,
//        fs.promises.*, require("fs")

var pass = 0;
var fail = 0;
var t = 0;

function ok(cond, desc) {
    t = t + 1;
    if (cond) {
        pass = pass + 1;
        console.log("ok " + t + " - " + desc);
    } else {
        fail = fail + 1;
        console.log("FAIL " + t + " - " + desc);
    }
}

var fs = require("fs");
var pid = process.pid;
var base = "/tmp/jb_fsext_" + pid;

// ═══════════════════════════════════════════════════════════════
// 1. readdirSync
// ═══════════════════════════════════════════════════════════════

var entries = fs.readdirSync(".");
ok(Array.isArray(entries), "readdirSync returns array");
ok(entries.length > 0, "readdirSync has entries");

// Check that it contains known files
var hasMakefile = false;
for (var i = 0; i < entries.length; i++) {
    if (entries[i] === "Makefile") { hasMakefile = true; }
}
ok(hasMakefile, "readdirSync contains Makefile");

// Non-existent directory
var badDir = fs.readdirSync("/tmp/nonexistent_dir_" + pid);
ok(badDir === undefined, "readdirSync returns undefined for missing dir");

// ═══════════════════════════════════════════════════════════════
// 2. mkdirSync / rmdirSync
// ═══════════════════════════════════════════════════════════════

var testDir = base + "_dir";
fs.mkdirSync(testDir);
ok(fs.existsSync(testDir) === true, "mkdirSync creates directory");

var dirStat = fs.statSync(testDir);
ok(dirStat.isDirectory() === true, "mkdirSync creates a directory (stat)");

fs.rmdirSync(testDir);
ok(fs.existsSync(testDir) === false, "rmdirSync removes directory");

// ═══════════════════════════════════════════════════════════════
// 3. rmSync
// ═══════════════════════════════════════════════════════════════

var rmFile = base + "_rm.txt";
fs.writeFileSync(rmFile, "to be removed");
ok(fs.existsSync(rmFile) === true, "rmSync: file exists before");
fs.rmSync(rmFile);
ok(fs.existsSync(rmFile) === false, "rmSync removes file");

// rmSync on directory
var rmDir = base + "_rmdir";
fs.mkdirSync(rmDir);
fs.rmSync(rmDir);
ok(fs.existsSync(rmDir) === false, "rmSync removes empty directory");

// ═══════════════════════════════════════════════════════════════
// 4. renameSync
// ═══════════════════════════════════════════════════════════════

var renSrc = base + "_ren_src.txt";
var renDst = base + "_ren_dst.txt";
fs.writeFileSync(renSrc, "rename me");
fs.renameSync(renSrc, renDst);
ok(fs.existsSync(renSrc) === false, "renameSync: source gone");
ok(fs.existsSync(renDst) === true, "renameSync: dest exists");
var renContent = fs.readFileSync(renDst, "utf8");
ok(renContent === "rename me", "renameSync: content preserved");
fs.unlinkSync(renDst);

// ═══════════════════════════════════════════════════════════════
// 5. copyFileSync
// ═══════════════════════════════════════════════════════════════

var cpSrc = base + "_cp_src.txt";
var cpDst = base + "_cp_dst.txt";
fs.writeFileSync(cpSrc, "copy me");
fs.copyFileSync(cpSrc, cpDst);
ok(fs.existsSync(cpSrc) === true, "copyFileSync: source still exists");
ok(fs.existsSync(cpDst) === true, "copyFileSync: dest exists");
var cpContent = fs.readFileSync(cpDst, "utf8");
ok(cpContent === "copy me", "copyFileSync: content matches");
fs.unlinkSync(cpSrc);
fs.unlinkSync(cpDst);

// ═══════════════════════════════════════════════════════════════
// 6. chmodSync
// ═══════════════════════════════════════════════════════════════

var chmodFile = base + "_chmod.txt";
fs.writeFileSync(chmodFile, "chmod test");
// 0o644 = 420
fs.chmodSync(chmodFile, 420);
ok(fs.existsSync(chmodFile), "chmodSync: file still accessible after chmod");
// 0o755 = 493
fs.chmodSync(chmodFile, 493);
ok(true, "chmodSync: no crash on mode change");
fs.unlinkSync(chmodFile);

// ═══════════════════════════════════════════════════════════════
// 7. symlinkSync / readlinkSync
// ═══════════════════════════════════════════════════════════════

var symlinkTarget = base + "_sym_target.txt";
var symlinkPath = base + "_sym_link.txt";
fs.writeFileSync(symlinkTarget, "symlink target");
fs.symlinkSync(symlinkTarget, symlinkPath);
ok(fs.existsSync(symlinkPath) === true, "symlinkSync: link exists");

var linkTarget = fs.readlinkSync(symlinkPath);
ok(linkTarget === symlinkTarget, "readlinkSync: returns correct target");

// Read through symlink
var symContent = fs.readFileSync(symlinkPath, "utf8");
ok(symContent === "symlink target", "symlink: can read through link");

fs.unlinkSync(symlinkPath);
fs.unlinkSync(symlinkTarget);

// ═══════════════════════════════════════════════════════════════
// 8. realpathSync
// ═══════════════════════════════════════════════════════════════

var rpFile = base + "_rp.txt";
fs.writeFileSync(rpFile, "realpath test");
var realPath = fs.realpathSync(rpFile);
ok(typeof realPath === "string", "realpathSync returns string");
ok(realPath.length > 0, "realpathSync returns non-empty path");
// Should resolve to an absolute path starting with /
ok(realPath[0] === "/", "realpathSync returns absolute path");
fs.unlinkSync(rpFile);

// Non-existent path
var badRealpath = fs.realpathSync("/tmp/nonexistent_" + pid);
ok(badRealpath === undefined, "realpathSync returns undefined for missing");

// ═══════════════════════════════════════════════════════════════
// 9. accessSync
// ═══════════════════════════════════════════════════════════════

var accFile = base + "_access.txt";
fs.writeFileSync(accFile, "access test");
// Should not throw/crash for existing file
fs.accessSync(accFile);
ok(true, "accessSync: no crash for existing file");
fs.unlinkSync(accFile);

// ═══════════════════════════════════════════════════════════════
// 10. lstatSync
// ═══════════════════════════════════════════════════════════════

var lsFile = base + "_lstat.txt";
fs.writeFileSync(lsFile, "lstat test");
var lstat = fs.lstatSync(lsFile);
ok(typeof lstat === "object", "lstatSync returns object");
ok(lstat.isFile() === true, "lstatSync.isFile() is true for file");
ok(lstat.isDirectory() === false, "lstatSync.isDirectory() is false for file");
ok(lstat.size > 0, "lstatSync.size > 0");
ok(lstat.mode > 0, "lstatSync.mode > 0");

// lstat on symlink should report isSymbolicLink
var lsTarget = base + "_lstat_target.txt";
var lsLink = base + "_lstat_link.txt";
fs.writeFileSync(lsTarget, "target");
fs.symlinkSync(lsTarget, lsLink);
var linkStat = fs.lstatSync(lsLink);
ok(linkStat.isSymbolicLink() === true, "lstatSync.isSymbolicLink() true for symlink");
ok(linkStat.isFile() === false, "lstatSync.isFile() false for symlink");

fs.unlinkSync(lsLink);
fs.unlinkSync(lsTarget);
fs.unlinkSync(lsFile);

// Non-existent path
var badLstat = fs.lstatSync("/tmp/nonexistent_" + pid);
ok(badLstat === undefined, "lstatSync returns undefined for missing");

// ═══════════════════════════════════════════════════════════════
// 11. require("fs") returns augmented object
// ═══════════════════════════════════════════════════════════════

var reqFs = require("fs");
ok(typeof reqFs === "object", "require('fs') returns object");
ok(typeof reqFs.readFileSync === "function", "require('fs').readFileSync");
ok(typeof reqFs.readdirSync === "function", "require('fs').readdirSync");
ok(typeof reqFs.mkdirSync === "function", "require('fs').mkdirSync");
ok(typeof reqFs.renameSync === "function", "require('fs').renameSync");

// ═══════════════════════════════════════════════════════════════
// 12. fs.promises
// ═══════════════════════════════════════════════════════════════

var fsp = reqFs.promises;
ok(typeof fsp === "object", "fs.promises is an object");
ok(typeof fsp.readFile === "function", "fs.promises.readFile exists");
ok(typeof fsp.writeFile === "function", "fs.promises.writeFile exists");
ok(typeof fsp.stat === "function", "fs.promises.stat exists");
ok(typeof fsp.readdir === "function", "fs.promises.readdir exists");
ok(typeof fsp.mkdir === "function", "fs.promises.mkdir exists");
ok(typeof fsp.unlink === "function", "fs.promises.unlink exists");
ok(typeof fsp.rename === "function", "fs.promises.rename exists");
ok(typeof fsp.copyFile === "function", "fs.promises.copyFile exists");
ok(typeof fsp.chmod === "function", "fs.promises.chmod exists");

// fs.promises.writeFile + readFile roundtrip
var promFile = base + "_promise.txt";
fsp.writeFile(promFile, "promise content").then(function() {
    return fsp.readFile(promFile, "utf8");
}).then(function(data) {
    ok(data === "promise content", "fs.promises writeFile+readFile roundtrip");
    return fsp.stat(promFile);
}).then(function(st) {
    ok(st.isFile() === true, "fs.promises.stat isFile()");
    ok(st.size > 0, "fs.promises.stat size > 0");
    return fsp.readdir("/tmp");
}).then(function(entries2) {
    ok(Array.isArray(entries2), "fs.promises.readdir returns array");
    ok(entries2.length > 0, "fs.promises.readdir has entries");
    return fsp.unlink(promFile);
}).then(function() {
    ok(fs.existsSync(promFile) === false, "fs.promises.unlink removed file");

    // fs.promises.readFile on missing file should reject
    return fsp.readFile("/tmp/nonexistent_" + pid + ".txt");
}).then(function() {
    ok(false, "fs.promises.readFile should reject for missing");
}).catch(function(err) {
    ok(err !== undefined && err !== null, "fs.promises.readFile rejects for missing");
    ok(err.code === "ENOENT", "fs.promises.readFile error has ENOENT code");
});

// ═══════════════════════════════════════════════════════════════
// 13. createWriteStream
// ═══════════════════════════════════════════════════════════════

var wsFile = base + "_wstream.txt";
var ws = reqFs.createWriteStream(wsFile);
ok(typeof ws === "object", "createWriteStream returns object");
ok(typeof ws.write === "function", "createWriteStream has write()");
ok(typeof ws.end === "function", "createWriteStream has end()");
ok(typeof ws.on === "function", "createWriteStream has on()");

ws.write("hello ");
ws.write("world");

var finishCalled = false;
ws.on("finish", function() {
    finishCalled = true;
});

ws.end("!");

ok(finishCalled === true, "createWriteStream finish event fired");

var wsContent = fs.readFileSync(wsFile, "utf8");
ok(wsContent === "hello world!", "createWriteStream: content matches");

// Write after end should be no-op
var retAfterEnd = ws.write("more");
ok(retAfterEnd === false, "write after end returns false");

fs.unlinkSync(wsFile);

// ═══════════════════════════════════════════════════════════════
// 14. require("node:fs") with node: prefix
// ═══════════════════════════════════════════════════════════════

var nodeFs = require("node:fs");
ok(typeof nodeFs === "object", "require('node:fs') works");
ok(typeof nodeFs.readFileSync === "function", "require('node:fs').readFileSync");

// Print summary after async tests (promises) have settled
setTimeout(function() {
    console.log("=== fs_extended tests: " + pass + " passed, " + fail + " failed ===");
}, 200);
