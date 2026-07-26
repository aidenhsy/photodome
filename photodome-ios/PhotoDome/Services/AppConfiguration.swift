import Foundation

enum AppConfiguration {
    static var apiBaseURL: URL {
        let configured =
            Bundle.main.object(
                forInfoDictionaryKey: "PhotoDomeAPIBaseURL"
            ) as? String
        #if DEBUG
            return try! validatedAPIBaseURL(
                configured,
                defaultValue: "http://127.0.0.1:3000",
                allowsInsecureLocalhost: true
            )
        #else
            return try! validatedAPIBaseURL(
                configured,
                defaultValue: nil,
                allowsInsecureLocalhost: false
            )
        #endif
    }

    static func validatedAPIBaseURL(
        _ configured: String?,
        defaultValue: String?,
        allowsInsecureLocalhost: Bool
    ) throws -> URL {
        let rawValue =
            configured.flatMap { $0.isEmpty ? nil : $0 }
            ?? defaultValue
        guard
            let rawValue,
            !rawValue.contains("$("),
            let url = URL(string: rawValue),
            let scheme = url.scheme?.lowercased(),
            let host = url.host,
            !host.isEmpty
        else {
            throw ConfigurationError.invalidAPIBaseURL
        }
        if scheme == "https" {
            return url
        }
        if allowsInsecureLocalhost,
            scheme == "http",
            host == "127.0.0.1" || host == "localhost"
        {
            return url
        }
        throw ConfigurationError.insecureAPIBaseURL
    }

    enum ConfigurationError: Error {
        case invalidAPIBaseURL
        case insecureAPIBaseURL
    }
}
