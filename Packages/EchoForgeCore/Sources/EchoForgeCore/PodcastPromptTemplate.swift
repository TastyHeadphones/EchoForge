import Foundation

public struct PodcastPromptTemplate: Sendable {
    public init() {}

    public static func makeNDJSONPrompt(
        topic: String,
        episodeCount: Int,
        hostAName: String,
        hostBName: String
    ) -> String {
        // IMPORTANT: The app incrementally decodes one JSON object per line.
        // Keep this prompt extremely explicit about formatting.
        return """
You are generating a multi-episode, two-host dialogue podcast script.

CRITICAL OUTPUT RULES:
- Output MUST be NDJSON: exactly one JSON object per line.
- Do NOT wrap the output in Markdown code fences.
- Do NOT emit any non-JSON text.
- Do NOT include literal newline characters inside string values.
- Use only ASCII characters.

SCHEMA (each line is ONE of these objects):
1) Project header (exactly once, first):
  {"type":"project","topic":string,"episode_count":int,"title":string,"description":string,
   "hosts":[{"id":"HOST_A","name":string,"persona":string},{"id":"HOST_B","name":string,"persona":string}]}

2) Episode header (once per episode, before any lines for that episode):
  {"type":"episode","episode_number":int,"title":string,"summary":string}

3) Dialogue line (many per episode):
  {"type":"line","episode_number":int,"speaker":"HOST_A"|"HOST_B","text":string}

4) Episode end marker (exactly once per episode):
  {"type":"episode_end","episode_number":int}

5) Done marker (exactly once at the end):
  {"type":"done"}

CONTENT REQUIREMENTS:
- Topic: \(topic)
- Total episodes: \(episodeCount)
- Host A name: \(hostAName)
- Host B name: \(hostBName)
- Make each episode meaningfully different: new angle, new examples, and a brief recap tying back to prior episodes.
- Two-person conversation: alternate speakers frequently (no long monologues).
- Keep language natural and podcast-like.

FORMAT REQUIREMENTS:
- Produce the project header FIRST.
- Then for episode_number 1..\(episodeCount) in order:
  - emit the episode header
  - emit 24 to 48 dialogue lines
  - emit episode_end
- Finally emit done.

Now start streaming NDJSON. Remember: ONE JSON OBJECT PER LINE.
"""
    }
}
