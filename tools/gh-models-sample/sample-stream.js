import ModelClient, { isUnexpected } from "@azure-rest/ai-inference";
import { AzureKeyCredential } from "@azure/core-auth";

const token = process.env["GITHUB_TOKEN"];
if (!token) throw new Error("GITHUB_TOKEN env var is missing");

const endpoint = "https://models.github.ai/inference";
const model = "openai/gpt-4.1";

async function main() {
  const client = ModelClient(endpoint, new AzureKeyCredential(token));

  const response = await client.path("/chat/completions").post({
    body: {
      model,
      stream: true,
      messages: [
        { role: "system", content: "You are a helpful assistant for Afrotek." },
        { role: "user", content: "Give me 3 punchy Afrotek taglines, stream token by token." }
      ]
    },
    headers: { "Accept": "text/event-stream" }
  });

  if (isUnexpected(response)) throw response.body.error;

  // Some environments yield raw strings/bytes per chunk. We'll buffer and parse SSE lines.
  let buffer = "";
  let sawTokens = false;

  for await (const chunk of response.body) {
    // Normalize chunk to string
    const piece = typeof chunk === "string" ? chunk :
                  chunk?.toString?.() ?? String(chunk);
    buffer += piece;

    // Process complete SSE events separated by double newlines
    let idx;
    while ((idx = buffer.indexOf("\\n\\n")) !== -1) {
      const eventBlock = buffer.slice(0, idx);
      buffer = buffer.slice(idx + 2);

      // Extract all "data: ..." lines inside the block
      const dataLines = eventBlock.split("\\n").filter(l => l.startsWith("data:"));
      for (const line of dataLines) {
        const payload = line.slice(5).trim(); // remove "data:"
        if (!payload || payload === "[DONE]") continue;
        try {
          const obj = JSON.parse(payload);
          const delta = obj?.choices?.[0]?.delta?.content;
          const msg   = obj?.choices?.[0]?.message?.content;
          if (delta) { process.stdout.write(delta); sawTokens = true; }
          else if (msg) { process.stdout.write(msg); sawTokens = true; }
        } catch (e) { /* ignore partials / keep buffering */ }
      }
    }
  }

  if (!sawTokens) console.error("\\n(No tokens received. Model streamed control frames only.)");
  else process.stdout.write("\\n");
}

main().catch((err) => console.error("Streaming sample error:", err));
