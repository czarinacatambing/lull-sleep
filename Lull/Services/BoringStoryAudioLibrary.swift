import Foundation
import SwiftUI

enum BoringStoryId: String, Codable, CaseIterable, Identifiable {
    case boringStory01 = "boring-story-01"
    case inCaptivity = "in captivity"
    case naturalHistoryLetters1To6 = "Natural History of Selborne - letters 1-6"
    case naturalHistoryLetters7To13 = "Natural History of Selborne - letters 7-13"
    case rulesOfEastAndWest = "rules of east and west"

    var id: String { rawValue }

    var title: String { rawValue }

    var fileExtension: String {
        switch self {
        case .boringStory01:
            return "mp3"
        case .inCaptivity, .naturalHistoryLetters1To6, .naturalHistoryLetters7To13, .rulesOfEastAndWest:
            return "m4a"
        }
    }

    var durationSeconds: Int {
        switch self {
        case .boringStory01:
            return 626
        case .inCaptivity:
            return 1503
        case .naturalHistoryLetters1To6:
            return 2136
        case .naturalHistoryLetters7To13:
            return 2471
        case .rulesOfEastAndWest:
            return 2417
        }
    }

    var durationText: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return seconds == 0 ? "\(minutes)m" : "\(minutes)m \(String(format: "%02d", seconds))s"
    }
}

struct BoringStoryStepConfig: Codable, Equatable {
    var storyId: BoringStoryId

    static let fresh = BoringStoryStepConfig(storyId: .boringStory01)

    var title: String { storyId.title }
    var durationSummary: String { storyId.durationText }
}

struct BoringStoryAudioAsset {
    var story: BoringStoryId
    var url: URL
}

enum BoringStoryAudioLibrary {
    private static let nextIndexKey = "boringStoryNextAudioIndex"
    private static let stories = BoringStoryId.allCases

    static func asset(for config: BoringStoryStepConfig) -> BoringStoryAudioAsset? {
        asset(for: config.storyId)
    }

    static func asset(for story: BoringStoryId) -> BoringStoryAudioAsset? {
        guard let url = Bundle.main.url(forResource: story.rawValue, withExtension: story.fileExtension) else {
            return nil
        }
        return BoringStoryAudioAsset(story: story, url: url)
    }

    static func nextStoryURL() -> URL? {
        nextStoryAsset()?.url
    }

    static func nextStoryAsset() -> BoringStoryAudioAsset? {
        guard !stories.isEmpty else { return nil }

        let defaults = UserDefaults.standard
        let storedIndex = defaults.object(forKey: nextIndexKey) as? Int ?? 0
        let index = ((storedIndex % stories.count) + stories.count) % stories.count
        defaults.set((index + 1) % stories.count, forKey: nextIndexKey)

        return asset(for: stories[index])
    }

    static func randomStoryAsset(excluding excluded: BoringStoryId? = nil) -> BoringStoryAudioAsset? {
        guard !stories.isEmpty else { return nil }

        let pool = stories.filter { $0 != excluded }
        let picked = (pool.isEmpty ? stories : pool).randomElement() ?? stories[0]
        return asset(for: picked)
    }
}

private enum BoringStoryPalette {
    static let bg = Color.black
    static let card = Color.white.opacity(0.045)
    static let line = Color.lullLine
    static let lineHi = Color.lullLineStrong
    static let text = Color(red: 245 / 255, green: 232 / 255, blue: 210 / 255).opacity(0.96)
    static let textDim = Color(red: 245 / 255, green: 232 / 255, blue: 210 / 255).opacity(0.55)
    static let textFaint = Color(red: 245 / 255, green: 232 / 255, blue: 210 / 255).opacity(0.35)
    static let accent = Color(hex: "#E8B87A")
    static let accentDeep = Color(hex: "#C99356")
    static let accentSoft = Color(hex: "#E8B87A").opacity(0.14)
}

struct BoringStoryStep: View {
    var initial: BoringStoryStepConfig = .fresh
    var onSave: (BoringStoryStepConfig) -> Void
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var config: BoringStoryStepConfig

