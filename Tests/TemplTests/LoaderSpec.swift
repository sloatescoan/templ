//
// Stencil
// Copyright © 2022 Stencil
// MIT Licence
//

import Spectre
import Templ
import XCTest
import Testing

@Suite struct TemplateLoaderTests {
  @Test func testFileSystemLoader() throws {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "fixtures").path
    let loader = FileSystemLoader(paths: [path])
    let environment = Environment(loader: loader)

    // it("errors when a template cannot be found") {
    try expect(try environment.loadTemplate(name: "unknown.html")).toThrow()
    // }

    // it("errors when an array of templates cannot be found") {
    try expect(try environment.loadTemplate(names: ["unknown.html", "unknown2.html"])).toThrow()
    // }

    // it("can load a template from a file") {
    _ = try environment.loadTemplate(name: "test.html")
    // }

    // it("errors when loading absolute file outside of the selected path") {
    try expect(try environment.loadTemplate(name: "/etc/hosts")).toThrow()
    // }

    // it("errors when loading relative file outside of the selected path") {
    try expect(try environment.loadTemplate(name: "../LoaderSpec.swift")).toThrow()
    // }
  }

  @Test func testDictionaryLoader() throws {
    let loader = DictionaryLoader(templates: [
      "index.html": "Hello World"
    ])
    let environment = Environment(loader: loader)

    // it("errors when a template cannot be found") {
    try expect(try environment.loadTemplate(name: "unknown.html")).toThrow()
    // }

    // it("errors when an array of templates cannot be found") {
    try expect(try environment.loadTemplate(names: ["unknown.html", "unknown2.html"])).toThrow()
    // }

    // it("can load a template from a known templates") {
    _ = try environment.loadTemplate(name: "index.html")
    // }

    // it("can load a known template from a collection of templates") {
    _ = try environment.loadTemplate(names: ["unknown.html", "index.html"])
    // }
  }
}
