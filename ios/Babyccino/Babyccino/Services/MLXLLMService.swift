//
//  MLXLLMService.swift
//  Babyccino
//
//  Real LLM using MLX Swift (device-only)
//  Uses pre-loaded model with intelligent prompting
//

import Foundation

// Only compile MLX code for physical devices
#if !targetEnvironment(simulator)
import MLX
import MLXNN
import MLXRandom
import MLXFast
import MLXLinalg
import MLXLLM
import MLXLMCommon
import Tokenizers

/// Model configuration
struct MLXModelConfig {
    let name: String
    let modelId: String
    let maxTokens: Int
    let temperature: Float

    /// Qwen2.5 1.5B - Recommended: Best balance of speed and JSON reliability
    static let qwen15b = MLXModelConfig(
        name: "Qwen2.5-1.5B-Instruct",
        modelId: "qwen-1.5b",
        maxTokens: 512,
        temperature: 0.7
    )

    /// Phi-3 Mini 3.8B - Highest quality, most reliable JSON output
    static let phi3mini = MLXModelConfig(
        name: "Phi-3-mini-4k-instruct",
        modelId: "phi-3-mini",
        maxTokens: 512,
        temperature: 0.3  // Lower temp for more deterministic JSON output
    )
}

/// LLM service using MLX for on-device inference
class MLXLLMService: LLMService {
    private var modelReady = false
    private let config: MLXModelConfig
    private var conversationHistory: [ChatMessage] = []
    private var modelContainer: ModelContainer?
    private let modelManager = ModelManager.shared
    private let modelFactory = LLMModelFactory.shared
    private var lastIntentAnalysis: IntentAnalysis?  // Store for extractRequirements()

    // System prompt for JSON-only structured output
    private let systemPrompt = """
You are a function spec analyzer. Output ONLY valid JSON, nothing else. No explanations, no extra text - ONLY the JSON object starting with { and ending with }.

You will receive a conversation history. Analyze the ENTIRE conversation to understand what function is being built and whether the specification is complete.

Output this exact structure:
{
  "function_name": "snake_case_name",
  "function_type": "well_known" | "custom" | "unclear",
  "spec_status": "complete" | "needs_rules" | "needs_details",
  "questions": ["question 1", "question 2"],
  "purpose": "one sentence description"
}

function_type:
- "well_known": palindrome, prime, fibonacci, factorial, sort, reverse, sum, max, min, gcd, lcm
- "unclear": no function has been described yet in the conversation (only greetings or vague statements)
- "custom": everything else

spec_status - evaluate the FULL conversation, then apply this test in order:
1. Is function_type "unclear"? → spec_status = "needs_rules", questions = []
2. Is function_type "well_known"? → spec_status = "complete", questions = []
3. For "custom" functions, check TWO things:
   A. Does the function involve subjective judgment, classification, scoring, or labels? (e.g. "fun/boring", "silly", "suspicious", "exciting", "good/bad")
      - YES → REQUIRE explicit user-stated rules. Look for conditional statements from the user: "if X then Y", specific thresholds, explicit criteria. If not present → spec_status = "needs_rules"
      - NO → the logic is mathematically/logically deterministic → spec_status = "complete"
   B. Are the function inputs or output type unclear? → spec_status = "needs_details"

KEY RULE: A function name or description alone is NEVER enough to mark a subjective custom function as "complete". The user MUST have stated explicit conditions in the conversation.

The "does it need rules?" signal words in the function description:
- NEEDS RULES: fun/boring, silly/serious, suspicious/normal, exciting/dull, good/bad, interesting, classify, score, rate, rank, evaluate, judge
- DOES NOT need rules: find, check, count, sum, sort, filter, reverse, calculate, convert, parse

The "rules are present" signal: user has written IF-THEN conditions, thresholds, or explicit criteria. Examples:
- "if more than one vowel it's fun" ✓ rules present
- "if length > 15 it's fun" ✓ rules present
- "if same char repeats 4 times it's boring" ✓ rules present
- "something fun or boring" ✗ NOT rules - just restating the goal

questions rules:
- needs_rules: ask 1-2 specific questions about what criteria/conditions define the output
- needs_details: ask 1-2 specific questions about missing inputs or output behaviour
- Max 2 questions. Empty array for "unclear" or "complete".

Examples:
User: "let's build great things" → {"function_name":"unknown","function_type":"unclear","spec_status":"needs_rules","questions":[],"purpose":""}
User: "write a palindrome checker" → {"function_name":"is_palindrome","function_type":"well_known","spec_status":"complete","questions":[],"purpose":"check if a string reads the same forwards and backwards"}
User: "determine if a name is fun or boring" → {"function_name":"classify_name","function_type":"custom","spec_status":"needs_rules","questions":["What specific conditions make a name 'fun'? e.g. vowel count, length, specific letters?","What conditions make it 'boring'?"],"purpose":"classify a name as fun or boring based on defined rules"}
User: "determine if a name is fun or boring" / Assistant: "What makes it fun?" / User: "if more than one vowel it's fun, if length > 15 it's fun, if same char repeats 4 times it's boring" → {"function_name":"classify_name","function_type":"custom","spec_status":"complete","questions":[],"purpose":"classify a name as fun or boring: fun if vowels > 1 or length > 15, boring if any character repeats 4 times"}
User: "return whichever array has a greater sum" → {"function_name":"greater_sum_array","function_type":"custom","spec_status":"complete","questions":[],"purpose":"compare two arrays and return the one with the greater sum of elements"}
User: "classify a transaction as suspicious" → {"function_name":"classify_transaction","function_type":"custom","spec_status":"needs_rules","questions":["What conditions make a transaction suspicious? e.g. amount threshold, frequency, unusual merchant?"],"purpose":"classify a transaction as suspicious or normal based on defined rules"}

CRITICAL: Output ONLY the JSON object. Start with { end with }. Nothing else.
"""

