import Foundation

enum AppGroupConfiguration {
    static let identifier = "group.com.samuelgiles.BinsOut"

    static func containerURL(fileManager: FileManager = .default) -> URL {
        if let sharedURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) {
            return sharedURL
        }

        // Keeps previews and unsigned simulator tests usable. Signed app and widget
        // builds must resolve the App Group container before system features ship.
        return URL.applicationSupportDirectory
            .appending(path: "BinsOut", directoryHint: .isDirectory)
    }
}
