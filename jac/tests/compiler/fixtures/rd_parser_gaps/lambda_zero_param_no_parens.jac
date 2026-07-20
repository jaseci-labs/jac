# Zero-parameter lambdas may omit the parens entirely; the parenthesized
# form and a bare return hint stay valid.
glob bare = lambda { 42; },
     parened = lambda() { 7; },
     hinted = lambda -> int { 1; };

with entry {
    print(bare(), parened(), hinted());
}
