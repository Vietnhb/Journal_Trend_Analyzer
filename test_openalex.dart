import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final uri = Uri.parse('https://api.openalex.org/works?search=deep%20learning&per-page=1&mailto=vietnhbse183457@fpt.edu.vn');
  final response = await http.get(uri);
  final decoded = jsonDecode(response.body);
  print('Total for deep learning: ${decoded['meta']['count']}');
  final results = decoded['results'] as List;
  int total = 0;
  for (var r in results) {
    total += (r['cited_by_count'] as int?) ?? 0;
  }
  print('Total: $total, Length: ${results.length}, Avg: ${total ~/ results.length}');
}
