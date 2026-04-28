import Foundation

extension FileManager {
    var demoLensRecordingsDirectory: URL {
        let movies = urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Movies", isDirectory: true)
        return movies.appendingPathComponent("DemoLens", isDirectory: true)
    }

    func makeDemoLensRecordingURL(date: Date = Date()) throws -> URL {
        let directory = demoLensRecordingsDirectory
        try createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let baseName = "DemoLens-\(formatter.string(from: date))"
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension("mov")
        var index = 2
        while fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)-\(index)").appendingPathExtension("mov")
            index += 1
        }
        return candidate
    }
}
