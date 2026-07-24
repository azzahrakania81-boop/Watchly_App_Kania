import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  static RouteView path = ('/profile', (_) => const ProfilePage());

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _username {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return 'User';

    final Map<String, dynamic> metadata = user.userMetadata ?? {};
    final dynamic name = metadata['full_name'] ?? metadata['name'] ?? metadata['username'];

    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }

    final String email = user.email ?? '';
    if (email.isEmpty) return 'User';

    final String emailName = email.split('@').first;
    if (emailName.isEmpty) return 'User';

    return '${emailName[0].toUpperCase()}${emailName.substring(1)}';
  }

  String get _email {
    final User? user = _supabase.auth.currentUser;
    return user?.email ?? 'No email available';
  }

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal logout: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff120708),
      bottomNavigationBar: Container(
        color: const Color(0xff120708),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xff120708),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF3B3B), width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                  },
                  child: const Center(
                    child: Icon(Icons.home_outlined, color: Colors.white, size: 28),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const Center(
                    child: Icon(Icons.person, color: Color(0xFFFF3B3B), size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header Title
                const Text(
                  'My Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 45),

                // Avatar Profile
                Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFF3B3B), width: 2),
                      color: const Color(0xff2A0A0E),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFFFF3B3B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Username & Email
                Text(
                  _username,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 50),

                // Tombol Log Out
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF3B3B), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFFF3B3B), size: 20),
                        SizedBox(width: 10),
                        Text(
                          'LOG OUT',
                          style: TextStyle(
                            color: Color(0xFFFF3B3B),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}