    var isReady: Bool {
        return modelReady
    }

    init(config: MLXModelConfig = .qwen15b) {
        self.config = config

        // Initialize in background
        Task {
            await initializeModel()
        }
    }

    /// Initialize and load the model
    private func initializeModel() async {
        do {
            // Check if a model is selected
            guard let selectedModelId = modelManager.selectedModelId,
                  let modelInfo = ModelInfo.model(withId: selectedModelId) else {
                throw MLXError.modelNotReady
            }

            // Check if model is downloaded
            guard modelManager.isModelDownloaded(selectedModelId) else {
                throw MLXError.inferenceFailed("Model not downloaded")
            }

            print("🔄 Loading MLX model: \(modelInfo.displayName)...")

            // Create model configuration pointing to local model directory
            let modelConfiguration = ModelConfiguration(
                id: modelInfo.huggingFaceRepo,
                defaultPrompt: "You are a helpful assistant"
            )

            // Load model using LLMModelFactory
            print("📦 Loading model: \(modelInfo.huggingFaceRepo)")
            self.modelContainer = try await modelFactory.loadContainer(
                configuration: modelConfiguration
            ) { progress in
                print("📊 Load progress: \(Int(progress.fractionCompleted * 100))%")
            }
            print("✅ Model and tokenizer loaded successfully")

            modelReady = true
            print("✅ MLX LLM Service initialized with \(modelInfo.displayName)")

        } catch {
            print("❌ Failed to initialize model: \(error)")
            modelReady = false
            // Model initialization failed - app should not proceed
            // User must download model through onboarding
        }
    }

    func generateResponse(messages: [ChatMessage]) async throws -> String {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔍 [MLXLLMService] generateResponse() called")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        guard isReady, let modelContainer = self.modelContainer else {
            print("❌ [MLXLLMService] Model not ready")
            throw MLXError.modelNotReady
        }

        // Store conversation history
        conversationHistory = messages
        print("📝 [MLXLLMService] Conversation has \(messages.count) messages")

        // Extract last user message
        guard let lastUserMessage = messages.last(where: { $0.role == "user" }) else {
            print("⚠️ [MLXLLMService] No user message found")
            return "I didn't receive a message. Could you try again?"
        }

        print("💬 [MLXLLMService] Last user message: \"\(lastUserMessage.content)\"")

        // Check for special commands
        let userMessageLower = lastUserMessage.content.lowercased()

        if userMessageLower.contains("show") && (userMessageLower.contains("flow") || userMessageLower.contains("visualize")) {
            print("🎯 [MLXLLMService] Special command detected: SHOW_FLOWCHART")
            return "show_flowchart"
        }

        if userMessageLower.contains("generate") && userMessageLower.contains("code") {
            print("🎯 [MLXLLMService] Special command detected: GENERATE_CODE")
            return "generate_code"
        }

        print("💭 [MLXLLMService] No special command detected, proceeding with LLM generation")

        // Build prompt in ChatML format for JSON output
        let prompt = buildChatMLPrompt(messages: messages, systemPrompt: systemPrompt)
        print("📋 [MLXLLMService] Built ChatML prompt (\(prompt.count) chars)")
        print("📋 [MLXLLMService] Prompt preview (first 200 chars):")
        print("   \(String(prompt.prefix(200)))...")
        print("🤖 [MLXLLMService] Starting MLX inference...")

        // Generate response using real MLX inference
        do {
            let generateParameters = GenerateParameters(
                maxTokens: config.maxTokens,
                temperature: config.temperature,
                topP: 0.9
            )

            // Use perform to access the model context
            let generatedText = try await modelContainer.perform { context in
                // Prepare input
                let input = try await context.processor.prepare(input: UserInput(prompt: prompt))

                // Use streaming detokenizer for text generation
                var detokenizer = NaiveStreamingDetokenizer(tokenizer: context.tokenizer)
                var fullText = ""

                _ = try MLXLMCommon.generate(
                    input: input,
                    parameters: generateParameters,
                    context: context
                ) { tokens in
                    if let last = tokens.last {
                        detokenizer.append(token: last)
                    }

                    if let new = detokenizer.next() {
                        fullText += new
                    }

                    // Check stop conditions
                    if let maxTokens = generateParameters.maxTokens,
                       tokens.count >= maxTokens {
                        return .stop
                    }

                    // Stop on end tokens (using EOS token if available)
                    if let last = tokens.last, last == context.tokenizer.unknownTokenId {
                        return .stop
                    }

                    return .more
                }

                return fullText
            }

            // Return empty check
            guard !generatedText.isEmpty else {
                print("❌ [MLXLLMService] Model returned empty response")
                throw MLXError.inferenceFailed("Model returned empty response")
            }

            print("✅ [MLXLLMService] Generated \(generatedText.count) characters")
            print("📄 [MLXLLMService] Raw model output:")
            print("   \"\(generatedText)\"")

            // Parse JSON response and convert to user-facing text
            let finalResponse = parseJSONAndGenerateResponse(from: generatedText)

            print("✓ [MLXLLMService] Final response: \"\(finalResponse)\"")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

            return finalResponse

        } catch {
            print("❌ [MLXLLMService] Generation failed: \(error)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            throw MLXError.inferenceFailed(error.localizedDescription)
        }
    }

