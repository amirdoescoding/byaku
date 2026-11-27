/** Star count at BUILD time. The page never calls GitHub from the browser. Offline, private repo or rate-limited: null. */
export async function getStars(): Promise<number | null> {
  try {
    const r = await fetch('https://api.github.com/repos/amirdoescoding/byaku', {
      headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'byaku-site-build' },
      signal: AbortSignal.timeout(5000),
    });
    if (!r.ok) return null;
    const n = ((await r.json()) as { stargazers_count?: unknown }).stargazers_count;
    return typeof n === 'number' ? n : null;
  } catch {
    return null;
  }
}
