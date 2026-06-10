import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'presentation/trends/providers/trend_provider.dart';
import 'presentation/trends/screens/trend_analysis_screen.dart';

void main() {
  runApp(const JournalTrendAnalyzerApp());
}

class JournalTrendAnalyzerApp extends StatelessWidget {
  const JournalTrendAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TrendProvider()),
      ],
      child: MaterialApp(
        title: 'Journal Trend Analyzer',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
          fontFamily: 'Inter', // Or standard flutter font
        ),
        home: const TrendAnalysisScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
