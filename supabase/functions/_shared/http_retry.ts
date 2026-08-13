// Shared retry helper for Tavily/Gemini calls. Only retries transient
// failures (rate limits and server-side hiccups) — a real 401/403/400
// means retrying won't help and just burns another unit of a limited quota,
// so those fail immediately.
const RETRYABLE_STATUS = new Set([429, 500, 502, 503, 504]);

export async function fetchWithRetry(
  url: string,
  init: RequestInit,
  { retries = 1, delayMs = 2000 }: { retries?: number; delayMs?: number } = {},
): Promise<Response> {
  let lastRes: Response | undefined;
  for (let attempt = 0; attempt <= retries; attempt++) {
    const res = await fetch(url, init);
    if (res.ok || !RETRYABLE_STATUS.has(res.status)) return res;
    lastRes = res;
    if (attempt < retries) await new Promise((r) => setTimeout(r, delayMs));
  }
  return lastRes!;
}
