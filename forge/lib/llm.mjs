// Model access. One real provider (Anthropic SDK) and one scripted mock that
// exercises the whole loop offline so the harness itself can be tested.
import Anthropic from "@anthropic-ai/sdk";
import { DEFAULTS } from "./config.mjs";

export function createProvider({ mock = false } = {}) {
  return mock ? mockProvider() : anthropicProvider();
}

function anthropicProvider() {
  const client = new Anthropic({ timeout: 20 * 60 * 1000 }); // long turns are normal on hard tasks
  return {
    name: "anthropic",
    async complete({ model, effort, system, messages, tools, maxTokens }) {
      const params = {
        model,
        max_tokens: maxTokens || DEFAULTS.maxTokensPerCall,
        system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
        messages,
        tools,
        thinking: { type: "adaptive" },
        output_config: { effort },
      };
      if (DEFAULTS.fallbacks) {
        params.betas = ["server-side-fallback-2026-07-01"];
        params.fallbacks = DEFAULTS.fallbacks;
      }
      let attempt = 0;
      for (;;) {
        try {
          const stream = client.beta.messages.stream(params);
          return await stream.finalMessage();
        } catch (err) {
          attempt++;
          if ((err instanceof Anthropic.RateLimitError || err instanceof Anthropic.InternalServerError || err instanceof Anthropic.APIConnectionError) && attempt <= 4) {
            await new Promise((r) => setTimeout(r, 2000 * 2 ** attempt));
            continue;
          }
          throw err;
        }
      }
    },
  };
}

// ---------------- mock ----------------
// Deterministic script: builder writes a broken game, verifier rejects it, the
// orchestrator records a lesson, tries to claim victory early (rejected), fixes
// the game, verifies, finishes. Enough to prove every guard in the harness.
export const MOCK_GAME_BROKEN = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Mock</title></head>
<body><div id="app"><h1>Mock game</h1><p id="score">0</p></div>
<script>
let state={score:0,over:false,turn:0};
window.GameAPI={name:"mock",reset(){state={score:0,over:false,turn:0};render();},getState(){return state;},
actions(){return state.over?[]:["left","right"];},act(a){state.turn++;state.score+= a==="left"?1:2;if(state.turn>=20)state.over=true;render();}};
function render(){document.getElementById("score").textContent=state.score;}
</script></body></html>`;

export const MOCK_GAME_FIXED = MOCK_GAME_BROKEN
  .replace('<div id="app">', '<div id="app" data-game-root>')
  .replace('act(a){state.turn++;', 'act(a){if(!this.actions().includes(a))throw new Error("invalid action "+a);state.turn++;');

function mockProvider() {
  const steps = new Map();
  const use = (name, input) => ({ type: "tool_use", id: `toolu_${Math.random().toString(36).slice(2, 10)}`, name, input });
  const msg = (content, stop) => ({ id: "msg_mock", model: "mock", role: "assistant", content, stop_reason: stop, usage: { input_tokens: 200, output_tokens: 80 } });
  return {
    name: "mock",
    async complete({ loopId, agentName, messages }) {
      const n = (steps.get(loopId) || 0) + 1;
      steps.set(loopId, n);
      const first = typeof messages[0].content === "string" ? messages[0].content : "";
      const slug = first.match(/Target slug:\s*([a-z0-9-]+)/)?.[1] || first.match(/games\/([a-z0-9-]+)\//)?.[1] || "mock-game";
      const last = messages[messages.length - 1];
      const lastResult = Array.isArray(last.content) && last.content[0]?.type === "tool_result" ? String(last.content[0].content) : "";

      if (agentName === "builder") {
        if (n === 1) return msg([use("write_file", { path: `games/${slug}/index.html`, content: MOCK_GAME_BROKEN })], "tool_use");
        return msg([{ type: "text", text: `Built games/${slug}/index.html. Did not verify (mock builder skips it to exercise the orchestrator).` }], "end_turn");
      }
      // orchestrator script
      switch (n) {
        case 1: return msg([use("query_knowledge", { query: "browser game contract GameAPI" })], "tool_use");
        case 2: return msg([use("spawn_agent", { name: "level-designer", role: "Designs difficulty curves and level layouts", system: "You design levels. Return a JSON layout plan.", tools: ["read_file", "query_knowledge"] })], "tool_use");
        case 3: return msg([use("delegate", { agent: "builder", task: `Build a minimal game at games/${slug}/index.html per the contract.` })], "tool_use");
        case 4: return msg([use("verify_game", { slug })], "tool_use");
        case 5: return msg([use("record_lesson", { summary: "Verifier requires data-game-root and act() must throw on invalid ids", detail: `Verification failed with: ${lastResult.slice(0, 300)}. Fix: add data-game-root to the root element and validate action ids inside act().`, tags: ["contract", "verifier", "gameapi"] })], "tool_use");
        case 6: return msg([use("finish_mission", { status: "verified", slug, report: "Premature claim to test the harness guard." })], "tool_use");
        case 7: return msg([use("write_file", { path: `games/${slug}/index.html`, content: MOCK_GAME_FIXED })], "tool_use");
        case 8: return msg([use("verify_game", { slug })], "tool_use");
        case 9: return msg([use("send_to_user", { message: `Mock mission for ${slug}: verifier passed after 1 fix; 1 lesson stored; 1 agent spawned.` })], "tool_use");
        case 10: return msg([use("finish_mission", { status: "verified", slug, report: `games/${slug}/index.html passes the verifier. Lesson recorded about the contract.` })], "tool_use");
        default: return msg([{ type: "text", text: "Mock script exhausted." }], "end_turn");
      }
    },
  };
}
