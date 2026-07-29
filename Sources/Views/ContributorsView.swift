import SwiftUI

private struct Contributor {
    let name: String
    let github: String?
    let fediverse: String?
    let contributions: [String]
}

// Only contributors whose actual work is present in this codebase are listed here. Android
// additionally credits Andrew Farabee for two bug fixes (TTS ducking, completion-announcement
// cutoff) — those iOS bugs were fixed independently in this codebase, not ported from his
// Android commits, so his credit isn't carried over.
private let contributors: [Contributor] = [
    Contributor(
        name: "xmgz",
        github: "xmgz",
        fediverse: "@l10n@gts.xmgz.eu",
        contributions: [String(localized: "Spanish (es) translation"), String(localized: "Galician (gl) translation")]
    ),
    Contributor(
        name: "Ilyushenok Ilya",
        github: "ilyushenok",
        fediverse: nil,
        contributions: [String(localized: "Russian (ru) translation")]
    ),
]

struct ContributorsView: View {
    var body: some View {
        List {
            ForEach(contributors, id: \.name) { contributor in
                ContributorCard(contributor: contributor)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Contributors")
    }
}

private struct ContributorCard: View {
    let contributor: Contributor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(contributor.name)
                .font(.headline)
            if let github = contributor.github {
                HandleRow(label: String(localized: "GitHub"), value: github)
            }
            if let fediverse = contributor.fediverse {
                HandleRow(label: String(localized: "Fediverse"), value: fediverse)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(contributor.contributions.enumerated()), id: \.offset) { index, text in
                    if index > 0 {
                        Divider()
                    }
                    Text(text)
                        .font(.body)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.background.secondary))
    }
}

private struct HandleRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text("\(label):")
            Text(value)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
