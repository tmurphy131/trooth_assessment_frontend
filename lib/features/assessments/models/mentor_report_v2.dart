import 'dart:convert';

class MentorReportV2 {
  final Snapshot snapshot;
  final BiblicalKnowledge? biblicalKnowledge;
  final List<OpenEndedInsight> openEndedInsights;
  final Flags flags;
  final FourWeekPlan fourWeekPlan;
  final List<String> conversationStarters;
  final List<RecommendedResource> recommendedResources;
  final PriorityAction? priorityAction;

  MentorReportV2({
    required this.snapshot,
    required this.biblicalKnowledge,
    required this.openEndedInsights,
    required this.flags,
    required this.fourWeekPlan,
    required this.conversationStarters,
    required this.recommendedResources,
    this.priorityAction,
  });

  factory MentorReportV2.fromJson(Map<String, dynamic> json) {
    // Detect v2.1 format (has health_score at top level) vs v2.0 (has snapshot)
    final isV21 = json.containsKey('health_score');
    
    Snapshot snapshot;
    BiblicalKnowledge? biblicalKnowledge;
    List<OpenEndedInsight> openEndedInsights;
    PriorityAction? priorityAction;
    
    if (isV21) {
      // v2.1 format from ai_prompt_master_assessment_v2_optimized.txt
      snapshot = Snapshot(
        overallMcPercent: (json['biblical_knowledge']?['percent'] as num?) ?? (json['health_score'] as num? ?? 0),
        knowledgeBand: json['health_band'] as String? ?? '',
        topStrengths: (json['strengths'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
        topGaps: (json['gaps'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
      );
      
      // v2.1 biblical_knowledge has percent and weak_topics
      final bk = json['biblical_knowledge'] as Map<String, dynamic>?;
      if (bk != null) {
        biblicalKnowledge = BiblicalKnowledge.fromV21Json(bk);
      }
      
      // v2.1 uses 'insights' instead of 'open_ended_insights'
      openEndedInsights = (json['insights'] as List<dynamic>? ?? [])
          .map((e) => OpenEndedInsight.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      
      // v2.1 has priority_action
      if (json['priority_action'] != null) {
        priorityAction = PriorityAction.fromJson(json['priority_action'] as Map<String, dynamic>);
      }
    } else {
      // v2.0 format (legacy)
      if (json['snapshot'] == null) throw FormatException('snapshot missing');
      snapshot = Snapshot.fromJson(json['snapshot'] as Map<String, dynamic>);
      biblicalKnowledge = json['biblical_knowledge'] == null 
          ? null 
          : BiblicalKnowledge.fromJson(json['biblical_knowledge'] as Map<String, dynamic>);
      openEndedInsights = (json['open_ended_insights'] as List<dynamic>? ?? [])
          .map((e) => OpenEndedInsight.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }
    
    return MentorReportV2(
      snapshot: snapshot,
      biblicalKnowledge: biblicalKnowledge,
      openEndedInsights: openEndedInsights,
      flags: Flags.fromJson((json['flags'] as Map<String, dynamic>? ?? {})),
      fourWeekPlan: FourWeekPlan.fromJson((json['four_week_plan'] as Map<String, dynamic>? ?? {})),
      conversationStarters: (json['conversation_starters'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
      recommendedResources: (json['recommended_resources'] as List<dynamic>? ?? [])
          .map((e) => RecommendedResource.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      priorityAction: priorityAction,
    );
  }

  Map<String, dynamic> toJson() => {
        'snapshot': snapshot.toJson(),
        if (biblicalKnowledge != null) 'biblical_knowledge': biblicalKnowledge!.toJson(),
        'open_ended_insights': openEndedInsights.map((e) => e.toJson()).toList(),
        'flags': flags.toJson(),
        'four_week_plan': fourWeekPlan.toJson(),
        'conversation_starters': conversationStarters,
        'recommended_resources': recommendedResources.map((e) => e.toJson()).toList(),
        if (priorityAction != null) 'priority_action': priorityAction!.toJson(),
      };
}

/// Priority action for focused mentoring
class PriorityAction {
  final String title;
  final List<String> steps;
  final String scripture;

  PriorityAction({required this.title, required this.steps, required this.scripture});

  factory PriorityAction.fromJson(Map<String, dynamic> json) {
    return PriorityAction(
      title: json['title'] as String? ?? '',
      steps: (json['steps'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
      scripture: json['scripture'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'steps': steps,
        'scripture': scripture,
      };
}

class Snapshot {
  final num overallMcPercent;
  final String knowledgeBand;
  final List<String> topStrengths;
  final List<String> topGaps;

  Snapshot({
    required this.overallMcPercent,
    required this.knowledgeBand,
    required this.topStrengths,
    required this.topGaps,
  });

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    if (json['overall_mc_percent'] == null || json['knowledge_band'] == null) {
      throw FormatException('snapshot keys missing');
    }
    return Snapshot(
      overallMcPercent: (json['overall_mc_percent'] as num),
      knowledgeBand: json['knowledge_band'] as String,
      topStrengths: (json['top_strengths'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
      topGaps: (json['top_gaps'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'overall_mc_percent': overallMcPercent,
        'knowledge_band': knowledgeBand,
        'top_strengths': topStrengths,
        'top_gaps': topGaps,
      };
}

class BiblicalKnowledge {
  final String? summary;
  final List<TopicBreakdown> topicBreakdown;
  final List<String> studyTargets;
  final num? percent;
  final List<String>? weakTopics;

  BiblicalKnowledge({
    this.summary, 
    required this.topicBreakdown, 
    required this.studyTargets,
    this.percent,
    this.weakTopics,
  });

  factory BiblicalKnowledge.fromJson(Map<String, dynamic> json) {
    return BiblicalKnowledge(
      summary: json['summary'] as String?,
      topicBreakdown: (json['topic_breakdown'] as List<dynamic>? ?? [])
          .map((e) => TopicBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      studyTargets: (json['study_targets'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
      percent: json['percent'] as num?,
      weakTopics: json['weak_topics'] != null 
          ? (json['weak_topics'] as List<dynamic>).map((e) => e.toString()).toList(growable: false)
          : null,
    );
  }
  
  /// Parse v2.1 format which has percent and weak_topics only
  factory BiblicalKnowledge.fromV21Json(Map<String, dynamic> json) {
    return BiblicalKnowledge(
      summary: null,
      topicBreakdown: [],
      studyTargets: [],
      percent: json['percent'] as num?,
      weakTopics: json['weak_topics'] != null 
          ? (json['weak_topics'] as List<dynamic>).map((e) => e.toString()).toList(growable: false)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (summary != null) 'summary': summary,
        'topic_breakdown': topicBreakdown.map((e) => e.toJson()).toList(),
        'study_targets': studyTargets,
        if (percent != null) 'percent': percent,
        if (weakTopics != null) 'weak_topics': weakTopics,
      };
}

class TopicBreakdown {
  final String topic;
  final int correct;
  final int total;
  final String? note;

  TopicBreakdown({required this.topic, required this.correct, required this.total, this.note});

  factory TopicBreakdown.fromJson(Map<String, dynamic> json) {
    if (json['topic'] == null) throw FormatException('topic missing');
    return TopicBreakdown(
      topic: json['topic'] as String,
      correct: (json['correct'] as num? ?? 0).toInt(),
      total: (json['total'] as num? ?? 0).toInt(),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'correct': correct,
        'total': total,
        if (note != null) 'note': note,
      };
}

class OpenEndedInsight {
  final String title;
  final String observation;
  final String evidence;
  final String level;
  final String nextStep;

  OpenEndedInsight({
    required this.title,
    required this.observation,
    required this.evidence,
    required this.level,
    required this.nextStep,
  });

  factory OpenEndedInsight.fromJson(Map<String, dynamic> json) {
    // v2.1 format: { category, level, evidence, next_step }
    if (json.containsKey('category') && json.containsKey('evidence') && json.containsKey('next_step')) {
      return OpenEndedInsight(
        title: (json['category'] ?? 'Insight').toString(),
        observation: (json['evidence'] ?? '').toString(), // v2.1 uses evidence as observation
        evidence: (json['evidence'] ?? '').toString(),
        level: (json['level'] ?? '').toString(),
        nextStep: (json['next_step'] ?? '').toString(),
      );
    }
    
    // v2.0 shape with title
    if (json.containsKey('title')) {
      return OpenEndedInsight(
        title: json['title'] as String,
        observation: (json['observation'] ?? '').toString(),
        evidence: (json['evidence'] ?? '').toString(),
        level: (json['level'] ?? '').toString(),
        nextStep: (json['next_step'] ?? json['nextStep'] ?? '').toString(),
      );
    }

    // Backward-compat: legacy v2.0 shape { category, level, evidence, discernment, scripture_anchor, mentor_moves[] }
    if (json.containsKey('category')) {
      final moves = (json['mentor_moves'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false);
      return OpenEndedInsight(
        title: (json['category'] ?? 'Insight').toString(),
        observation: (json['discernment'] ?? json['observation'] ?? '').toString(),
        evidence: (json['evidence'] ?? json['scripture_anchor'] ?? '').toString(),
        level: (json['level'] ?? '').toString(),
        nextStep: moves.isNotEmpty ? moves.join('; ') : (json['next_step'] ?? '').toString(),
      );
    }

    // Fallback - return empty insight rather than throwing
    return OpenEndedInsight(
      title: 'Insight',
      observation: '',
      evidence: '',
      level: '',
      nextStep: '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'observation': observation,
        'evidence': evidence,
        'level': level,
        'next_step': nextStep,
      };
}

class Flags {
  final List<String> red;
  final List<String> yellow;
  final List<String> green;

  Flags({required this.red, required this.yellow, required this.green});

  factory Flags.fromJson(Map<String, dynamic> json) {
    return Flags(
      red: (json['red'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
      yellow: (json['yellow'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
      green: (json['green'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'red': red,
        'yellow': yellow,
        'green': green,
      };
}

class FourWeekPlan {
  final List<String> rhythm;
  final List<String> checkpoints;

  FourWeekPlan({required this.rhythm, required this.checkpoints});

  factory FourWeekPlan.fromJson(Map<String, dynamic> json) {
    return FourWeekPlan(
      rhythm: (json['rhythm'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
      checkpoints: (json['checkpoints'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'rhythm': rhythm,
        'checkpoints': checkpoints,
      };
}

class RecommendedResource {
  final String title;
  final String why;
  final String type;

  RecommendedResource({required this.title, required this.why, required this.type});

  factory RecommendedResource.fromJson(Map<String, dynamic> json) {
    for (final k in ['title','why','type']) { if (!json.containsKey(k)) throw FormatException('resource missing $k'); }
    return RecommendedResource(
      title: json['title'] as String,
      why: json['why'] as String,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'why': why,
        'type': type,
      };
}