    /// Build a prompt from conversation history using the correct format for the active model.
    /// Qwen uses ChatML (<|im_start|>), Phi-3 uses its own tag format (<|system|>, <|user|>, etc.)
    private func buildChatMLPrompt(messages: [ChatMessage], systemPrompt: String) -> String {
        let activeModelId = modelManager.selectedModelId ?? config.modelId
        let isPhi3 = activeModelId == "phi-3-mini"

        if isPhi3 {
            // Phi-3 format: <|system|>\ncontent<|end|>\n<|user|>\ncontent<|end|>\n<|assistant|>\n
            var prompt = "<|system|>\n\(systemPrompt)<|end|>\n"
            for message in messages where message.role == "user" || message.role == "assistant" {
                let tag = message.role == "user" ? "<|user|>" : "<|assistant|>"
                prompt += "\(tag)\n\(message.content)<|end|>\n"
            }
            prompt += "<|assistant|>\n"
            return prompt
        } else {
            // ChatML format (Qwen and others): <|im_start|>role\ncontent<|im_end|>\n
            var prompt = "<|im_start|>system\n\(systemPrompt)<|im_end|>\n"
            for message in messages where message.role == "user" || message.role == "assistant" {
                prompt += "<|im_start|>\(message.role)\n\(message.content)<|im_end|>\n"
            }
            prompt += "<|im_start|>assistant\n"
            return prompt
        }
    }

    /// Parse JSON response from LLM and generate user-facing text
    private func parseJSONAndGenerateResponse(from rawOutput: String) -> String {
        print("🔍 [MLXLLMService] Parsing JSON response...")

        // Extract JSON from potential markdown code blocks or extra text
        let cleanedOutput = extractJSON(from: rawOutput)

        // Try to parse JSON
        guard let jsonData = cleanedOutput.data(using: .utf8),
              let intent = try? JSONDecoder().decode(IntentAnalysis.self, from: jsonData) else {
            print("⚠️ [MLXLLMService] Failed to parse JSON")
            print("   Raw output: \"\(rawOutput.prefix(200))...\"")
            print("   Cleaned output: \"\(cleanedOutput.prefix(200))...\"")
            // Fallback: Don't show raw JSON to user, ask them to describe a function
            return ResponseTemplate.needsFunctionDescription.text
        }

        print("✅ [MLXLLMService] Successfully parsed JSON")
        print("   Function: \(intent.functionName)")
        print("   Type: \(intent.functionType.rawValue)")
        print("   Spec status (raw): \(intent.specStatus.rawValue)")
        print("   Questions: \(intent.questions)")

        // Swift-side validation: correct the LLM's spec_status when needed.
        // Small models (1.5B) often mark custom subjective functions as "complete"
        // on the first message even without user-defined rules.
        let validatedIntent = validateSpecStatus(intent)
        print("   Spec status (validated): \(validatedIntent.specStatus.rawValue)")

        // Store for extractRequirements() if spec is complete
        if validatedIntent.specStatus == .complete {
            lastIntentAnalysis = validatedIntent
        }

        // Generate user-facing response from spec status
        let response: String
        switch validatedIntent.specStatus {
        case .complete:
            if validatedIntent.functionType == .unclear {
                response = ResponseTemplate.needsFunctionDescription.text
            } else {
                response = ResponseTemplate.readyToGenerate(purpose: validatedIntent.purpose).text
            }
        case .needsRules:
            if validatedIntent.functionType == .unclear {
                response = ResponseTemplate.needsFunctionDescription.text
            } else {
                response = ResponseTemplate.needsRules(questions: validatedIntent.questions).text
            }
        case .needsDetails:
            response = ResponseTemplate.needsDetails(questions: validatedIntent.questions).text
        }

        print("📝 [MLXLLMService] Generated template response: \"\(response)\"")
        return response
    }


