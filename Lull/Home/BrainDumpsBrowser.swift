import AVFoundation
import SwiftUI
import UIKit

// Lists every brain dump recording in the app sandbox (Documents/brain_dumps/),
// regardless of whether AppState has a SleepLogEntry referencing it. This is
// the source of truth for "what's actually on the phone."
struct BrainDumpsBrowser: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = BrainDumpsListModel()
    @StateObject private var playback = AudioPlaybackService()
    @State private var playingURL: URL?
    @State private var shareItem: ShareableURL?

    var body: some View {
        NavigationStack {
            Group {
                if model.recordings.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Brain Dumps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { model.reload() }
        .onDisappear { playback.stop(); playingURL = nil }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.slash")
                .font(.system(size: 28))
                .foregroundColor(.lullInk3)
            Text("No brain dumps yet.")
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.lullInk3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            ForEach(model.recordings) { rec in
                BrainDumpRow(
                    recording: rec,
                    isPlaying: playingURL == rec.id && playback.isPlaying,
                    progress: playingURL == rec.id ? playback.progress : 0,
                    onTogglePlay: { togglePlay(rec) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        delete(rec)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        shareItem = ShareableURL(url: rec.id)
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.up")
                    }
                    .tint(.lullAmber)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { model.reload() }
    }

    private func togglePlay(_ rec: BrainDumpsListModel.Recording) {
        if playingURL == rec.id && playback.isPlaying {
            playback.pause()
            return
        }
        playback.stop()
        playback.load(url: rec.id)
        playback.play()
        playingURL = rec.id
    }

    private func delete(_ rec: BrainDumpsListModel.Recording) {
        if playingURL == rec.id {
            playback.stop()
            playingURL = nil
        }
        model.delete(rec)
        state.clearBrainDumpReference(forFileAt: rec.id)
    }
}

// MARK: - Row

private struct BrainDumpRow: View {
    let recording: BrainDumpsListModel.Recording
    let isPlaying: Bool
    let progress: Double
    let onTogglePlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.displayDate)
                    .font(.system(.body))
                    .foregroundColor(.lullInk0)
                Text(recording.durationLabel)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.lullInk3)
                if isPlaying {
                    ProgressView(value: progress)
                        .tint(.lullAmber)
                        .frame(height: 2)
                        .padding(.top, 2)
                }
            }
            Spacer()
            Button(action: onTogglePlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.lullAmber)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - List model

@MainActor
final class BrainDumpsListModel: ObservableObject {
    struct Recording: Identifiable, Hashable {
        let id: URL
        let date: Date
        let displayDate: String
        let durationSec: Int

        var durationLabel: String {
            if durationSec <= 0 { return "—" }
            let m = durationSec / 60
            let s = durationSec % 60
            return "\(m)m \(s)s"
        }
    }

    @Published private(set) var recordings: [Recording] = []

    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    func reload() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("brain_dumps", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            recordings = []
            return
        }

        let m4as = contents.filter { $0.pathExtension.lowercased() == "m4a" }
        var built: [Recording] = []
        built.reserveCapacity(m4as.count)

        for url in m4as {
            let stem = url.deletingPathExtension().lastPathComponent
            let date: Date = {
                if stem.hasPrefix("braindump_"),
                   let parsed = Self.isoDay.date(from: String(stem.dropFirst("braindump_".count))) {
                    return parsed
                }
                if let created = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate {
                    return created
                }
                return Date.distantPast
            }()
            let durationSec: Int = {
                guard let player = try? AVAudioPlayer(contentsOf: url) else { return 0 }
                return Int(player.duration.rounded())
            }()
            built.append(Recording(
                id: url,
                date: date,
                displayDate: Self.displayFormatter.string(from: date),
                durationSec: durationSec
            ))
        }

        built.sort { $0.date > $1.date }
        recordings = built
    }

    func delete(_ recording: Recording) {
        try? FileManager.default.removeItem(at: recording.id)
        reload()
    }
}

// MARK: - Share sheet helper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

private struct ShareableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
