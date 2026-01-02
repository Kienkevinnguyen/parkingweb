import 'dart:convert';
import 'package:http/http.dart' as http;

const baseUrl = 'http://localhost:3000';

class DailyPoint {
  final int day;
  final int visits;

  DailyPoint({required this.day, required this.visits});

  factory DailyPoint.fromJson(Map<String, dynamic> json) {
    return DailyPoint(
      day: (json['day'] as num).toInt(),
      visits: (json['visits'] as num).toInt(),
    );
  }
}

Future<List<DailyPoint>> fetchDailyTrend({
  required String token,
  required int year,
  required int month,
}) async {
  final uri = Uri.parse('$baseUrl/api/admin/trends/daily?year=$year&month=$month');

  final res = await http.get(
    uri,
    headers: {'Authorization': 'Bearer $token'},
  );

  if (res.statusCode != 200) {
    throw Exception(res.body);
  }

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final points = (data['points'] as List).cast<dynamic>();

  return points
      .map((p) => DailyPoint.fromJson((p as Map).cast<String, dynamic>()))
      .toList();
}
