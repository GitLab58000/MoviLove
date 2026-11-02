import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_screen.dart';
import '../widgets/guest_prompt.dart';

const List<Map<String, String>> _countries = [
  {'code': 'UA', 'name': 'Україна', 'flag': '🇺🇦'},
  {'code': 'US', 'name': 'США', 'flag': '🇺🇸'},
  {'code': 'GB', 'name': 'Великобританія', 'flag': '🇬🇧'},
  {'code': 'DE', 'name': 'Німеччина', 'flag': '🇩🇪'},
  {'code': 'FR', 'name': 'Франція', 'flag': '🇫🇷'},
  {'code': 'PL', 'name': 'Польща', 'flag': '🇵🇱'},
  {'code': 'JP', 'name': 'Японія', 'flag': '🇯🇵'},
  {'code': 'KR', 'name': 'Південна Корея', 'flag': '🇰🇷'},
  {'code': 'CA', 'name': 'Канада', 'flag': '🇨🇦'},
  {'code': 'IT', 'name': 'Італія', 'flag': '🇮🇹'},
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingAvatar = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? get _userDocRef {
    final user = _user;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = _user;
    if (user == null) return;

    final picker = ImagePicker();
    final pickedFile =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child('${user.uid}.jpg');

      await ref.putFile(File(pickedFile.path));
      final url = await ref.getDownloadURL();

      await _userDocRef!.set({'avatarUrl': url}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка завантаження: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _editNickname(String currentNickname) async {
    final controller = TextEditingController(text: currentNickname);
    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Змінити нікнейм',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Відміна'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );

    if (newNickname != null && newNickname.isNotEmpty) {
      await _userDocRef!.set({'nickname': newNickname}, SetOptions(merge: true));
    }
  }

  Future<void> _pickCountry(String? currentCode) async {
    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: _countries.map((country) {
          return ListTile(
            leading: Text(country['flag']!,
                style: const TextStyle(fontSize: 22)),
            title: Text(country['name']!,
                style: const TextStyle(color: Colors.white)),
            trailing: currentCode == country['code']
                ? const Icon(Icons.check, color: Colors.redAccent)
                : null,
            onTap: () => Navigator.pop(context, country),
          );
        }).toList(),
      ),
    );

    if (selected != null) {
      await _userDocRef!.set({
        'countryCode': selected['code'],
        'countryName': selected['name'],
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Профіль'),
          backgroundColor: const Color(0xFF121212),
        ),
        body: const GuestPrompt(
          icon: Icons.person_outline,
          message: 'Увійдіть в акаунт, щоб бачити профіль',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профіль'),
        backgroundColor: const Color(0xFF121212),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userDocRef!.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final nickname = data?['nickname'] ?? 'Без імені';
          final avatarUrl = data?['avatarUrl'];
          final countryName = data?['countryName'];
          final countryCode = data?['countryCode'];

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              Center(
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white12,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, size: 55, color: Colors.white38)
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              _ProfileTile(
                icon: Icons.person_outline,
                label: 'Нікнейм',
                value: nickname,
                onTap: () => _editNickname(nickname),
              ),
              _ProfileTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: user.email ?? '—',
              ),
              _ProfileTile(
                icon: Icons.public,
                label: 'Країна',
                value: countryName != null
                    ? '${_flagFor(countryCode)} $countryName'
                    : 'Не обрана',
                onTap: () => _pickCountry(countryCode),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                          (route) => false,
                    );
                  }
                },
                child: const Text('Вийти',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _flagFor(String? code) {
    final country = _countries.firstWhere(
          (c) => c['code'] == code,
      orElse: () => {'flag': ''},
    );
    return country['flag'] ?? '';
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.redAccent),
        title: Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        subtitle: Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: Colors.white38)
            : null,
        onTap: onTap,
      ),
    );
  }
}