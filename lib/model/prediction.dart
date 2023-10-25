class Prediction {
  Prediction._({required this.label, required this.score});

  final String label;
  final double score;

  Prediction.fromMap(Map<String, dynamic> map)
      : this._(label: map['label'], score: map['score']);
}
