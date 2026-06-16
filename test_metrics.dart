import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final uri1 = Uri.parse('https://api.openalex.org/works?search=deep%20learning&per-page=50&page=1&sort=publication_year:desc&mailto=vietnhbse183457@fpt.edu.vn');
  final res1 = await http.get(uri1);
  final d1 = jsonDecode(res1.body);
  print('Total publications: ${d1['meta']['count']}');

  final uri2 = Uri.parse('https://api.openalex.org/works?search=deep%20learning&group_by=publication_year&mailto=vietnhbse183457@fpt.edu.vn');
  final res2 = await http.get(uri2);
  final d2 = jsonDecode(res2.body);
  print('Group by year:');
  for (var item in (d2['group_by'] as List).take(3)) {
    print('${item['key']}: ${item['count']}');
  }

  final uri3 = Uri.parse('https://api.openalex.org/works?search=deep%20learning&per-page=50&page=1&sort=cited_by_count:desc&mailto=vietnhbse183457@fpt.edu.vn');
  final res3 = await http.get(uri3);
  final d3 = jsonDecode(res3.body);
  final topPapers = d3['results'] as List;
  int totalTop = 0;
  for (var p in topPapers) totalTop += (p['cited_by_count'] as int?) ?? 0;
  print('Avg citations (top 50): ${topPapers.isEmpty ? 0 : totalTop ~/ topPapers.length}');
}