    /// Validate and correct LLM's spec_status using deterministic Swift rules.
    /// Small models can err in both directions:
    ///   - Mark subjective functions "complete" before any rules are given
    ///   - Mark functions "needs_rules" even when rules were stated upfront
    /// This validator corrects both cases.
    private func validateSpecStatus(_ intent: IntentAnalysis) -> IntentAnalysis {
        // Rule 1: unclear is always needs_rules — no correction needed
        guard intent.functionType != .unclear else { return intent }

        // Rule 2: well_known is always complete — no correction needed
        guard intent.functionType == .custom else { return intent }

        let isSubjective = isSubjectiveFunction(intent)
        let rulesPresent = userHasStatedRules()

        switch intent.specStatus {
        case .complete:
            // Downgrade: LLM said complete, but this is subjective and no rules were stated
            if isSubjective && !rulesPresent {
                print("⚠️ [MLXLLMService] Overriding complete→needs_rules: subjective function, no rules found in conversation")
                let fallbackQuestions = defaultRuleQuestions(for: intent)
                return IntentAnalysis(
                    functionName: intent.functionName,
                    functionType: intent.functionType,
                    specStatus: .needsRules,
                    questions: fallbackQuestions,
                    purpose: intent.purpose
                )
            }

        case .needsRules:
            // Upgrade: LLM said needs_rules, but user already stated explicit rules
            if rulesPresent {
                print("✅ [MLXLLMService] Overriding needs_rules→complete: rules found in conversation")
                return IntentAnalysis(
                    functionName: intent.functionName,
                    functionType: intent.functionType,
                    specStatus: .complete,
                    questions: [],
                    purpose: intent.purpose
                )
            }

        case .needsDetails:
            // needsDetails is for missing input/output information — don't override
            break
        }

        return intent
    }

    /// Returns true if the function involves subjective judgment that requires user-defined rules.
    private func isSubjectiveFunction(_ intent: IntentAnalysis) -> Bool {
        let subjectiveKeywords = [
            "fun", "boring", "silly", "serious", "suspicious", "normal",
            "exciting", "dull", "good", "bad", "interesting", "classify",
            "score", "rate", "rank", "evaluate", "judge", "label",
            "weird", "cool", "nice", "ugly", "pretty", "spam", "toxic"
        ]
        let lowerName = intent.functionName.lowercased()
        let lowerPurpose = (intent.purpose ?? "").lowercased()
        // Also scan the last user message
        let lastUserContent = conversationHistory.last(where: { $0.role == "user" })?.content.lowercased() ?? ""

        return subjectiveKeywords.contains(where: {
            lowerName.contains($0) || lowerPurpose.contains($0) || lastUserContent.contains($0)
        })
    }

    /// Returns true if any user message contains explicit rule statements (if/when conditions).
    /// Checks ALL user messages — rules may be provided upfront in the very first message.
    private func userHasStatedRules() -> Bool {
        let ruleSignals = ["if ", "when ", "more than", "less than", "greater than",
                           "at least", "at most", "repeats", "return true", "return false",
                           "true if", "false if", " > ", " < ", " >= ", " <= ",
                           "means ", "is defined as", "count", "length", "characters"]
        let userMessages = conversationHistory.filter { $0.role == "user" }.map { $0.content.lowercased() }
        return userMessages.contains(where: { msg in
            ruleSignals.contains(where: { msg.contains($0) })
        })
    }

    /// Generate sensible default clarification questions for a subjective function.
    private func defaultRuleQuestions(for intent: IntentAnalysis) -> [String] {
        let name = intent.functionName.lowercased()
        let purpose = (intent.purpose ?? "").lowercased()

        // Try to generate specific questions based on the function's output labels
        // by extracting them from purpose/name
        if purpose.contains("fun") || name.contains("fun") {
            return ["What specific conditions make a name 'fun'? e.g. vowel count, length, specific letters?",
                    "What conditions make it 'boring'?"]
        } else if purpose.contains("silly") || name.contains("silly") {
            return ["What makes it 'silly'? e.g. unusual characters, length, repeated letters?"]
        } else if purpose.contains("suspicious") || name.contains("suspicious") {
            return ["What conditions make it 'suspicious'? e.g. amount threshold, specific patterns?"]
        } else {
            // Generic fallback for any subjective classification
            return ["What specific conditions or rules define the output? Please describe each case with explicit criteria."]
        }
    }

    /// Extract JSON from text that might contain markdown code blocks or extra content
    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if trimmed.hasPrefix("```") {
            // Extract content between ```json and ``` or between ``` and ```
            let pattern = "```(?:json)?\\s*([\\s\\S]*?)```"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let range = Range(match.range(at: 1), in: trimmed) {
                return String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // If no code blocks, look for JSON object
        if let startIndex = trimmed.firstIndex(of: "{"),
           let endIndex = trimmed.lastIndex(of: "}") {
            return String(trimmed[startIndex...endIndex])
        }

        return trimmed
    }

    /// Remove code blocks and explanatory text from LLM response (legacy fallback)
    /// We only want requirements gathering questions, not explanations
    private func removeCodeBlocks(from text: String) -> String {
        var result = text

        // Remove markdown code blocks (```python ... ``` or ``` ... ```)
        let codeBlockPattern = "```[\\s\\S]*?```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            result = regex.stringByReplacingMatches(
                in: text,
                range: range,
                withTemplate: ""  // Silently remove
            )
        }

