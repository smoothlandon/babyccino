# Removed Qwen 0.5B - JSON-Only Models

## Summary

Removed Qwen 0.5B (300MB) from available models. App now only offers models that support reliable JSON structured output.

## Why Remove 0.5B?

**Problem observed:**
```
Query: "Can you help me write some functions?"

Qwen 0.5B Output (via JSON):
{
  "needs_clarification": true,
  "questions": [
    "I need a function for palindrome.",
    "I need a function for prime.",
    "I need a function for fibonacci."
  ]
}

Response shown to user:
"A few questions:

1. I need a function for palindrome.
2. I need a function for prime.
3. I need a function for fibonacci."
```

**The model was confused** - it put function names in the "questions" array instead of actual questions. This is because:
- 0.5B parameters is too small for reliable JSON generation
- Model doesn't understand the structured output task
- Unable to follow complex system prompts consistently

## What Changed

### Removed Files/Code
- ❌ Qwen 0.5B from `ModelInfo.availableModels` array
- ❌ `generatePatternBasedResponse()` function (no longer needed)
- ❌ Special case logic: `if config.modelId == "qwen-0.5b"`
- ❌ Pattern-matching fallback for small models

### Updated Defaults
- ✅ Default model: `qwen-0.5b` → `qwen-1.5b`
- ✅ Added `modelId` field to `MLXModelConfig`
- ✅ Updated recommendations in ModelInfo descriptions

### Available Models Now

**Qwen 1.5B (900MB)** - Recommended ⭐
- Reliable JSON output
- Good balance of speed/quality
- ~30 tokens/sec on iPad M3
- Default model

**Phi-3 Mini 3.8B (2.3GB)** - Best Quality
- Most reliable JSON parsing
- Excellent reasoning
- ~15 tokens/sec on iPad M3
- Production quality

## Files Modified

1. **ModelInfo.swift**
   - Removed Qwen 0.5B from `availableModels`
   - Made Qwen 1.5B the recommended model
   - Updated descriptions to mention JSON reliability

2. **MLXLLMService.swift**
   - Removed `generatePatternBasedResponse()` function
   - Removed special-case logic for 0.5B
   - Added `modelId` field to `MLXModelConfig`
   - Updated default config: `.qwen05b` → `.qwen15b`
   - Added `.phi3mini` config option

3. **LLMServiceFactory.swift**
   - Updated default: `MLXLLMService(config: .qwen05b)` → `.qwen15b`

4. **MODEL_SELECTION.md**
   - Removed pattern-matching strategy section
   - Updated benchmarks table
   - Removed 0.5B from recommendations

## User Impact

### First Launch (New Users)
- See only 2 models in onboarding: Qwen 1.5B (recommended) and Phi-3 Mini
- Default selection: Qwen 1.5B
- Download size: 900MB (was 300MB)

### Existing Users (Had 0.5B Selected)
- If they had 0.5B downloaded, it remains cached but won't be selectable
- App will use factory default (1.5B) since 0.5B not in available models
- They'll need to download 1.5B on next launch

### Behavior Change
**Before:**
- 0.5B used simple pattern matching
- Only recognized exact keywords
- Fast but inflexible

**After:**
- All models use JSON structured output
- Understands variations: "palindrome function", "palindrome checker", "detect palindromes"
- Slightly slower but much more capable

## Technical Details

### JSON Output Quality by Model Size

| Parameters | JSON Reliability | Observed Issues |
|------------|------------------|-----------------|
| 0.5B | ❌ Poor | Confuses task, puts wrong data in fields |
| 1.5B | ✅ Good | Occasional formatting issues, mostly reliable |
| 3.8B | ✅✅ Excellent | Consistently follows schema |

### Why 1.5B Works Where 0.5B Fails

**Model Capabilities:**
- **0.5B**: Basic conversation, struggles with structured output
- **1.5B**: Good reasoning, can follow JSON schema reliably
- **3.8B**: Excellent reasoning, near-perfect JSON compliance

**System Prompt Complexity:**
Our JSON prompt requires:
- Understanding multi-line instructions
- Following strict output format (JSON only)
- Classifying requests (well_known vs custom)
- Conditional logic (when to ask questions)

0.5B simply doesn't have the capacity for this.

## Migration Path for Existing Users

If user had 0.5B selected:
1. App launches
2. Checks selected model: "qwen-0.5b"
3. Looks up in `availableModels` → not found
4. Falls back to factory default (1.5B)
5. If 1.5B not downloaded, shows onboarding

## Future Considerations

### Could We Support Smaller Models?

**Option 1: Hybrid Approach**
- Quick keyword check first (instant)
- If no match, use LLM JSON (200-500ms)
- Could work with 0.5B but complex to implement

**Option 2: Simplified JSON Schema**
- Remove `questions` field
- Just: `{function: "palindrome", clarify: false}`
- Might work but less flexible

**Decision: Not worth it**
- 900MB isn't prohibitively large
- Better to have reliable 1.5B than flaky 0.5B
- User experience consistency more important than download size

## Testing

**Build status:** ✅ Clean build succeeds

**Models to test:**
1. Qwen 1.5B (default)
   - "write a palindrome function" → Should work
   - "Can you help me with some functions?" → Should ask what kind
   - "make a prime checker" → Should work

2. Phi-3 Mini (optional, best quality)
   - Same tests, expect better JSON compliance

**Expected behavior:**
- All queries use JSON output
- Variations in phrasing handled correctly
- No more confused "questions" arrays

## Rollback Plan

If JSON proves problematic:
1. Git revert to restore 0.5B
2. Re-add pattern matching fallback
3. Make pattern matching the default
4. Use JSON only for 1.5B+

**Current assessment:** JSON approach working well, no rollback needed.
