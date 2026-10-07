// test_fs.js — Phase 3.5: File system API tests
// Tests: readFileSync, writeFileSync, appendFileSync, existsSync, unlinkSync,
//        statSync, readFile (async), writeFile (async)

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
var tmpFile = "/tmp/jb_test_fs_" + process.pid + ".txt";
var tmpFile2 = "/tmp/jb_test_fs2_" + process.pid + ".txt";

// 1. fs object exists
ok(typeof fs === "object", "fs is an object");

// 2. fs has expected methods
ok(typeof fs.readFileSync === "function", "fs.readFileSync is a function");
ok(typeof fs.writeFileSync === "function", "fs.writeFileSync is a function");
ok(typeof fs.existsSync === "function", "fs.existsSync is a function");
ok(typeof fs.unlinkSync === "function", "fs.unlinkSync is a function");
ok(typeof fs.readFile === "function", "fs.readFile is a function");
ok(typeof fs.writeFile === "function", "fs.writeFile is a function");
ok(typeof fs.statSync === "function", "fs.statSync is a function");
ok(typeof fs.appendFileSync === "function", "fs.appendFileSync is a function");

// 3. writeFileSync + readFileSync roundtrip
fs.writeFileSync(tmpFile, "hello world");
var content = fs.readFileSync(tmpFile, "utf8");
ok(content === "hello world", "writeFileSync + readFileSync roundtrip");

// 4. existsSync — existing file
ok(fs.existsSync(tmpFile) === true, "existsSync returns true for existing file");

// 5. existsSync — non-existing file
ok(fs.existsSync("/tmp/this_file_does_not_exist_999.txt") === false, "existsSync returns false for missing file");

// 6. readFileSync — non-existing file returns undefined
var missing = fs.readFileSync("/tmp/this_file_does_not_exist_999.txt");
ok(missing === undefined, "readFileSync returns undefined for missing file");

// 7. appendFileSync
fs.appendFileSync(tmpFile, " appended");
var appended = fs.readFileSync(tmpFile, "utf8");
ok(appended === "hello world appended", "appendFileSync appends to file");

// 8. writeFileSync overwrites
fs.writeFileSync(tmpFile, "overwritten");
var overwritten = fs.readFileSync(tmpFile, "utf8");
ok(overwritten === "overwritten", "writeFileSync overwrites existing file");

// 9. statSync — existing file
var stat = fs.statSync(tmpFile);
ok(typeof stat === "object", "statSync returns an object");
ok(stat.size > 0, "statSync.size > 0 for non-empty file");
ok(stat.isFile() === true, "statSync.isFile() is true");

// 10. unlinkSync
fs.unlinkSync(tmpFile);
ok(fs.existsSync(tmpFile) === false, "unlinkSync removes the file");

// 11. readFileSync empty file
fs.writeFileSync(tmpFile2, "");
var empty = fs.readFileSync(tmpFile2, "utf8");
ok(empty === "", "readFileSync reads empty file as empty string");
fs.unlinkSync(tmpFile2);

// 12. writeFileSync with multiline content
var multiline = "line1\nline2\nline3\n";
fs.writeFileSync(tmpFile, multiline);
var readBack = fs.readFileSync(tmpFile, "utf8");
ok(readBack === multiline, "writeFileSync/readFileSync preserve newlines");

// 13. Async readFile (callback)
var asyncTmpFile = "/tmp/jb_test_fs_async_" + process.pid + ".txt";
fs.writeFileSync(asyncTmpFile, "async content");

fs.readFile(asyncTmpFile, "utf8", function(err, data) {
    ok(err === null, "readFile callback: err is null on success");
    ok(data === "async content", "readFile callback: data matches written content");

    // 14. Async readFile — error path
    fs.readFile("/tmp/this_file_does_not_exist_999.txt", "utf8", function(err2, data2) {
        ok(err2 !== null, "readFile callback: err is non-null for missing file");
        ok(data2 === undefined, "readFile callback: data is undefined on error");

        // 15. Async writeFile
        var asyncTmpFile2 = "/tmp/jb_test_fs_async2_" + process.pid + ".txt";
        fs.writeFile(asyncTmpFile2, "written async", function(err3) {
            ok(err3 === null, "writeFile callback: err is null on success");

            // Verify the write
            var verifyContent = fs.readFileSync(asyncTmpFile2, "utf8");
            ok(verifyContent === "written async", "writeFile + readFileSync verification");

            // Cleanup
            fs.unlinkSync(asyncTmpFile);
            fs.unlinkSync(asyncTmpFile2);
            fs.unlinkSync(tmpFile);
        });
    });
});

// Print summary after async callbacks have had a chance to run
setTimeout(function() {
    console.log("=== fs tests: " + pass + " passed, " + fail + " failed ===");
}, 100);
