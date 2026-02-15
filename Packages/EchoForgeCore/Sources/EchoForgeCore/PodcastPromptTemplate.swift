import Foundation

public struct PodcastPromptTemplate: Sendable {
    public init() {}

    public struct Episodes: Sendable, Equatable {
        public var total: Int
        public var range: ClosedRange<Int>

        public init(total: Int, range: ClosedRange<Int>) {
            self.total = total
            self.range = range
        }
    }

    public struct Hosts: Sendable, Equatable {
        public var hostAName: String
        public var hostBName: String

        public init(hostAName: String, hostBName: String) {
            self.hostAName = hostAName
            self.hostBName = hostBName
        }
    }

    public struct Options: Sendable, Equatable {
        public var includeProjectHeader: Bool
        public var includeDoneMarker: Bool
        public var priorEpisodesRecap: String?
        public var projectTitle: String?

        public init(
            includeProjectHeader: Bool = true,
            includeDoneMarker: Bool = true,
            priorEpisodesRecap: String? = nil,
            projectTitle: String? = nil
        ) {
            self.includeProjectHeader = includeProjectHeader
            self.includeDoneMarker = includeDoneMarker
            self.priorEpisodesRecap = priorEpisodesRecap
            self.projectTitle = projectTitle
        }
    }

    public static func makeNDJSONPrompt(
        topic: String,
        episodeCount: Int,
        hostAName: String,
        hostBName: String
    ) -> String {
        makeNDJSONPrompt(
            topic: topic,
            episodes: Episodes(total: episodeCount, range: 1...episodeCount),
            hosts: Hosts(hostAName: hostAName, hostBName: hostBName),
            options: Options()
        )
    }

    public static func makeNDJSONPrompt(
        topic: String,
        episodes: Episodes,
        hosts: Hosts,
        options: Options = Options()
    ) -> String {
        // IMPORTANT: The app incrementally decodes one JSON object per line.
        // Keep this prompt extremely explicit about formatting.
        let contentSection = makeContentSection(topic: topic, episodes: episodes, hosts: hosts, options: options)
        let formatSection = makeFormatSection(episodes: episodes, options: options)

        return [
            introSection,
            schemaSection,
            contentSection,
            formatSection,
            outroSection
        ]
        .joined(separator: "\n\n")
    }

    private static let introSection: String = """
You are generating a multi-episode, two-host dialogue podcast script.

CRITICAL OUTPUT RULES:
- Output MUST be NDJSON: exactly one JSON object per line.
- Do NOT wrap the output in Markdown code fences.
- Do NOT emit any non-JSON text.
- Do NOT include literal newline characters inside string values.
- Use only ASCII characters.
"""

    private static let schemaSection: String = """
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
"""

    private static let outroSection: String = """
Now start streaming NDJSON. Remember: ONE JSON OBJECT PER LINE.
"""

    private static func makeContentSection(
        topic: String,
        episodes: Episodes,
        hosts: Hosts,
        options: Options
    ) -> String {
        let startEpisode = episodes.range.lowerBound
        let endEpisode = episodes.range.upperBound

        let recapSection = makePriorEpisodeRecapSection(startEpisode: startEpisode, recap: options.priorEpisodesRecap)
        let titleSection = makeProjectTitleSection(title: options.projectTitle)

        return """
CONTENT REQUIREMENTS:
- Topic: \(topic)
- Project title: \(titleSection)
- Total episodes: \(episodes.total)
- Generate ONLY episodes \(startEpisode) through \(endEpisode) (inclusive), and no other episode numbers.
- Host A name: \(hosts.hostAName)
- Host B name: \(hosts.hostBName)
- Make each episode meaningfully different: new angle, new examples, and a brief recap tying back to prior episodes.
- Two-person conversation: alternate speakers frequently (no long monologues).
- Keep language natural and podcast-like.
- Each episode should be long-form: target at least 20 minutes of spoken dialogue.
\(recapSection)
"""
    }

    private static func makeFormatSection(episodes: Episodes, options: Options) -> String {
        let startEpisode = episodes.range.lowerBound
        let endEpisode = episodes.range.upperBound

        let projectHeaderRequirement = options.includeProjectHeader
            ? "- Produce the project header FIRST."
            : "- Do NOT emit a project header in this request."

        let doneMarkerRequirement = options.includeDoneMarker
            ? "- After the final episode_end, emit done."
            : "- Do NOT emit done in this request."

        return """
FORMAT REQUIREMENTS:
- For this request:
\(projectHeaderRequirement)
\(doneMarkerRequirement)
- Then for episode_number \(startEpisode)..\(endEpisode) in order:
  - emit the episode header
  - emit 160 to 240 dialogue lines (enough for at least ~20 minutes of spoken audio)
  - emit episode_end
"""
    }

    private static func makePriorEpisodeRecapSection(startEpisode: Int, recap: String?) -> String {
        let trimmed = recap?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "" }

        let upper = startEpisode - 1
        let rangeText = upper >= 1 ? "1..\(upper)" : "none"

        return """

PRIOR EPISODES (for continuity; do not contradict; do not invent new facts):
- These are episodes \(rangeText) summaries.
\(trimmed)
"""
    }

    private static func makeProjectTitleSection(title: String?) -> String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return "Generate a good title."
        }
        return "Use exactly this title in the project header: \"\(trimmed)\"."
    }
}
