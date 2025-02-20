import Templ

struct CannotUpdateConfig: Error {}
struct UninitializedConfig: Error {}

public struct TemplConfig {
    nonisolated(unsafe) private static var config: TemplConfig?

    public let environment: Environment

    public init(environment: Environment) {
        self.environment = environment
    }

    public static func set(_ config: TemplConfig) throws {
        if Self.config == nil {
            Self.config = config
            return
        }

        throw CannotUpdateConfig()
    }

    public static func get() throws -> TemplConfig {
        guard let config = Self.config else {
            throw UninitializedConfig()
        }

        return config
    }
}