import 'package:equatable/equatable.dart';

import 'municipality.dart';

enum AncodeType { link, note }

enum AncodeStatus { active, inactive, grace, scheduled }

class Ancode extends Equatable {
  const Ancode({
    required this.id,
    required this.code,
    required this.normalizedCode,
    required this.type,
    this.url,
    this.noteText,
    required this.municipalityId,
    this.municipality,
    this.isExclusiveItaly = false,
    this.status = AncodeStatus.active,
    this.scheduleStart,
    this.scheduleEnd,
    required this.ownerUserId,
    this.clickCount = 0,
    this.priorityRank,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });

  final String id;
  final String code;
  final String normalizedCode;
  final AncodeType type;
  final String? url;
  final String? noteText;
  final String municipalityId;
  final Municipality? municipality;
  final bool isExclusiveItaly;
  final AncodeStatus status;
  final DateTime? scheduleStart;
  final DateTime? scheduleEnd;
  final String ownerUserId;
  final int clickCount;
  final int? priorityRank;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  bool get isLink => type == AncodeType.link;
  bool get isNote => type == AncodeType.note;
  bool get isExclusive => isExclusiveItaly;
  bool get isActive => status == AncodeStatus.active;
  bool get isInGrace => status == AncodeStatus.grace;

  factory Ancode.fromJson(Map<String, dynamic> json) {
    return Ancode(
      id: json['id'] as String,
      code: json['code'] as String,
      normalizedCode: json['normalized_code'] as String,
      type: AncodeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AncodeType.link,
      ),
      url: json['url'] as String?,
      noteText: json['note_text'] as String?,
      municipalityId: json['municipality_id'] as String,
      municipality: json['municipality'] != null
          ? Municipality.fromJson(json['municipality'] as Map<String, dynamic>)
          : null,
      isExclusiveItaly: json['is_exclusive_italy'] as bool? ?? false,
      status: AncodeStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AncodeStatus.active,
      ),
      scheduleStart: json['schedule_start'] != null
          ? DateTime.parse(json['schedule_start'] as String)
          : null,
      scheduleEnd: json['schedule_end'] != null
          ? DateTime.parse(json['schedule_end'] as String)
          : null,
      ownerUserId: json['owner_user_id'] as String,
      clickCount: json['click_count'] as int? ?? 0,
      priorityRank: json['priority_rank'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'normalized_code': normalizedCode,
        'type': type.name,
        'url': url,
        'note_text': noteText,
        'municipality_id': municipalityId,
        'is_exclusive_italy': isExclusiveItaly,
        'status': status.name,
        'schedule_start': scheduleStart?.toIso8601String(),
        'schedule_end': scheduleEnd?.toIso8601String(),
        'owner_user_id': ownerUserId,
        'click_count': clickCount,
        'priority_rank': priorityRank,
        'expires_at': expiresAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id];
}
