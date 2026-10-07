export async function load() {
  const { who } = await import("./dynref/leaf.fixture.mjs");   // relative to THIS module's dir
  return who() + " via " + import.meta.url.split("/").slice(-1)[0];
}
