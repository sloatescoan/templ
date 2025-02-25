//
// Stencil
// Copyright © 2022 Stencil
// MIT Licence
//

import Spectre
@testable import Templ
import XCTest
import Testing

@Suite
struct LexerTests {

  @Test func testText() throws {
    let lexer = Lexer(templateString: "Hello World")
    let tokens = lexer.tokenize()

    try expect(tokens.count) == 1
    try expect(tokens.first) == .text(value: "Hello World", at: makeSourceMap("Hello World", for: lexer))
  }

  @Test func testComment() throws {
    let lexer = Lexer(templateString: "{# Comment #}")
    let tokens = lexer.tokenize()

    try expect(tokens.count) == 1
    try expect(tokens.first) == .comment(value: "Comment", at: makeSourceMap("Comment", for: lexer))
  }

  @Test func testVariable() throws {
    let lexer = Lexer(templateString: "{{ Variable }}")
    let tokens = lexer.tokenize()

    try expect(tokens.count) == 1
    try expect(tokens.first) == .variable(value: "Variable", at: makeSourceMap("Variable", for: lexer))
  }

  @Test func testTokenWithoutSpaces() throws {
    let lexer = Lexer(templateString: "{{Variable}}")
    let tokens = lexer.tokenize()

    try expect(tokens.count) == 1
    try expect(tokens.first) == .variable(value: "Variable", at: makeSourceMap("Variable", for: lexer))
  }

  @Test func testUnclosedTag() throws {
    let templateString = "{{ thing"
    let lexer = Lexer(templateString: templateString)
    let tokens = lexer.tokenize()

    try expect(tokens.count) == 1
    try expect(tokens.first) == .text(value: "", at: makeSourceMap("{{ thing", for: lexer))
  }

  @Test func testContentMixture() throws {
    let templateString = "My name is {{ myname }}."
    let lexer = Lexer(templateString: templateString)
    let tokens = lexer.tokenize()

    try expect(tokens.count) == 3
    try expect(tokens[0]) == .text(value: "My name is ", at: makeSourceMap("My name is ", for: lexer))
    try expect(tokens[1]) == .variable(value: "myname", at: makeSourceMap("myname", for: lexer))
    try expect(tokens[2]) == .text(value: ".", at: makeSourceMap(".", for: lexer))
  }

  @Test func testVariablesWithoutBeingGreedy() throws {
    let templateString = "{{ thing }}{{ name }}"
    let lexer = Lexer(templateString: templateString)
    let tokens = lexer.tokenize()

    try expect(tokens.count) == 2
    try expect(tokens[0]) == .variable(value: "thing", at: makeSourceMap("thing", for: lexer))
    try expect(tokens[1]) == .variable(value: "name", at: makeSourceMap("name", for: lexer))
  }

  @Test func testUnclosedBlock() throws {
    let lexer = Lexer(templateString: "{%}")
    _ = lexer.tokenize()
  }

  @Test func testTokenizeIncorrectSyntaxWithoutCrashing() throws {
    let lexer = Lexer(templateString: "func some() {{% if %}")
    _ = lexer.tokenize()
  }

  @Test func testEmptyVariable() throws {
    let lexer = Lexer(templateString: "{{}}")
    _ = lexer.tokenize()
  }

  @Test func testNewlines() throws {
    // swiftlint:disable indentation_width
    let templateString = """
      My name is {%
          if name
           and
          name
      %}{{
      name
      }}{%
      endif %}.
      """
    // swiftlint:enable indentation_width
    let lexer = Lexer(templateString: templateString)
    let tokens = lexer.tokenize()

    try expect(tokens.count) == 5
    try expect(tokens[0]) == .text(value: "My name is ", at: makeSourceMap("My name is", for: lexer))
    try expect(tokens[1]) == .block(value: "if name and name", at: makeSourceMap("{%", for: lexer))
    try expect(tokens[2]) == .variable(value: "name", at: makeSourceMap("name", for: lexer, options: .backwards))
    try expect(tokens[3]) == .block(value: "endif", at: makeSourceMap("endif", for: lexer))
    try expect(tokens[4]) == .text(value: ".", at: makeSourceMap(".", for: lexer))
  }

  @Test func testTrimSymbols() throws {
    let fBlock = "if hello"
    let sBlock = "ta da"
    let lexer = Lexer(templateString: "{%+ \(fBlock) -%}{% \(sBlock) -%}")
    let tokens = lexer.tokenize()
    let behaviours = (
      WhitespaceBehaviour(leading: .keep, trailing: .trim),
      WhitespaceBehaviour(leading: .unspecified, trailing: .trim)
    )

    try expect(tokens.count) == 2
    try expect(tokens[0]) == .block(value: fBlock, at: makeSourceMap(fBlock, for: lexer), whitespace: behaviours.0)
    try expect(tokens[1]) == .block(value: sBlock, at: makeSourceMap(sBlock, for: lexer), whitespace: behaviours.1)
  }

  @Test func testEscapeSequence() throws {
    let templateString = "class Some {{ '{' }}{% if true %}{{ stuff }}{% endif %}"
    let lexer = Lexer(templateString: templateString)
    let tokens = lexer.tokenize()

    try expect(tokens.count) == 5
    try expect(tokens[0]) == .text(value: "class Some ", at: makeSourceMap("class Some ", for: lexer))
    try expect(tokens[1]) == .variable(value: "'{'", at: makeSourceMap("'{'", for: lexer))
    try expect(tokens[2]) == .block(value: "if true", at: makeSourceMap("if true", for: lexer))
    try expect(tokens[3]) == .variable(value: "stuff", at: makeSourceMap("stuff", for: lexer))
    try expect(tokens[4]) == .block(value: "endif", at: makeSourceMap("endif", for: lexer))
  }

  // measure from XCTestCase has no Swift Testing equivalent
  // @Test func testPerformance() throws {
  //   let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "fixtures/huge.html").path
  //   let content: String = try String(contentsOf: URL(filePath: path))

  //   measure {
  //     let lexer = Lexer(templateString: content)
  //     _ = lexer.tokenize()
  //   }
  // }

  @Test func testCombiningDiaeresis() throws {
    // the symbol "ü" in the `templateString` is unusually encoded as 0x75 0xCC 0x88 (LATIN SMALL LETTER U + COMBINING
    // DIAERESIS) instead of 0xC3 0xBC (LATIN SMALL LETTER U WITH DIAERESIS)
    let templateString = "ü\n{% if test %}ü{% endif %}\n{% if ü %}ü{% endif %}\n"
    let lexer = Lexer(templateString: templateString)
    let tokens = lexer.tokenize()

    try expect(tokens.count) == 9
    assert(tokens[1].contents == "if test")
  }

  private func makeSourceMap(_ token: String, for lexer: Lexer, options: String.CompareOptions = []) -> SourceMap {
    guard let range = lexer.templateString.range(of: token, options: options) else { fatalError("Token not found") }
    return SourceMap(location: lexer.rangeLocation(range))
  }
}
