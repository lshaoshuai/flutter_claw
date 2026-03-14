import 'dart:convert';
import '../llm/llm_client.dart';
import '../utils/logger.dart';

/// Task Difficulty Enumeration
enum TaskDifficulty {
  /// Level 1: Simple queries, format conversion, explicit API calls.
  /// (Suitable for ultra-fast/cheap models like Gemini Flash)
  level1_simple,

  /// Level 2: Data analysis, simple logic coding, copywriting.
  /// (Suitable for mid-tier models like GPT-4o-mini or Claude Haiku)
  level2_moderate,

  /// Level 3: Complex multi-table correlation analysis, deep strategic planning, complex debugging.
  /// (Suitable for frontier models like GPT-4o or Claude 3.5 Sonnet)
  level3_complex,

  /// Unknown difficulty; defaults to moderate processing.
  unknown,
}

/// Domain Tag Enumeration (Used to dispatch to specific Domain Agents or load specific SOPs)
enum DomainTag {
  data_analysis, // Data Analysis (CSV/Excel processing, SQL generation)
  content_ops, // Content Operations (Copywriting, SEO, Social Media)
  user_ops, // User Operations (CRM queries, Email dispatch)
  general_qa, // General Q&A (Does not require code execution)
}

/// Routing Decision Result
class RouteDecision {
  final TaskDifficulty difficulty;
  final DomainTag domain;
  final String
  reasoning; // The logic behind the model's decision (for Debugging/Logging)

  RouteDecision({
    required this.difficulty,
    required this.domain,
    required this.reasoning,
  });

  factory RouteDecision.fromJson(Map<String, dynamic> json) {
    return RouteDecision(
      difficulty: _parseDifficulty(json['difficulty']),
      domain: _parseDomain(json['domain']),
      reasoning: json['reasoning'] ?? 'No reasoning provided.',
    );
  }

  static TaskDifficulty _parseDifficulty(String? value) {
    switch (value?.toLowerCase()) {
      case 'level1':
        return TaskDifficulty.level1_simple;
      case 'level2':
        return TaskDifficulty.level2_moderate;
      case 'level3':
        return TaskDifficulty.level3_complex;
      default:
        return TaskDifficulty.unknown;
    }
  }

  static DomainTag _parseDomain(String? value) {
    switch (value?.toLowerCase()) {
      case 'data':
        return DomainTag.data_analysis;
      case 'content':
        return DomainTag.content_ops;
      case 'user':
        return DomainTag.user_ops;
      default:
        return DomainTag.general_qa;
    }
  }

  @override
  String toString() {
    return 'RouteDecision(Difficulty: $difficulty, Domain: $domain, Reasoning: $reasoning)';
  }
}

/// Router Agent (The "Triage Desk"): Responsible for parsing user intent and classifying difficulty/domain.
class RouterAgent {
  // The Router Agent should use the fastest, cheapest model (e.g., Gemini Flash),
  // as it only makes classification decisions and performs no heavy lifting.
  final LLMClient fastLlmClient;

  RouterAgent({required this.fastLlmClient});

  /// Analyzes the user instruction and returns a routing decision.
  Future<RouteDecision> analyzeTask(String userInstruction) async {
    Log.i('🚦 RouterAgent is analyzing task complexity...');

    final prompt = _buildRoutingPrompt(userInstruction);

    try {
      // Force the model to output in JSON format
      final responseText = await fastLlmClient.generateJson(prompt);
      final jsonMap = jsonDecode(responseText);

      final decision = RouteDecision.fromJson(jsonMap);
      Log.i('🧭 Routing decision complete: $decision');
      return decision;
    } catch (e) {
      Log.e(
        '⚠️ RouterAgent analysis failed; falling back to default moderate routing: $e',
      );
      // Fallback mechanism: If parsing fails, default to a moderate data analysis flow.
      return RouteDecision(
        difficulty: TaskDifficulty.level2_moderate,
        domain: DomainTag.data_analysis,
        reasoning: 'Fallback due to parsing error.',
      );
    }
  }

  /// Builds the System Prompt specific to routing.
  /// This Prompt is critical as it defines how the system distinguishes "simple" from "complex."
  String _buildRoutingPrompt(String instruction) {
    return '''
You are the "Triage Dispatcher (Router)" for an advanced Multi-Agent Operations System.
Your sole job is to analyze natural language user requirements, assess their difficulty, and apply appropriate domain tags.

【Assessment Criteria - Difficulty (difficulty)】
- "level1" (Simple): No complex logical reasoning or long code generation required. Examples: "Check the views for a specific article from yesterday," "Convert this text to Markdown," "Call an email dispatch API."
- "level2" (Moderate): Requires writing medium-length scripts for data processing or standard copywriting. Examples: "Read the local sales.csv, calculate the average order value, and plot a bar chart," "Write a social media post based on this product documentation."
- "level3" (Complex): Requires deep thinking, multi-step reasoning, spanning multiple data sources, or writing complex analysis algorithms. Examples: "Combine last week's churn data with competitors' pricing strategies to write a user retention plan and run a predictive model locally."

【Assessment Criteria - Domain (domain)】
- "data": Clearly involves numbers, tables (CSV/Excel), reports, or statistical calculations.
- "content": Involves writing articles, translation, polishing, or social media copy.
- "user": Involves querying user info, sending messages, customer support tickets, or user profiling/tagging.
- "general": Other pure text Q&A that does not require a local sandbox environment.

【User Requirement】
"$instruction"

【Output Requirements】
You must ONLY output a valid JSON object. Do not include Markdown tags (like ```json) or any other conversational filler.
Format:
{
  "difficulty": "level1" | "level2" | "level3",
  "domain": "data" | "content" | "user" | "general",
  "reasoning": "A one-sentence explanation of why you classified it this way."
}
''';
  }
}
