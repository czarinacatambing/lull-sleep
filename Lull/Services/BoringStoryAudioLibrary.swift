import Foundation

enum BoringStoryAudioLibrary {
    private static let nextIndexKey = "boringStoryNextAudioIndex"
    private static let stories = [
        "boring-story-01",
        "boring-story-02",
    ]

    static func nextStoryURL() -> URL? {
        guard !stories.isEmpty else { return nil }

        let defaults = UserDefaults.standard
        let storedIndex = defaults.object(forKey: nextIndexKey) as? Int ?? 0
        let index = ((storedIndex % stories.count) + stories.count) % stories.count
        defaults.set((index + 1) % stories.count, forKey: nextIndexKey)

        return Bundle.main.url(forResource: stories[index], withExtension: "mp3")
    }
}
