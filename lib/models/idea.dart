class Idea {
  final String id;
  final String title;
  final String? notes;
  final String? imagePath; // storage object path, e.g. userId/images/...
  final String? audioPath; // storage object path
  final DateTime createdAt;
  bool isFavorite;
  bool reminderEnabled;
  DateTime? reminderAt;

  String? imageUrl; // transient signed URL for display
  String? audioUrl; // transient signed URL for playback

  Idea({
    required this.id,
    required this.title,
    this.notes,
    this.imagePath,
    this.audioPath,
    required this.createdAt,
    this.isFavorite = false,
    this.reminderEnabled = false,
    this.reminderAt,
    this.imageUrl,
    this.audioUrl,
  });

  bool get hasMedia => imagePath != null || audioPath != null;

  static const Object _unset = Object();

  Idea copyWith({
    String? title,
    String? notes,
    String? imagePath,
    String? audioPath,
    bool? isFavorite,
    bool? reminderEnabled,
    Object? reminderAt = _unset,
    String? imageUrl,
    String? audioUrl,
  }) {
    return Idea(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      audioPath: audioPath ?? this.audioPath,
      createdAt: createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderAt: identical(reminderAt, _unset)
          ? this.reminderAt
          : reminderAt as DateTime?,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'notes': notes,
        'image_url': imagePath,
        'audio_url': audioPath,
        'is_favorite': isFavorite,
        'reminder_at': reminderAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory Idea.fromMap(Map<String, dynamic> json) => Idea(
        id: json['id'] as String,
        title: json['title'] as String,
        notes: json['notes'] as String?,
        imagePath: json['image_url'] as String?,
        audioPath: json['audio_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        isFavorite: json['is_favorite'] as bool? ?? false,
        reminderEnabled: json['reminder_at'] != null,
        reminderAt: json['reminder_at'] != null
            ? DateTime.parse(json['reminder_at'] as String).toLocal()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'imagePath': imagePath,
        'audioPath': audioPath,
        'createdAt': createdAt.toIso8601String(),
        'isFavorite': isFavorite,
        'reminderEnabled': reminderEnabled,
        'reminderAt': reminderAt?.toIso8601String(),
      };

  factory Idea.fromJson(Map<String, dynamic> json) => Idea(
        id: json['id'] as String,
        title: json['title'] as String,
        notes: json['notes'] as String?,
        imagePath: json['imagePath'] as String?,
        audioPath: json['audioPath'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isFavorite: json['isFavorite'] as bool? ?? false,
        reminderEnabled: json['reminderEnabled'] as bool? ?? false,
        reminderAt: json['reminderAt'] != null
            ? DateTime.parse(json['reminderAt'] as String)
            : null,
      );
}
