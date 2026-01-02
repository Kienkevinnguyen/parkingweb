import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trends_api.dart';
import 'daily_visits_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const baseUrl = 'http://localhost:3000';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parking Admin',
      theme: ThemeData(useMaterial3: true),
      home: const EntryScreen(),
    );
  }
}

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});
  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  Future<String?> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('admin_token');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _loadToken(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final token = snap.data;
        if (token == null || token.isEmpty) return const AdminLoginScreen();
        return AdminDashboard(token: token);
      },
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final userCtrl = TextEditingController(text: 'kiennguyen');
  final passCtrl = TextEditingController(text: 'kien12345');
  bool loading = false;
  String? error;

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': userCtrl.text.trim(), 'password': passCtrl.text}),
      );

      if (res.statusCode != 200) {
        throw Exception(res.body);
      }

      final data = jsonDecode(res.body);
      final token = data['token'] as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_token', token);

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboard(token: token)));
    } catch (e) {
      setState(() => error = 'Login failed: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 12),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: loading ? null : login, child: Text(loading ? 'Signing in...' : 'Login')),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  final String token;
  const AdminDashboard({super.key, required this.token});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

// ✅ HERE is the class you were missing
class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? overview;
  String? error;
  bool loading = false;

  // ✅ Trend state variables (add chart data here)
  List<DailyPoint> trend = [];
  bool trendLoading = false;
  String? trendError;

  late TextEditingController yearCtrl;
  late TextEditingController monthCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    yearCtrl = TextEditingController(text: now.year.toString());
    monthCtrl = TextEditingController(text: now.month.toString());
  }

  int get year => int.tryParse(yearCtrl.text) ?? DateTime.now().year;
  int get month => int.tryParse(monthCtrl.text) ?? DateTime.now().month;

  Future<void> loadOverview() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/admin/overview?year=$year&month=$month'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode != 200) throw Exception(res.body);
      overview = jsonDecode(res.body) as Map<String, dynamic>;

      // also load trend for the chart
      await loadTrend();
    } catch (e) {
      setState(() => error = 'Load failed: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> loadTrend() async {
    setState(() {
      trendLoading = true;
      trendError = null;
    });

    try {
      final data = await fetchDailyTrend(
        token: widget.token,
        year: year,
        month: month,
      );
      setState(() => trend = data);
    } catch (e) {
      setState(() => trendError = 'Trend failed: $e');
    } finally {
      setState(() => trendLoading = false);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final users = (overview?['users'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [TextButton(onPressed: logout, child: const Text('Logout'))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              SizedBox(width: 140, child: TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Year'))),
              const SizedBox(width: 12),
              SizedBox(width: 140, child: TextField(controller: monthCtrl, decoration: const InputDecoration(labelText: 'Month'))),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: loading ? null : loadOverview,
                child: Text(loading ? 'Loading...' : 'Load'),
              ),
            ]),
            const SizedBox(height: 12),
            if (error != null) Align(alignment: Alignment.centerLeft, child: Text(error!, style: const TextStyle(color: Colors.red))),

            // ✅ Chart card
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Visits (month)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (trendLoading) const LinearProgressIndicator(),
                    if (trendError != null) Text(trendError!, style: const TextStyle(color: Colors.red)),
                    if (!trendLoading && trendError == null) DailyVisitsChart(points: trend),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Expanded(
              child: users.isEmpty
                  ? const Center(child: Text('No data loaded. Click Load.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Plate')),
                          DataColumn(label: Text('Visits')),
                          DataColumn(label: Text('Voucher')),
                        ],
                        rows: users.map((u) {
                          final total = u['totalVisits'] ?? 0;
                          final eligible = u['eligibleVoucher'] == true;
                          return DataRow(cells: [
                            DataCell(Text('${u['customerId']}')),
                            DataCell(Text('${u['plateNumber']}')),
                            DataCell(Text('$total')),
                            DataCell(Text(eligible ? '✅ Earned' : '❌ Not yet')),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
