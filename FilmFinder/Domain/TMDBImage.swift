import Foundation

enum TMDBImage {
    static func poster(_ path: String?) -> URL? { url(size: "w500", path) }
    static func backdrop(_ path: String?) -> URL? { url(size: "w780", path) }
    static func logo(_ path: String?) -> URL? { url(size: "w92", path) }

    private static func url(size: String, _ path: String?) -> URL? {
        guard let path, path.hasPrefix("/") else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}
