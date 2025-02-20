//
// Stencil
// Copyright © 2022 Stencil
// MIT Licence
//

import Foundation

typealias Line = (content: String, number: UInt, range: Range<String.Index>)

struct Lexer: Hashable {
  static func == (lhs: Lexer, rhs: Lexer) -> Bool {
      lhs.templateString == rhs.templateString
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(templateString)
  }

  let templateName: String?
  let templateString: String
  let lines: [Line]

  /// The potential token start characters. In a template these appear after a
  /// `{` character, for example `{{`, `{%`, `{#`, ...
  private static let tokenChars: [Unicode.Scalar] = ["{", "%", "#"]

  /// The minimum length of a tag
  private static let tagLength = 2

  /// The token end characters, corresponding to their token start characters.
  /// For example, a variable token starts with `{{` and ends with `}}`
  private static let tokenCharMap: [Unicode.Scalar: Unicode.Scalar] = [
    "{": "}",
    "%": "%",
    "#": "#"
  ]

  /// Characters controlling whitespace trimming behaviour
  private static let behaviourMap: [Character: WhitespaceBehaviour.Behaviour] = [
    "+": .keep,
    "-": .trim
  ]

  init(templateName: String? = nil, templateString: String) {
    self.templateName = templateName
    self.templateString = templateString

    self.lines = zip(1..., templateString.components(separatedBy: .newlines)).compactMap { index, line in
      guard !line.isEmpty,
        let range = templateString.range(of: line) else { return nil }
      return (content: line, number: UInt(index), range)
    }
  }

  private func behaviour(string: String, tagLength: Int) -> WhitespaceBehaviour {
    let leftIndex = string.index(string.startIndex, offsetBy: tagLength, limitedBy: string.endIndex)
    let rightIndex = string.index(string.endIndex, offsetBy: -(tagLength + 1), limitedBy: string.startIndex)

    return WhitespaceBehaviour(
      leading: Self.behaviourMap[leftIndex.map { string[$0] } ?? " "] ?? .unspecified,
      trailing: Self.behaviourMap[rightIndex.map { string[$0] } ?? " "] ?? .unspecified
    )
  }

  /// Create a token that will be passed on to the parser, with the given
  /// content and a range. The content will be tested to see if it's a
  /// `variable`, a `block` or a `comment`, otherwise it'll default to a simple
  /// `text` token.
  ///
  /// - Parameters:
  ///   - string: The content string of the token
  ///   - range: The range within the template content, used for smart
  ///            error reporting
  func createToken(string: String, at range: Range<String.Index>) -> Token {
    func strip(length: (Int, Int) = (Self.tagLength, Self.tagLength)) -> String {
      guard string.count > (length.0 + length.1) else { return "" }
      let trimmed = String(string.dropFirst(length.0).dropLast(length.1))
        .components(separatedBy: "\n")
        .filter { !$0.isEmpty }
        .map { $0.trim(character: " ") }
        .joined(separator: " ")
      return trimmed
    }

    if string.hasPrefix("{{") || string.hasPrefix("{%") || string.hasPrefix("{#") {
      let behaviour = string.hasPrefix("{%") ? behaviour(string: string, tagLength: Self.tagLength) : .unspecified
      let stripLengths = (
        Self.tagLength + (behaviour.leading != .unspecified ? 1 : 0),
        Self.tagLength + (behaviour.trailing != .unspecified ? 1 : 0)
      )

      let value = strip(length: stripLengths)
      let range = templateString.range(of: value, range: range) ?? range
      let location = rangeLocation(range)
      let sourceMap = SourceMap(filename: templateName, location: location)

      if string.hasPrefix("{{") {
        return .variable(value: value, at: sourceMap)
      } else if string.hasPrefix("{%") {
        return .block(value: strip(length: stripLengths), at: sourceMap, whitespace: behaviour)
      } else if string.hasPrefix("{#") {
        return .comment(value: value, at: sourceMap)
      }
    }

    let location = rangeLocation(range)
    let sourceMap = SourceMap(filename: templateName, location: location)
    return .text(value: string, at: sourceMap)
  }

  /// Transforms the template into a list of tokens, that will eventually be
  /// passed on to the parser.
  ///
  /// - Returns: The list of tokens (see `createToken(string: at:)`).
  func tokenize() -> [Token] {
    var tokens: [Token] = []

    let scanner = Scanner(templateString)
    while !scanner.isEmpty {
      if let (char, text) = scanner.scanForTokenStart(Self.tokenChars) {
        if !text.isEmpty {
          tokens.append(createToken(string: text, at: scanner.range))
        }

        guard let end = Self.tokenCharMap[char] else { continue }
        let result = scanner.scanForTokenEnd(end)
        tokens.append(createToken(string: result, at: scanner.range))
      } else {
        tokens.append(createToken(string: scanner.content, at: scanner.range))
        scanner.content = ""
      }
    }

    return tokens
  }