        // Remove numbered lists (1. 2. 3. etc.) - these are usually explanations
        let numberedListPattern = "\\d+\\.\\s+[^\\n]*"
        if let regex = try? NSRegularExpression(pattern: numberedListPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Remove explanatory sentences - significantly expanded list
        let explanatoryPatterns = [
            // Function descriptions
            "Here's a[^.!?]*function[^.!?]*[.!?]",
            "This function[^.!?]*[.!?]",
            "The function[^.!?]*[.!?]",
            "Let's implement[^.!?]*[.!?]",
            "We'll create[^.!?]*[.!?]",
            "I can help you write[^.!?]*[.!?]",

            // Implementation details
            "It then[^.!?]*[.!?]",
            "It checks[^.!?]*[.!?]",
            "Finally, it[^.!?]*[.!?]",
            "We use[^.!?]*[.!?]",
            "We compare[^.!?]*[.!?]",
            "We filter[^.!?]*[.!?]",

            // Definitions and explanations
            "A palindrome is[^.!?]*[.!?]",
            "A prime number is[^.!?]*[.!?]",
            "[A-Z][a-z]+ is a [^.!?]*that[^.!?]*[.!?]",

            // Parameter/output descriptions starting sentences
            "^\\s*Input[^:]*:[^.!?]*[.!?]",
            "^\\s*Output[^:]*:[^.!?]*[.!?]",
            "^\\s*Logic[^:]*:[^.!?]*[.!?]",
            "^\\s*Edge Cases[^:]*:[^.!?]*[.!?]",
            "^\\s*Return Type[^:]*:[^.!?]*[.!?]",
            "The input[^.!?]*will be[^.!?]*[.!?]",

            // Requests for test input (confusing function design with function execution)
            "Please provide the input[^.!?]*[.!?]",
            "What input[^.!?]*would you like[^.!?]*[.!?]",
            "Provide the[^.!?]*number[^.!?]*[.!?]",
            "Which[^.!?]*would you like to[^.!?]*check[^.!?]*[.!?]",

            // How-to statements
            "How to use:[^.!?]*[.!?]",
            "To use this[^.!?]*[.!?]",
            "Call[^.!?]*and[^.!?]*[.!?]",

            // Bullet points and section markers
            "^\\s*[-*]\\s+[^\\n]*",
            "^\\s*###[^\\n]*"
        ]

        for pattern in explanatoryPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: range,
                    withTemplate: ""
                )
            }
        }

        // Clean up extra whitespace and newlines
        result = result.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    /// Extract requirements from conversation history using LLM
    func extractRequirements() -> FunctionRequirements {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔍 [MLXLLMService] extractRequirements() called")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        print("📝 [MLXLLMService] Conversation history (\(conversationHistory.count) messages):")
        for (index, msg) in conversationHistory.enumerated() {
            print("   [\(index)] \(msg.role): \(msg.content)")
        }

        // Use stored intent analysis from last LLM response
        if let intent = lastIntentAnalysis {
            print("✅ [MLXLLMService] Using stored intent analysis from JSON")
            return convertIntentToRequirements(intent)
        }

        // Fallback to pattern matching if no intent stored
        print("⚠️ [MLXLLMService] No stored intent, using pattern matching fallback")
        return extractRequirementsWithPatternMatching()
    }

    /// Convert IntentAnalysis to FunctionRequirements
    private func convertIntentToRequirements(_ intent: IntentAnalysis) -> FunctionRequirements {
        print("🔄 [MLXLLMService] Converting intent to requirements")
        print("   Function: \(intent.functionName)")
        print("   Type: \(intent.functionType.rawValue)")

        // Build full conversation transcript - the server's code generation LLM
        // uses this to implement custom/subjective logic defined during conversation
        let transcript = buildConversationTranscript()
        print("📜 [MLXLLMService] Transcript (\(transcript.count) chars):")
        transcript.split(separator: "\n").forEach { print("   \($0)") }

        let parameters: [FunctionParameter]
        let returnType: String
        let edgeCases: [String]
        let purpose: String

        if intent.functionType == .custom {
            // For custom functions: derive everything from the conversation.
            // The hardcoded templates have no knowledge of user-defined rules.
            (parameters, returnType, edgeCases) = extractCustomFunctionSpec(
                intent: intent,
                transcript: transcript
            )
            // Build a rich purpose string that includes the rules for the server
            purpose = buildPurposeWithRules(intent: intent, transcript: transcript)
        } else {
            // Well-known functions use hardcoded accurate specs
            (parameters, returnType, edgeCases) = getRequirementsForFunction(
                name: intent.functionName,
                type: intent.functionType
            )
            purpose = intent.purpose ?? "Process input and return result"
        }

        // If the user explicitly named the function in conversation, use that name
        let functionName = extractExplicitFunctionName(from: transcript) ?? intent.functionName

        let requirements = FunctionRequirements(
            name: functionName,
            purpose: purpose,
            parameters: parameters,
            returnType: returnType,
            edgeCases: edgeCases,
            examples: generateExamples(for: functionName),
            conversationTranscript: transcript
        )

        print("📋 [MLXLLMService] Created requirements:")
        print("   Name: \(requirements.name)")
        print("   Purpose: \(requirements.purpose)")
        print("   Parameters: \(requirements.parameters.map { "\($0.name): \($0.type)" })")
        print("   Return type: \(requirements.returnType)")
        print("   Edge cases: \(requirements.edgeCases)")
        print("   Has transcript: \(requirements.conversationTranscript != nil)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        return requirements
    }

    /// Extract parameter, return type, and edge cases for a custom function from the conversation.
    /// This is used instead of hardcoded templates so user-defined rules are preserved.
    private func extractCustomFunctionSpec(
        intent: IntentAnalysis,
        transcript: String
    ) -> ([FunctionParameter], String, [String]) {
        // Determine parameter name and type from function name and conversation
        let lowerName = intent.functionName.lowercased()
        let lowerTranscript = transcript.lowercased()

        // Detect parameter type from conversation context
        let paramName: String
        let paramType: String
        let paramDescription: String

        if lowerName.contains("name") || lowerTranscript.contains("name") {
            paramName = "name"
            paramType = "str"
            paramDescription = "The name to classify"
        } else if lowerName.contains("word") || lowerName.contains("string") || lowerName.contains("text") {
            paramName = "text"
            paramType = "str"
            paramDescription = "The text to evaluate"
        } else if lowerName.contains("number") || lowerName.contains("num") || lowerName.contains("int") {
            paramName = "n"
            paramType = "int"
            paramDescription = "The number to evaluate"
        } else if lowerTranscript.contains("string") || lowerTranscript.contains("word") {
            paramName = "text"
            paramType = "str"
            paramDescription = "The input text to evaluate"
        } else {
            paramName = "value"
            paramType = "str"
            paramDescription = "The input value to evaluate"
        }

        // Detect return type from conversation
        let returnType: String
        if lowerTranscript.contains("return boolean") || lowerTranscript.contains("return bool") ||
           lowerTranscript.contains("return a boolean") || lowerTranscript.contains("return a bool") ||
           lowerTranscript.contains("return true") || lowerTranscript.contains("return false") ||
           lowerTranscript.contains("true if") || lowerTranscript.contains("false if") ||
           lowerTranscript.contains("bool") {
            returnType = "bool"
        } else if lowerName.contains("classify") || lowerName.contains("label") || lowerName.contains("category") {
            returnType = "str"
        } else if lowerTranscript.contains("score") || lowerTranscript.contains("rating") || lowerTranscript.contains("count") {
            returnType = "int"
        } else {
            returnType = "bool"
        }

        // Extract rules from user messages as edge cases
        // Pull all user-stated conditions from the conversation
        let userMessages = conversationHistory
            .filter { $0.role == "user" }
            .map { $0.content }
        let edgeCases = extractRulesFromUserMessages(userMessages)

        return (
            [FunctionParameter(name: paramName, type: paramType, description: paramDescription)],
            returnType,
            edgeCases
        )
    }

    /// Extract explicit rules and conditions stated by the user in their messages.
    private func extractRulesFromUserMessages(_ messages: [String]) -> [String] {
        var rules: [String] = []
        for message in messages {
            // Split on common delimiters: periods, semicolons, "and", newlines
            let sentences = message
                .components(separatedBy: CharacterSet(charactersIn: ".,;\n"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            for sentence in sentences {
                let lower = sentence.lowercased()
                // Keep sentences that express conditions or rules
                let isRule = lower.contains("if ") || lower.contains("when ") ||
                             lower.contains("return ") || lower.contains("should ") ||
                             lower.contains("more than") || lower.contains("less than") ||
                             lower.contains("greater than") || lower.contains("at least") ||
                             lower.contains("repeats") || lower.contains("contains") ||
                             lower.contains("true if") || lower.contains("false if") ||
                             lower.hasPrefix("it's") || lower.hasPrefix("its")
                if isRule && sentence.count > 8 && sentence.count < 200 {
                    rules.append(sentence)
                }
            }
        }
        return rules.isEmpty ? ["See conversation transcript for full specification"] : rules
    }

    /// Scan user messages for explicit function name declarations like
    /// "the function will be called X" or "name it X" or "call it X".
    /// Returns a snake_case version of the name, or nil if not found.
    private func extractExplicitFunctionName(from transcript: String) -> String? {
        let patterns = [
            "(?:function will be called|function called|call it|name it|named|called)\\s+([A-Za-z_][A-Za-z0-9_]*)",
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: transcript, range: NSRange(transcript.startIndex..., in: transcript)),
               let range = Range(match.range(at: 1), in: transcript) {
                let name = String(transcript[range])
                // Convert camelCase to snake_case for Python convention
                let snake = name
                    .replacingOccurrences(of: "([A-Z])", with: "_$1", options: .regularExpression)
                    .lowercased()
                    .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
                print("✅ [MLXLLMService] Extracted explicit function name: \(name) → \(snake)")
                return snake
            }
        }
        return nil
    }

    /// Build a purpose string that includes the user-defined rules for the server.
    private func buildPurposeWithRules(intent: IntentAnalysis, transcript: String) -> String {
        let base = intent.purpose ?? "Process input and return result"
        // The transcript contains the rules — tell the server to look there
        return "\(base). IMPORTANT: Implement using the exact rules defined in the conversation transcript."
    }

    /// Build a clean conversation transcript from history (user/assistant turns only)
    private func buildConversationTranscript() -> String {
        let lines = conversationHistory.compactMap { msg -> String? in
            switch msg.role {
            case "user":
                return "User: \(msg.content)"
            case "assistant":
                // Skip internal ready-to-generate prompts - not useful context for server
                let lower = msg.content.lowercased()
                if lower.contains("say 'generate code'") || lower.contains("say generate code") {
                    return nil
                }
                return "Assistant: \(msg.content)"
            default:
                return nil
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Get requirements details for known function types
    private func getRequirementsForFunction(name: String, type: IntentAnalysis.FunctionType) -> ([FunctionParameter], String, [String]) {
        // Check for well-known patterns
        let lowerName = name.lowercased()

        if lowerName.contains("palindrome") {
            return (
                [FunctionParameter(name: "s", type: "str", description: "The string to check")],
                "bool",
                [
                    "Empty string returns True",
                    "Single character returns True",
                    "Case insensitive comparison",
                    "Ignore non-alphanumeric characters"
                ]
            )
        } else if lowerName.contains("prime") {
            return (
                [FunctionParameter(name: "n", type: "int", description: "The number to check for primality")],
                "bool",
                [
                    "n < 2 returns False",
                    "n = 2 returns True",
                    "Handle negative numbers by returning False"
                ]
            )
        } else if lowerName.contains("fib") {
            return (
                [FunctionParameter(name: "n", type: "int", description: "The position in Fibonacci sequence")],
                "int",
                [
                    "n < 0 raises ValueError",
                    "n = 0 returns 0",
                    "n = 1 returns 1"
                ]
            )
        } else if lowerName.contains("sort") {
            return (
                [FunctionParameter(name: "arr", type: "list[int]", description: "The list to sort")],
                "list[int]",
                [
                    "Empty list returns empty list",
                    "Single element list returns itself",
                    "Handle duplicate values"
                ]
            )
        }

        // Default for custom functions
        return (
            [FunctionParameter(name: "input", type: "Any", description: "Input parameter")],
            "Any",
            ["Handle edge cases appropriately"]
        )
    }

    /// Fallback: Extract requirements using pattern matching
    private func extractRequirementsWithPatternMatching() -> FunctionRequirements {
        print("🔎 [MLXLLMService] extractRequirementsWithPatternMatching() started")

        var functionName = "my_function"
        var purpose = "Perform a task"
        var parameters: [FunctionParameter] = []
        var edgeCases: [String] = []

        // Get the most recent user messages (limit to last 5 to focus on current request)
        let recentMessages = conversationHistory
            .filter { $0.role == "user" }
            .suffix(5)

        print("🔍 [MLXLLMService] Examining last \(recentMessages.count) user messages:")
        for (index, msg) in recentMessages.enumerated() {
            print("   [\(index)] \(msg.content)")
        }

        // Look through recent conversation for clues
        // Process in reverse order so most recent takes precedence
        for (index, message) in recentMessages.reversed().enumerated() {
            let content = message.content.lowercased()
            print("🔍 [MLXLLMService] Checking message \(index) (reversed): \"\(message.content)\"")

            // Expanded pattern matching
            var foundMatch = false

            if content.contains("palindrome") {
                print("✓ [MLXLLMService] Matched pattern: PALINDROME")
                functionName = "is_palindrome"
                purpose = "Check if a string is a palindrome"
                parameters = [
                    FunctionParameter(name: "s", type: "str", description: "The string to check")
                ]
                edgeCases = [
                    "Empty string returns True",
                    "Single character returns True",
                    "Case insensitive comparison",
                    "Ignore non-alphanumeric characters"
                ]
                foundMatch = true
            } else if content.contains("prime") {
                print("✓ [MLXLLMService] Matched pattern: PRIME")
                functionName = "is_prime"
                purpose = "Check if a number is prime"
                parameters = [
                    FunctionParameter(name: "n", type: "int", description: "The number to check for primality")
                ]
                edgeCases = [
                    "n < 2 returns False",
                    "n = 2 returns True",
                    "Handle negative numbers by returning False"
                ]
                foundMatch = true
            } else if content.contains("fibonacci") || content.contains("fib") {
                print("✓ [MLXLLMService] Matched pattern: FIBONACCI")
                functionName = "fibonacci"
                purpose = "Calculate the nth Fibonacci number"
                parameters = [
                    FunctionParameter(name: "n", type: "int", description: "The position in Fibonacci sequence")
                ]
                edgeCases = [
                    "n < 0 raises ValueError",
                    "n = 0 returns 0",
                    "n = 1 returns 1"
                ]
                foundMatch = true
            } else if content.contains("sort") {
                print("✓ [MLXLLMService] Matched pattern: SORT")
                functionName = "sort_list"
                purpose = "Sort a list of numbers"
                parameters = [
                    FunctionParameter(name: "arr", type: "list[int]", description: "The list to sort")
                ]
                edgeCases = [
                    "Empty list returns empty list",
                    "Single element list returns itself",
                    "Handle duplicate values"
                ]
                foundMatch = true
            } else {
                print("✗ [MLXLLMService] No pattern matched in this message")
            }

            // Extract additional edge cases from user messages
            if content.contains("negative") && !edgeCases.contains(where: { $0.contains("negative") }) {
                edgeCases.append("Handle negative numbers")
            }
            if content.contains("zero") || content.contains("0") {
                if !edgeCases.contains(where: { $0.contains("zero") || $0.contains("0") }) {
                    edgeCases.append("Handle zero input")
                }
            }

            // Stop at first matched function
            if foundMatch {
                print("🎯 [MLXLLMService] Found match, stopping search")
                break
            }
        }

        let requirements = FunctionRequirements(
            name: functionName,
            purpose: purpose,
            parameters: parameters,
            returnType: functionName.contains("prime") || functionName.contains("palindrome") ? "bool" : "int",
            edgeCases: edgeCases,
            examples: generateExamples(for: functionName),
            conversationTranscript: nil
        )

        print("📋 [MLXLLMService] Extracted requirements:")
        print("   Name: \(requirements.name)")
        print("   Purpose: \(requirements.purpose)")
        print("   Parameters: \(requirements.parameters.count)")
        print("   Return Type: \(requirements.returnType)")
        print("   Edge Cases: \(requirements.edgeCases.count)")
        print("   Examples: \(requirements.examples.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        return requirements
    }

    /// Generate examples based on function type
    private func generateExamples(for functionName: String) -> [FunctionExample] {
        if functionName.contains("palindrome") {
            return [
                FunctionExample(input: "\"racecar\"", output: "True"),
                FunctionExample(input: "\"A man, a plan, a canal, Panama\"", output: "True"),
                FunctionExample(input: "\"hello\"", output: "False"),
                FunctionExample(input: "\"\"", output: "True")
            ]
        } else if functionName.contains("prime") {
            return [
                FunctionExample(input: "2", output: "True"),
                FunctionExample(input: "4", output: "False"),
                FunctionExample(input: "17", output: "True"),
                FunctionExample(input: "1", output: "False")
            ]
        } else if functionName.contains("fibonacci") {
            return [
                FunctionExample(input: "0", output: "0"),
                FunctionExample(input: "1", output: "1"),
                FunctionExample(input: "5", output: "5"),
                FunctionExample(input: "10", output: "55")
            ]
        } else if functionName.contains("sort") {
            return [
                FunctionExample(input: "[3, 1, 4, 1, 5]", output: "[1, 1, 3, 4, 5]"),
                FunctionExample(input: "[]", output: "[]"),
                FunctionExample(input: "[1]", output: "[1]")
            ]
        } else {
            return []
        }
    }

    func classifyFlowchartComplexity(requirements: FunctionRequirements) async throws -> FlowchartComplexity {
        guard isReady else {
            throw MLXError.modelNotReady
        }

        // Simulate thinking delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Enhanced heuristic classification
        let purposeLower = requirements.purpose.lowercased()
        let functionNameLower = requirements.name.lowercased()

        // Simple functions that should use local generation
        let simplePatterns = ["palindrome", "prime", "even", "odd", "vowel", "consonant"]
        for pattern in simplePatterns {
            if functionNameLower.contains(pattern) {
                print("📊 Classified as SIMPLE (common pattern: \(pattern))")
                return .simple
            }
        }

        // Complex keywords indicating loops, recursion, or multiple branches
        let complexKeywords = [
            "loop", "iterate", "iteration", "while", "for",
            "recursion", "recursive", "recurse",
            "multiple", "nested", "several",
            "sort", "search", "traverse", "binary",
            "fibonacci", "factorial", "permutation", "combination"
        ]

        // Check function name and purpose for complex keywords
        for keyword in complexKeywords {
            if purposeLower.contains(keyword) || functionNameLower.contains(keyword) {
                print("📊 Classified as COMPLEX (keyword: \(keyword))")
                return .complex
            }
        }

        // Check edge case count (many edge cases = complex)
        // Increased threshold since well-defined functions often have multiple edge cases
        if requirements.edgeCases.count > 5 {
            print("📊 Classified as COMPLEX (>5 edge cases)")
            return .complex
        }

        // Check parameter count (many params = likely complex)
        if requirements.parameters.count > 2 {
            print("📊 Classified as COMPLEX (>2 parameters)")
            return .complex
        }

        // Check for array/list parameters (often indicates iteration)
        for param in requirements.parameters {
            if param.type.lowercased().contains("list") ||
               param.type.lowercased().contains("array") {
                print("📊 Classified as COMPLEX (list/array parameter)")
                return .complex
            }
        }

        print("📊 Classified as SIMPLE")
        return .simple
    }

}

/// MLX-specific errors
enum MLXError: LocalizedError {
    case modelNotReady
    case tokenizationFailed
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotReady:
            return "MLX model is still initializing. Please wait a moment."
        case .tokenizationFailed:
            return "Failed to tokenize input text"
        case .inferenceFailed(let reason):
            return "Inference failed: \(reason)"
        }
    }
}

#endif
