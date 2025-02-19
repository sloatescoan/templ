import Hummingbird
import Templ

public struct TemplResponse: ResponseGenerator {
    let template: String?
    let templateContext: [String: Any]?
    let status: HTTPResponse.Status
    let headers: HTTPFields
    let body: ResponseBody?

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
            templateContext["foo"] = Foo()


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
}

struct Foo {
    var bar: Bar = Bar()
}

struct Bar {
    var baz = "qux"
}