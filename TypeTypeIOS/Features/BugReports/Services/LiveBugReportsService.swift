import Foundation

protocol LiveBugReportsServiceProtocol {
  func create(
    category: String,
    description: String,
    videoURL: String?
  ) async throws -> LiveCreatedBugReport
  func sendJournal(
    _ lines: [String],
    description: String,
    userAgent: String
  ) async throws -> LiveCreatedBugReport
  func reports(
    page: Int,
    limit: Int,
    status: String?,
    category: String?
  ) async throws -> LiveAdminBugReportsPage
  func detail(id: String) async throws -> LiveAdminBugReportDetail
  func updateStatus(id: String, status: String) async throws
  func createGitHubIssue(id: String) async throws -> URL
}

final class LiveBugReportsService: LiveBugReportsServiceProtocol {
  let apiClient: APIClient
  let diagnosticsStore: LiveDiagnosticsStore?
  let diagnosticScopeProvider: () -> LiveDiagnosticScope?

  init(
    apiClient: APIClient,
    diagnosticsStore: LiveDiagnosticsStore? = nil,
    diagnosticScopeProvider: @escaping () -> LiveDiagnosticScope? = {
      nil
    }
  ) {
    self.apiClient = apiClient
    self.diagnosticsStore = diagnosticsStore
    self.diagnosticScopeProvider = diagnosticScopeProvider
  }

  func reports(
    page: Int,
    limit: Int,
    status: String?,
    category: String?
  ) async throws -> LiveAdminBugReportsPage {
    var query = [
      URLQueryItem(name: "page", value: String(page)),
      URLQueryItem(name: "limit", value: String(limit)),
    ]
    status.map { query.append(URLQueryItem(name: "status", value: $0)) }
    category.map {
      query.append(URLQueryItem(name: "category", value: $0))
    }
    return try await apiClient.request(
      APIEndpoint(
        path: "/admin/bug-reports",
        method: .get,
        queryItems: query,
        requiresAuth: true
      ),
      as: LiveAdminBugReportsPage.self
    )
  }

  func detail(id: String) async throws -> LiveAdminBugReportDetail {
    try await apiClient.request(
      endpoint("/admin/bug-reports/\(id)", .get),
      as: LiveAdminBugReportDetail.self
    )
  }

  func updateStatus(id: String, status: String) async throws {
    _ = try await apiClient.request(
      endpoint(
        "/admin/bug-reports/\(id)/status",
        .put,
        body: try APIEndpoint.jsonBody(
          LiveBugReportStatusPayload(status: status)
        )
      ),
      as: LiveBugReportStatusResult.self
    )
  }

  func createGitHubIssue(id: String) async throws -> URL {
    let result = try await apiClient.request(
      endpoint("/admin/bug-reports/\(id)/github-issue", .post),
      as: LiveBugReportGitHubResult.self
    )
    return result.githubIssueURL
  }

  func endpoint(
    _ path: String,
    _ method: HTTPMethod,
    body: Data? = nil
  ) -> APIEndpoint {
    APIEndpoint(
      path: path,
      method: method,
      body: body,
      requiresAuth: true
    )
  }
}
