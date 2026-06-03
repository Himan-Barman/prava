class ProfileVisibility {
  ProfileVisibility({
    required Map<String, String> fields,
    required Map<String, bool> visible,
    required this.privateAccount,
  })  : fields = Map.unmodifiable(_normalizeFields(fields)),
        visible = Map.unmodifiable(_normalizeVisible(visible));

  final Map<String, String> fields;
  final Map<String, bool> visible;
  final bool privateAccount;

  static const fieldKeys = <String>[
    'bio',
    'location',
    'website',
    'joined',
    'posts',
    'followers',
    'following',
    'likes',
  ];

  static const levels = <String>[
    'everyone',
    'followers',
    'friends',
    'onlyMe',
  ];

  static const defaults = <String, String>{
    'bio': 'everyone',
    'location': 'friends',
    'website': 'everyone',
    'joined': 'everyone',
    'posts': 'everyone',
    'followers': 'everyone',
    'following': 'everyone',
    'likes': 'onlyMe',
  };

  static Map<String, String> _normalizeFields(Map<String, String> incoming) {
    return {
      for (final key in fieldKeys)
        key: levels.contains(incoming[key]) ? incoming[key]! : defaults[key]!,
    };
  }

  static Map<String, bool> _normalizeVisible(Map<String, bool> incoming) {
    return {
      for (final key in fieldKeys) key: incoming[key] ?? true,
    };
  }

  factory ProfileVisibility.defaultsForOwner() {
    return ProfileVisibility(
      fields: defaults,
      visible: {for (final key in fieldKeys) key: true},
      privateAccount: false,
    );
  }

  factory ProfileVisibility.fromSummaryJson(Map<String, dynamic>? json) {
    if (json == null) return ProfileVisibility.defaultsForOwner();

    final rawFields = json['fields'];
    final rawVisible = json['visible'];
    return ProfileVisibility(
      fields: _readFields(rawFields),
      visible: _readVisible(rawVisible),
      privateAccount: json['privateAccount'] == true,
    );
  }

  factory ProfileVisibility.fromSettingsJson(Map<String, dynamic>? json) {
    if (json == null) return ProfileVisibility.defaultsForOwner();
    return ProfileVisibility(
      fields: _readFields(json['profileVisibility']),
      visible: {for (final key in fieldKeys) key: true},
      privateAccount: json['privateAccount'] == true,
    );
  }

  static Map<String, String> _readFields(dynamic raw) {
    if (raw is! Map) return defaults;
    return {
      for (final key in fieldKeys)
        key: levels.contains(raw[key]?.toString())
            ? raw[key].toString()
            : defaults[key]!,
    };
  }

  static Map<String, bool> _readVisible(dynamic raw) {
    if (raw is! Map) {
      return {for (final key in fieldKeys) key: true};
    }
    return {
      for (final key in fieldKeys) key: raw[key] == true,
    };
  }

  bool canSee(String key) => visible[key] ?? true;

  String levelFor(String key) => fields[key] ?? defaults[key]!;

  ProfileVisibility copyWithField(String key, String level) {
    return ProfileVisibility(
      fields: {
        ...fields,
        key: levels.contains(level) ? level : defaults[key]!,
      },
      visible: visible,
      privateAccount: privateAccount,
    );
  }

  Map<String, dynamic> toSettingsJson() {
    return {'profileVisibility': fields};
  }

  static String fieldLabel(String key) {
    switch (key) {
      case 'bio':
        return 'Bio';
      case 'location':
        return 'Location';
      case 'website':
        return 'Website';
      case 'joined':
        return 'Joined date';
      case 'posts':
        return 'Posts';
      case 'followers':
        return 'Followers count';
      case 'following':
        return 'Following count';
      case 'likes':
        return 'Likes count';
      default:
        return key;
    }
  }

  static String levelLabel(String level) {
    switch (level) {
      case 'everyone':
        return 'Everyone';
      case 'followers':
        return 'Followers';
      case 'friends':
        return 'Friends';
      case 'onlyMe':
        return 'Only me';
      default:
        return 'Everyone';
    }
  }
}
