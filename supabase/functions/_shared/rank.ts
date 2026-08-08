// BM25 relevance ranking (Lucene-style) used to rerank news
// and web results against the user's idea text.

const STOPWORDS = new Set(
  ('a an and are as at be but by for from had has he her his i if in is it its ' +
   'of on or our she so that the their them then there they this to was we were ' +
   'will with you your about after also any because been before between both ' +
   'can could did do does during each few get had how just more most new not ' +
   'now other over own same should such than too under up very what when where ' +
   'which while who why would more').split(' '),
);

export function tokenize(text: string): string[] {
  return (text.toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .map((t) => t.trim())
    .filter((t) => t.length > 2 && !STOPWORDS.has(t)));
}

export function bm25Score(
  queryTokens: string[],
  docText: string,
  docFreq: Map<string, number>,
  totalDocs: number,
  avgDocLen: number,
): number {
  const k1 = 1.5;
  const b = 0.75;
  const terms = tokenize(docText);
  const termFreq = new Map<string, number>();
  for (const t of terms) termFreq.set(t, (termFreq.get(t) ?? 0) + 1);

  const docLen = terms.length;
  const norm = avgDocLen > 0 ? docLen / avgDocLen : 1;

  let score = 0;
  for (const q of queryTokens) {
    const tf = termFreq.get(q) ?? 0;
    if (tf === 0) continue;
    const df = docFreq.get(q) ?? 1;
    const idf = Math.log(1 + (totalDocs - df + 0.5) / (df + 0.5));
    score += idf * ((tf * (k1 + 1)) / (tf + k1 * (1 - b + b * norm)));
  }
  return score;
}
