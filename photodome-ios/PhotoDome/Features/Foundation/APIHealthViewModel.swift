import Foundation

@MainActor
final class APIHealthViewModel: ObservableObject {
    enum State: Equatable {
        case checking
        case connected
        case unavailable
    }

    @Published private(set) var state: State = .checking

    private let api: APIClient

    init(
        api: APIClient = APIClient(
            baseURL: URL(string: "http://127.0.0.1:3000")!
        )
    ) {
        self.api = api
    }

    func check() async {
        state = .checking
        do {
            try await api.checkHealth()
            state = .connected
        } catch {
            state = .unavailable
        }
    }
}
