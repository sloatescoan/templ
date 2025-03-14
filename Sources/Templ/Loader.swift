//
// Stencil
// Copyright © 2022 Stencil
// MIT Licence
//

import Foundation

/// Type used for loading a template
public protocol Loader: Sendable {
  /// Load a template with the given name
  func loadTemplate(name: String, environment: Environment) throws -> Template
  /// Load a template with the given list of names
  func loadTemplate(names: [String], environment: Environment) throws -> Template
}

extension Loader {
  /// Default implementation, tries to load the first template that exists from the list of given names
  public func loadTemplate(names: [String], environment: Environment) throws -> Template {
    for name in names {
      do {
        return try loadTemplate(name: name, environment: environment)
      } catch is TemplateDoesNotExist {
        continue
      } catch {
        throw error
      }
    }

    throw TemplateDoesNotExist(templateNames: names, loader: self)
  }
}

// A class for loading a template from disk
public final class FileSystemLoader: Loader, CustomStringConvertible {
  public let paths: [URL]

  public init(paths: [String]) {
    self.paths = paths.map {
      URL(fileURLWithPath: $0)
    }
  }

  public init(bundle: [Bundle]) {
    self.paths = bundle.map { bundle in
      bundle.bundleURL
    }
  }

  public var description: String {
    "FileSystemLoader(\(paths))"
  }

  public func loadTemplate(name: String, environment: Environment) throws -> Template {
    do {
      for path in paths {
        let templatePath = try path.safeAppending(path: name)

        if try !templatePath.checkResourceIsReachable() {
          continue
        }

        let content = try String(contentsOf: templatePath, encoding: .utf8)
        return environment.templateClass.init(templateString: content, environment: environment, name: name)
      }
    } catch {
      throw TemplateDoesNotExist(templateNames: [name], loader: self)
    }

    throw TemplateDoesNotExist(templateNames: [name], loader: self)
  }

  public func loadTemplate(names: [String], environment: Environment) throws -> Template {
    do {
      for path in paths {
        for templateName in names {
          let templatePath = try path.safeAppending(path: templateName)

          if try templatePath.checkResourceIsReachable() {
            let content: String = try String(contentsOf: templatePath, encoding: .utf8)
            return environment.templateClass.init(templateString: content, environment: environment, name: templateName)
          }
        }
      }
    } catch {
      throw TemplateDoesNotExist(templateNames: names, loader: self)
    }

    throw TemplateDoesNotExist(templateNames: names, loader: self)
  }
}

public final class DictionaryLoader: Loader {
  public let templates: [String: String]

  public init(templates: [String: String]) {
    self.templates = templates
  }

  public func loadTemplate(name: String, environment: Environment) throws -> Template {
    if let content = templates[name] {
      return environment.templateClass.init(templateString: content, environment: environment, name: name)
    }

    throw TemplateDoesNotExist(templateNames: [name], loader: self)
  }

  public func loadTemplate(names: [String], environment: Environment) throws -> Template {
    for name in names {
      if let content = templates[name] {
        return environment.templateClass.init(templateString: content, environment: environment, name: name)
      }
    }

    throw TemplateDoesNotExist(templateNames: names, loader: self)
  }
}

extension URL {
  func safeAppending(path: String) throws -> URL {
    let newURL = self.appending(path: path).standardized

    if !newURL.path().hasPrefix(self.path()) {
      throw SuspiciousFileOperation(basePath: self.path(), path: newURL.path())
    }

    return newURL
  }
}

final class SuspiciousFileOperation: Error {
  let basePath: String
  let path: String

  init(basePath: String, path: String) {
    self.basePath = basePath
    self.path = path
  }

  var description: String {
    "Path `\(path)` is located outside of base path `\(basePath)`"
  }
}