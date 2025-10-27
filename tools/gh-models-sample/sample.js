import ModelClient, { isUnexpected } from "@azure-rest/ai-inference";
import { AzureKeyCredential } from "@azure/core-auth";

const token = process.env["GITHUB_TOKEN"];
if (!token) throw new Error("GITHUB_TOKEN env var is missing");

const endpoint = "https://models.github.ai/inference";
// GitHub-hosted model example:
const model = "openai/gpt-4o";
// For external providers you’ve configured in GitHub:  model = "custom/<key_id>/<model_id>"

export async function main() {
  const client = ModelClient(endpoint, new AzureKeyCredential(token));

  const response = await client.path("/chat/completions").post({
    body: {
      messages: [
        { role: "system", content: "You are a helpful assistant." },
        { role: "user", content: "What is the capital of France?" }
      ],
      model
    }
  });

  if (isUnexpected(response)) throw response.body.error;

  console.log(response.body.choices[0].message.content);
}

main().catch((err) => {
  console.error("The sample encountered an error:", err);
});
