import Foundation
import HTTPTypes
import OpenAPIRuntime

struct InstallationIdentityMiddleware: ClientMiddleware {
    let identity: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[
            HTTPField.Name("X-PhotoDome-Installation-ID")!
        ] = identity
        return try await next(request, body, baseURL)
    }
}

struct CapabilityAuthMiddleware: ClientMiddleware {
    let capability: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(capability)"
        return try await next(request, body, baseURL)
    }
}
