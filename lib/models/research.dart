class ResearchReport {
  final String summary;
  final String problem;
  final String solution;
  final String targetMarket;
  final List<String> competitors;
  final String costRange;
  final String costBreakdown;
  final int potentialScore;
  final List<String> keyInsights;
  final List<String> sources;

  ResearchReport({
    required this.summary,
    required this.problem,
    required this.solution,
    required this.targetMarket,
    required this.competitors,
    required this.costRange,
    required this.costBreakdown,
    required this.potentialScore,
    required this.keyInsights,
    this.sources = const [],
  });

  factory ResearchReport.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) => (v as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    return ResearchReport(
      summary: json['summary']?.toString() ?? '',
      problem: json['problem']?.toString() ?? '',
      solution: json['solution']?.toString() ?? '',
      targetMarket: json['targetMarket']?.toString() ?? '',
      competitors: strings(json['competitors']),
      costRange: json['costRange']?.toString() ?? '',
      costBreakdown: json['costBreakdown']?.toString() ?? '',
      potentialScore: int.tryParse(json['potentialScore'].toString()) ?? 0,
      keyInsights: strings(json['keyInsights']),
      sources: strings(json['sources']),
    );
  }
}
