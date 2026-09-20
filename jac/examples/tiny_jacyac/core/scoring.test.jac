test "reputation rewards contributions and never goes negative" {
    assert reputation(0, 0).points == 0;
    assert reputation(3, 2).points == 36;
    assert reputation(3, 2).rank == "Regular";
    assert reputation(10, 0).rank == "Community spark";
    assert reputation(-5, -2).points == 0;
}
