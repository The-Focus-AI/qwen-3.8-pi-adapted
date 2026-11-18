/**
 * examples/chat — interactive CLI that streams tokens from a
 * llama.cpp OpenAI-compatible server (default: http://127.0.0.1:9931/v1).
 *
 * Run:  bun run index.ts
 */

import * as readline from "node:readline";

const BASE_URL = process.env.LLAMA_BASE_URL ?? "http://127.0.0.1:9931/v1";
const MODEL = process.env.LLAMA_MODEL ?? "default";
const API_KEY = process.env.LLAMA_API_KEY ?? "dummy";

const SYSTEM_PROMPT =
  "You are a helpful assistant. Keep answers concise.";

interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

/**
 * Line reader over stdin that works for both interactive (TTY) and piped input.
 * Lines are buffered as they arrive; `next()` resolves with the next line or
 * `null` on EOF.
 */
function createLineReader() {
  const rl = readline.createInterface({
    input: process.stdin,
    terminal: process.stdin.isTTY === true,
  });
  const queue: string[] = [];
  let waiters: Array<(line: string | null) => void> = [];
  let eof = false;

  rl.on("line", (line) => {
    const w = waiters.shift();
    if (w) w(line);
    else queue.push(line);
  });
  rl.on("close", () => {
    eof = true;
    for (const w of waiters.splice(0)) w(null);
  });

  return {
    next: (): Promise<string | null> =>
      new Promise((resolve) => {
        if (queue.length) return resolve(queue.shift()!);
        if (eof) return resolve(null);
        waiters.push(resolve);
      }),
    close: () => rl.close(),
  };
}

/**
 * Send a chat completion request with streaming enabled.
 * Yields each assistant text delta as it arrives.
 * Resolves with the full assembled text.
 */
async function* streamChat(
  messages: ChatMessage[],
  signal: AbortSignal,
): AsyncGenerator<string, string, void> {
  const res = await fetch(`${BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(API_KEY ? { Authorization: `Bearer ${API_KEY}` } : {}),
    },
    body: JSON.stringify({
      model: MODEL,
      messages,
      stream: true,
    }),
    signal,
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Server error ${res.status}: ${body || res.statusText}`);
  }
  if (!res.body) throw new Error("Empty response body");

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let full = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });

      // SSE frames are separated by blank lines.
      let sep: number;
      while ((sep = buffer.indexOf("\n\n")) !== -1) {
        const frame = buffer.slice(0, sep);
        buffer = buffer.slice(sep + 2);

        const dataLine = frame
          .split("\n")
          .find((l) => l.startsWith("data:"));
        if (!dataLine) continue;
        const payload = dataLine.slice(5).trim();
        if (payload === "[DONE]") continue;

        try {
          const json = JSON.parse(payload);
          const delta: string | undefined = json.choices?.[0]?.delta?.content;
          if (delta) {
            full += delta;
            yield delta;
          }
        } catch {
          // ignore malformed frame
        }
      }
    }
  } finally {
    reader.releaseLock();
  }
  return full;
}

async function main(): Promise<void> {
  const lines = createLineReader();
  const isTTY = process.stdin.isTTY === true;
  const history: ChatMessage[] = [{ role: "system", content: SYSTEM_PROMPT }];

  if (isTTY) {
    console.log("🤖 Chat with llama.cpp server");
    console.log(`   ${BASE_URL}  (model: ${MODEL})`);
    console.log("   Type a message and press Enter.  /exit or Ctrl-D to quit.\n");
  }

  while (true) {
    if (isTTY) process.stdout.write("you> ");
    const input = (await lines.next())?.trim() ?? null;
    if (input === null) break; // EOF / Ctrl-D
    if (input === "/exit" || input === "/quit") break;
    if (input.length === 0) continue;

    history.push({ role: "user", content: input });
    process.stdout.write("\nassistant> ");

    const controller = new AbortController();
    let first = true;
    let assistantText = "";
    try {
      for await (const token of streamChat(history, controller.signal)) {
        process.stdout.write(token);
        assistantText += token;
        first = false;
      }
      if (first) {
        console.log("(empty response)");
      } else {
        console.log();
      }
      history.push({ role: "assistant", content: assistantText });
    } catch (err: any) {
      if (err?.name === "AbortError") {
        console.log("\n[interrupted]");
      } else {
        console.error(`\nerror: ${err?.message ?? err}`);
      }
      // drop the failed user turn so history stays consistent
      history.pop();
    }
  }

  lines.close();
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
