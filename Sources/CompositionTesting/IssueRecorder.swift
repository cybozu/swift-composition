import Testing

package protocol IssueRecordable: Sendable {
    func record(_ message: String)
}

package enum IssueRecorder {
    @TaskLocal package static var current: any IssueRecordable = DefaultIssueRecorder()
}

private struct DefaultIssueRecorder: IssueRecordable {
    func record(_ message: String) {
        Issue.record(.init(rawValue: message))
    }
}
