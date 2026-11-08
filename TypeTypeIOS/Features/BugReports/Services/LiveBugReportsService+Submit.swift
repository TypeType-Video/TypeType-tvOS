import Foundation

extension LiveBugReportsService {
  func create(
    category: String,
    description: String,
    videoURL: String?
  ) async throws -> LiveCreatedBugReport {
    try await submit(
      category: category,
      description: description,
      videoURL: videoURL,
      route: "ios://report",
      userAgent: "TypeType iOS",
      crashLogs: []
    )
  }

  func sendJournal(
    _ lines: [String],
    description: String,
    userAgent: String
  ) async throws -> LiveCreatedBugReport {
    let now = Int64(Date().timeIntervalSince1970 * 1_000)
    let chunks = stride(from: 0, to: lines.count, by: 20).map {
      Array(lines[$0..<min($0 + 20, lines.count)])
    }
    let logs = chunks.suffix(200).map { chunk in
      LiveBugCrashLog(
        message: chunk.first ?? "",
        stack: chunk.joined(separator: "\n"),
        timestamp: now
      )
    }
    return try await submit(
      category: "functionality",
      description: description,
      videoURL: nil,
      route: "tvos://journal",
      userAgent: userAgent,
      crashLogs: logs
    )
  }

  private func submit(
    category: String,
    description: String,
    videoURL: String?,
    route: String,
    userAgent: String,
    crashLogs: [LiveBugCrashLog]
  ) async throws -> LiveCreatedBugReport {
    let diagnostics: [LiveDiagnosticEntry]
    if let diagnosticsStore,
      let scope = diagnosticScopeProvider() {
      diagnostics = await diagnosticsStore.entries(for: scope)
    } else {
      diagnostics = []
    }
    let context = LiveBugReportContextPayload(
      videoURL: videoURL,
      route: route,
      timestamp: Int64(Date().timeIntervalSince1970 * 1_000),
      userAgent: userAgent,
      browserLanguage: Locale.current.identifier,
      crashLogs: crashLogs,
      apiErrors: diagnostics.compactMap { entry in
        guard let status = entry.statusCode, status >= 400 else {
          return nil
        }
        return LiveBugAPIError(
          requestID: entry.requestID,
          endpoint: entry.route,
          status: status,
          code: nil,
          message: nil,
          timestamp: Int64(
            entry.timestamp.timeIntervalSince1970 * 1_000
          )
        )
      }
      .prefix(100)
      .map { $0 }
    )
    return try await apiClient.request(
      endpoint(
        "/bug-reports",
        .post,
        body: try APIEndpoint.jsonBody(
          LiveCreateBugReportPayload(
            category: category,
            description: description,
            context: context
          )
        )
      ),
      as: LiveCreatedBugReport.self
    )
  }
}
