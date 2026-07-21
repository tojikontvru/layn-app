import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _usernameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _channelNameCtrl;
  late TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _usernameCtrl = TextEditingController(text: auth.user?.username ?? '');
    _emailCtrl = TextEditingController(text: auth.email ?? '');
    _firstNameCtrl = TextEditingController(text: auth.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: auth.lastName ?? '');
    _channelNameCtrl = TextEditingController(text: auth.user?.channelName ?? '');
    _descCtrl = TextEditingController(text: auth.description ?? '');
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _channelNameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.updateProfile(
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        firstname: _firstNameCtrl.text.trim(),
        lastname: _lastNameCtrl.text.trim(),
        channelName: _channelNameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль обновлён'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar preview
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundImage: Provider.of<AuthProvider>(context).user?.avatar != null &&
                      Provider.of<AuthProvider>(context).user!.avatar!.isNotEmpty
                  ? NetworkImage(Provider.of<AuthProvider>(context).user!.avatar!)
                  : null,
              child: Provider.of<AuthProvider>(context).user?.avatar == null ||
                      Provider.of<AuthProvider>(context).user!.avatar!.isEmpty
                  ? Text(
                      (_usernameCtrl.text.isNotEmpty ? _usernameCtrl.text[0] : '?').toUpperCase(),
                      style: const TextStyle(fontSize: 32),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          _buildField('Имя пользователя', _usernameCtrl),
          const SizedBox(height: 12),
          _buildField('Email', _emailCtrl, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _buildField('Имя', _firstNameCtrl),
          const SizedBox(height: 12),
          _buildField('Фамилия', _lastNameCtrl),
          const SizedBox(height: 12),
          _buildField('Название канала', _channelNameCtrl),
          const SizedBox(height: 12),
          _buildField('Описание', _descCtrl, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
