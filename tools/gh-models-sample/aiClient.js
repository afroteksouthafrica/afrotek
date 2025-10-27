import ModelClient, { isUnexpected } from "@azure-rest/ai-inference";
import { AzureKeyCredential } from "@azure/core-auth";

const DEFAULT_ENDPOINT = "https://models.github.ai/inference";

export function createAiClient({
  token = process.env.GITHUB_TOKEN,
  endpoint = DEFAULT_ENDPOINT,
  model = "openai/gpt-4o"
} = {}) {
  if (!token) throw new Error("GITHUB_TOKEN env var is missing");

  const client = ModelClient(endpoint, new AzureKeyCredential(token));

  async function chat(messages, opts = {}) {
    const body = {
      messages,
      model: opts.model || model,
      temperature: opts.temperature ?? 0.2,
      max_tokens: opts.max_tokens ?? 4000,
      stream: opts.stream ?? false
    };

    return withRetry(async () => {
      const res = await client.path("/chat/completions").post({ body });
      if (isUnexpected(res)) throw decorateError(res);
      return res.body;
    });
  }

  return { chat };
}

function decorateError(res) {
  const err = res?.body?.error ?? { message: "Unexpected response" };
  err.status = res.status;
  err.headers = res.headers;
  return err;
}

async function withRetry(fn, { retries = 5, baseDelayMs = 500 } = {}) {
  let attempt = 0;
  // Simple exponential backoff honoring Retry-After if present
  // (429/503 are common for rate limits/transient issues)
  while (true) {
    try {
      return await fn();
    } catch (e) {
      const status = e?.status;
      const retryAfterHeader = e?.headers?.get?.("retry-after");
      const shouldRetry = status === 429 || status === 503 || status === 500;

      if (!shouldRetry || attempt >= retries) throw e;

      const jitter = Math.random() * 200;
      const retryAfterMs = retryAfterHeader
        ? Number(retryAfterHeader) * 1000
        : (2 ** attempt) * baseDelayMs + jitter;

      await new Promise((r) => setTimeout(r, retryAfterMs));
      attempt++;
    }
  }
}
