class ClimeModel {
  final int number;
  final String name;
  final String arabicName;
  final String bounds;
  final String description;
  final String shortTitle;

  const ClimeModel({
    required this.number,
    required this.name,
    required this.arabicName,
    required this.bounds,
    required this.description,
    this.shortTitle = '',
  });

  factory ClimeModel.fromJson(Map<String, dynamic> json) {
    return ClimeModel(
      number: json['number'] as int,
      name: json['name'] as String,
      arabicName: json['arabicName'] as String,
      bounds: json['bounds'] as String,
      description: json['description'] as String,
      shortTitle: json['shortTitle'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'name': name,
      'arabicName': arabicName,
      'bounds': bounds,
      'description': description,
      'shortTitle': shortTitle,
    };
  }
}
