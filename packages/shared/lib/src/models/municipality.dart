import 'package:equatable/equatable.dart';

class Municipality extends Equatable {
  const Municipality({
    required this.istatCode,
    required this.name,
    this.province,
    this.region,
    this.lat,
    this.lng,
  });

  final String istatCode;
  final String name;
  final String? province;
  final String? region;
  final double? lat;
  final double? lng;

  factory Municipality.fromJson(Map<String, dynamic> json) {
    return Municipality(
      istatCode: json['istat_code'] as String,
      name: json['name'] as String,
      province: json['province'] as String?,
      region: json['region'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'istat_code': istatCode,
        'name': name,
        'province': province,
        'region': region,
        'lat': lat,
        'lng': lng,
      };

  @override
  List<Object?> get props => [istatCode];
}
