class Composer {
  final int? id;
  final String name;
  final int? bornYear;
  final int? diedYear;

  const Composer({
    this.id,
    required this.name,
    this.bornYear,
    this.diedYear,
  });

  factory Composer.fromMap(Map<String, dynamic> map) {
    return Composer(
      id: map['id'] as int?,
      name: map['name'] as String,
      bornYear: map['born_year'] as int?,
      diedYear: map['died_year'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'born_year': bornYear,
      'died_year': diedYear,
    };
  }

  Composer copyWith({
    int? id,
    String? name,
    int? bornYear,
    int? diedYear,
  }) {
    return Composer(
      id: id ?? this.id,
      name: name ?? this.name,
      bornYear: bornYear ?? this.bornYear,
      diedYear: diedYear ?? this.diedYear,
    );
  }

  @override
  String toString() => name;
}
