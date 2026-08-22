import os;
import from os.path { relpath, normcase, abspath, splitext, normpath }

with entry {
    print(os.sep);
    print(os.extsep);
    print(os.pardir);
    print(os.curdir);
    print(os.pathsep);
    print(os.devnull);

    print(relpath("/a/b/c", "/a/b"));
    print(relpath("/a/b/c", "/a"));
    print(relpath("/a", "/a/b/c"));
    print(relpath("/a/b", "/a/b"));
    print(relpath("/a/b/c", "/x/y"));
    print(relpath("/", "/a"));
    print(relpath("/a", "/"));
    print(relpath("/a/b/../c", "/a"));

    print(normcase("A/B"));
    print(normcase("a/b"));
    print(normcase(""));

    print(abspath("/a/../b"));
    print(abspath("/a/./b/"));
    print(abspath("//a/b"));

    (stem, ext) = splitext("a/b.txt");
    print(stem + "|" + ext);
    (stem2, ext2) = splitext("a/.bashrc");
    print(stem2 + "|" + ext2);
    (stem3, ext3) = splitext("a/b.tar.gz");
    print(stem3 + "|" + ext3);
    (stem4, ext4) = splitext("noext");
    print(stem4 + "|" + ext4);

    print(normpath("a/../b"));
    print(normpath("//a//b"));

    _ = os.system("touch -t 202311141322.20 /tmp/jac_os_gaps_mtime.txt");
    print(os.path.getmtime("/tmp/jac_os_gaps_mtime.txt"));
    print(os.path.normcase("A/B"));
    print(os.path.normcase(""));
}