  /// Finds the line matching the given range (for a token)
  ///
  /// - Parameter range: The range to search for.
  /// - Returns: The content for that line, the line number and offset within
  ///            the line.
  func rangeLocation(_ range: Range<String.Index>) -> ContentLocation {
    guard let line = self.lines.first(where: { $0.range.contains(range.lowerBound) }) else {
      return ("", 0, 0)
    }
    let offset = templateString.distance(from: line.range.lowerBound, to: range.lowerBound)
    return (line.content, line.number, offset)
  }
}

class Scanner {
  let originalContent: String
  var content: String
  var range: Range<String.UnicodeScalarView.Index>

  /// The start delimiter for a token.
  private static let tokenStartDelimiter: Unicode.Scalar = "{"
  /// And the corresponding end delimiter for a token.
  private static let tokenEndDelimiter: Unicode.Scalar = "}"

  init(_ content: String) {
    self.originalContent = content
    self.content = content
    range = content.unicodeScalars.startIndex..<content.unicodeScalars.startIndex
  }

  var isEmpty: Bool {
    content.isEmpty
  }

  /// Scans for the end of a token, with a specific ending character. If we're
  /// searching for the end of a block token `%}`, this method receives a `%`.
  /// The scanner will search for that `%` followed by a `}`.
  ///
  /// Note: if the end of a token is found, the `content` and `range`
  /// properties are updated to reflect this. `content` will be set to what
  /// remains of the template after the token. `range` will be set to the range
  /// of the token within the template.
  ///
  /// - Parameter tokenChar: The token end character to search for.
  /// - Returns: The content of a token, or "" if no token end was found.
  func scanForTokenEnd(_ tokenChar: Unicode.Scalar) -> String {
    var foundChar = false

    for (index, char) in zip(0..., content.unicodeScalars) {
      if foundChar && char == Self.tokenEndDelimiter {
        let result = String(content.unicodeScalars.prefix(index + 1))
        content = String(content.unicodeScalars.dropFirst(index + 1))
        range = range.upperBound..<originalContent.unicodeScalars.index(range.upperBound, offsetBy: index + 1)
        return result
      } else {
        foundChar = (char == tokenChar)
      }
    }

    content = ""
    return ""
  }

  /// Scans for the start of a token, with a list of potential starting
  /// characters. To scan for the start of variables (`{{`), blocks (`{%`) and
  /// comments (`{#`), this method receives the characters `{`, `%` and `#`.
  /// The scanner will search for a `{`, followed by one of the search
  /// characters. It will give the found character, and the content that came
  /// before the token.
  ///
  /// Note: if the start of a token is found, the `content` and `range`
  /// properties are updated to reflect this. `content` will be set to what
  /// remains of the template starting with the token. `range` will be set to
  /// the start of the token within the template.
  ///
  /// - Parameter tokenChars: List of token start characters to search for.
  /// - Returns: The found token start character, together with the content
  ///            before the token, or nil of no token start was found.
  func scanForTokenStart(_ tokenChars: [Unicode.Scalar]) -> (Unicode.Scalar, String)? {
    var foundBrace = false

    range = range.upperBound..<range.upperBound
    for (index, char) in zip(0..., content.unicodeScalars) {
      if foundBrace && tokenChars.contains(char) {
        let result = String(content.unicodeScalars.prefix(index - 1))
        content = String(content.unicodeScalars.dropFirst(index - 1))
        range = range.upperBound..<originalContent.unicodeScalars.index(range.upperBound, offsetBy: index - 1)
        return (char, result)
      } else {
        foundBrace = (char == Self.tokenStartDelimiter)
      }
    }

    return nil
  }
}

extension String {
  func findFirstNot(character: Character) -> String.Index? {
    var index = startIndex

    while index != endIndex {
      if character != self[index] {
        return index
      }
      index = self.index(after: index)
    }

    return nil
  }

  func findLastNot(character: Character) -> String.Index? {
    var index = self.index(before: endIndex)

    while index != startIndex {
      if character != self[index] {
        return self.index(after: index)
      }
      index = self.index(before: index)
    }

    return nil
  }

  func trim(character: Character) -> String {
    let first = findFirstNot(character: character) ?? startIndex
    let last = findLastNot(character: character) ?? endIndex
    return String(self[first..<last])
  }
}

/// Location in some content (text)
public typealias ContentLocation = (content: String, lineNumber: UInt, lineOffset: Int)