    init(
        initial: BoringStoryStepConfig = .fresh,
        onSave: @escaping (BoringStoryStepConfig) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initial = initial
        self.onSave = onSave
        self.onDismiss = onDismiss
        _config = State(initialValue: initial)
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            let bottomPadding = max(proxy.safeAreaInsets.bottom + 18, 104)

            ZStack {
                BoringStoryPalette.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header(compact: compact)

                    VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                        Text("BORING STORY")
                            .font(.system(size: 11.5, weight: .medium))
                            .tracking(0.92)
                            .foregroundColor(BoringStoryPalette.accent)
                        Text("Story to drift off to")
                            .font(.serif(compact ? 22 : 24))
                            .foregroundColor(BoringStoryPalette.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, compact ? 6 : 14)
                    .padding(.bottom, compact ? 8 : 14)

                    storyList(compact: compact)
                        .padding(.horizontal, 16)

                    selectedDurationCard(compact: compact)
                        .padding(.horizontal, 16)
                        .padding(.top, compact ? 8 : 14)

                    Spacer(minLength: compact ? 4 : 14)

                    Button(action: primaryAction) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Capsule().fill(BoringStoryPalette.accent))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomPadding)
                }
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: reduceMotion ? 0.18 : 0.28), value: config.storyId)
    }

    private func header(compact: Bool) -> some View {
        HStack {
            Text("EDIT STEP")
                .font(.system(size: 13, weight: .medium))
                .tracking(0.52)
                .foregroundColor(BoringStoryPalette.textFaint)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(BoringStoryPalette.textDim)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .overlay(Circle().strokeBorder(BoringStoryPalette.line, lineWidth: 1))
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, compact ? 40 : 52)
        .padding(.bottom, compact ? 4 : 8)
    }

    private func storyList(compact: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(BoringStoryId.allCases.enumerated()), id: \.element) { index, story in
                BoringStoryRow(
                    story: story,
                    selected: config.storyId == story,
                    compact: compact,
                    isLast: index == BoringStoryId.allCases.count - 1,
                    onSelect: { config.storyId = story }
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(BoringStoryPalette.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(BoringStoryPalette.line, lineWidth: 1))
        )
    }

    private func selectedDurationCard(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Duration")
                    .font(.system(size: compact ? 12.5 : 13, weight: .medium))
                    .foregroundColor(BoringStoryPalette.textDim)
                Spacer()
                Text(config.durationSummary)
                    .font(.serif(compact ? 24 : 28))
                    .foregroundColor(BoringStoryPalette.accent)
                    .monospacedDigit()
            }

            Text(config.title)
                .font(.system(size: compact ? 12.5 : 13.5, weight: .medium))
                .foregroundColor(BoringStoryPalette.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(compact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(BoringStoryPalette.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(BoringStoryPalette.line, lineWidth: 1))
        )
    }

    private func primaryAction() {
        onSave(config)
    }
}

private struct BoringStoryRow: View {
    var story: BoringStoryId
    var selected: Bool
    var compact: Bool
    var isLast: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? BoringStoryPalette.accentSoft : Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? BoringStoryPalette.accent.opacity(0.35) : BoringStoryPalette.line, lineWidth: 1))
                    Image(systemName: "book.closed")
                        .font(.system(size: compact ? 14 : 16, weight: .regular))
                        .foregroundColor(selected ? BoringStoryPalette.accent : BoringStoryPalette.textDim)
                }
                .frame(width: compact ? 30 : 34, height: compact ? 30 : 34)

                Text(story.title)
                    .font(.system(size: compact ? 14 : 15, weight: .medium))
                    .foregroundColor(BoringStoryPalette.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(story.durationText)
                    .font(.mono(compact ? 10.5 : 11))
                    .kerning(0.8)
                    .foregroundColor(selected ? BoringStoryPalette.accent : BoringStoryPalette.textDim)
                    .monospacedDigit()
                    .frame(minWidth: compact ? 58 : 66, alignment: .trailing)

                BoringStoryRadioDot(selected: selected)
            }
            .frame(minHeight: compact ? 46 : 54)
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .background(selected ? BoringStoryPalette.accentSoft : Color.clear)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(BoringStoryPalette.line)
                        .frame(height: 1)
                        .padding(.leading, 64)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(story.title), \(story.durationText), \(selected ? "selected" : "not selected")")
    }
}

private struct BoringStoryRadioDot: View {
    var selected: Bool

    var body: some View {
        Circle()
            .strokeBorder(selected ? BoringStoryPalette.accent : BoringStoryPalette.lineHi, lineWidth: 1.5)
            .background(
                Circle()
                    .fill(selected ? BoringStoryPalette.accentSoft : Color.clear)
                    .overlay {
                        if selected {
                            Circle()
                                .fill(BoringStoryPalette.accent)
                                .frame(width: 10, height: 10)
                        }
                    }
            )
            .frame(width: 22, height: 22)
    }
}
