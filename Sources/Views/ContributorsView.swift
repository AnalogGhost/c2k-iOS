import SwiftUI

private struct Contributor {
    let name: String
    let github: String?
    let fediverse: String?
    let contributions: [String]
}

// Only contributors whose actual work is present in this codebase are listed here. Android
// additionally credits Andrew Farabee (TTS ducking, completion-announcement cutoff) and
// Hamza Bilen (manual language selection) — the iOS bugs were fixed independently and the
// iOS language picker is a fresh implementation, so neither is carried over. Ahmet Emre's
// Turkish translation *is* used here (ported from the Android repo), so he is credited.
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
    Contributor(
        name: "Ahmet Emre",
        github: "ahmetemrew",
        fediverse: nil,
        contributions: [String(localized: "Turkish (tr) translation")]
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
