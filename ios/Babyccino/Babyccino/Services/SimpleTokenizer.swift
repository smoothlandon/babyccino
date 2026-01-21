//
//  SimpleTokenizer.swift
//  Babyccino
//
//  Simple tokenizer wrapper for MLX models
//

import Foundation

/// Simple tokenizer for Chat ML formatted prompts
/// Uses the tokenizer.json file from HuggingFace models
class SimpleTokenizer {
    private let vocabulary: [String: Int]
    private let reverseVocabulary: [Int: String]
    let bosToken: Int
    let eosToken: Int
    let padToken: Int

    init(tokenizerPath: URL) throws {
        // Load tokenizer.json
        let data = try Data(contentsOf: tokenizerPath)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let model = json?["model"] as? [String: Any],
              let vocab = model["vocab"] as? [String: Int] else {
            throw TokenizerError.invalidFormat
        }

        self.vocabulary = vocab
        self.reverseVocabulary = Dictionary(uniqueKeysWithValues: vocab.map { ($1, $0) })

        // Get special tokens
        if let addedTokens = json?["added_tokens"] as? [[String: Any]] {
            self.bosToken = addedTokens.first(where: { ($0["content"] as? String) == "<|im_start|>" })?["id"] as? Int ?? 0
            self.eosToken = addedTokens.first(where: { ($0["content"] as? String) == "<|im_end|>" })?["id"] as? Int ?? 2
            self.padToken = addedTokens.first(where: { ($0["content"] as? String) == "<|endoftext|>" })?["id"] as? Int ?? 0
        } else {
            // Fallback defaults for Qwen models
            self.bosToken = 151644  // <|im_start|>
            self.eosToken = 151645  // <|im_end|>
            self.padToken = 151643  // <|endoftext|>
        }

        print("✅ Tokenizer loaded: \(vocabulary.count) tokens")
    }

    /// Encode text to token IDs (simplified byte-pair encoding)
    func encode(text: String) -> [Int] {
        var tokens: [Int] = []

        // Simple whitespace tokenization + vocabulary lookup
        // Real BPE would be more complex, but this works for basic cases
        let words = text.split(separator: " ", omittingEmptySubsequences: false)

        for word in words {
            let wordStr = String(word)

            // Try to find exact match first
            if let tokenId = vocabulary[wordStr] {
                tokens.append(tokenId)
            } else {
                // Fallback: character-level encoding
                for char in wordStr {
                    if let tokenId = vocabulary[String(char)] {
                        tokens.append(tokenId)
                    }
                }
            }
        }

        return tokens
    }

    /// Decode token IDs to text
    func decode(tokens: [Int]) -> String {
        let words = tokens.compactMap { reverseVocabulary[$0] }
        return words.joined()
    }
}

/// Tokenizer errors
enum TokenizerError: LocalizedError {
    case invalidFormat
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid tokenizer format"
        case .fileNotFound:
            return "Tokenizer file not found"
        }
    }
}
