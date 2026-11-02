impl artifact_mtime(path: Path) -> float {
    return float(path.stat().st_mtime);
}
