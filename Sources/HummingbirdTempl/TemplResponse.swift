import Hummingbird
import Templ

public struct TemplResponse: ResponseGenerator {
    let template: String?
    public var templateContext: [String: Any]?
    public var status: HTTPResponse.Status
    public var headers: HTTPFields
    public var body: ResponseBody?

    public init(
        template: String,
        templateContext: [String: Any] = [:],
        status: HTTPResponse.Status = .ok,
        headers: HTTPFields = .init()
    ) {
        self.template = template
        self.templateContext = templateContext
        self.status = status
        self.headers = headers

        // body must be nil
        self.body = nil
    }

    public init(status: HTTPResponse.Status, headers: HTTPFields = .init(), body: ResponseBody = .init()) {
        self.status = status
        self.headers = headers
        self.body = body

        // template and templateContext must be nil
        self.template = nil
        self.templateContext = nil
    }

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        if template != nil {
            // If a template was supplied, render that
            guard let template, var templateContext = templateContext else {
                throw HTTPError(.internalServerError)
            }

            templateContext["request"] = request

            let environment: Templ.Environment

            do {
                let config = try TemplConfig.get()
                environment = config.environment
            } catch {
                return .init(status: .internalServerError)
            }

            var headers = headers

            if !headers.contains(.contentType) {
                headers[.contentType] = "text/html"
            }

            let rendered = try environment.renderTemplate(name: template, context: templateContext)

            return Response(
                status: status,
                headers: headers,
                body: .init(byteBuffer: .init(string: rendered))
            )
        }

        // Otherwise, we must have a body
        guard let body else {
            throw HTTPError(.internalServerError)
        }

        return Response(status: status, headers: headers, body: body)
    }

    public init(redirect: String, reason: String = "Redirecting.", status: HTTPResponse.Status = .seeOther) {
        self.init(
            status: status,
            headers: [.location: redirect],
            body: .init(byteBuffer: .init(string: reason))
        )
    }

    // from Hummingbird's Response
    public mutating func setCookie(_ cookie: Cookie) {
        self.headers[values: .setCookie].append(cookie.description)
    }
}
