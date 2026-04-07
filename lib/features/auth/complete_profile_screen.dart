import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/user_preferences_repository.dart';
import '../../core/widgets/home_navigation_button.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _nameController = TextEditingController();
  final _whatsAppController = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCurrentData);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsAppController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentData() async {
    final profile = await ref.read(userPreferencesRepositoryProvider).load();
    if (!mounted) return;
    _nameController.text = profile.displayName;
    _whatsAppController.text = profile.whatsAppPhone;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _whatsAppController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Informe seu nome.';
      });
      return;
    }
    if (phone.isEmpty) {
      setState(() {
        _error = 'Informe seu telefone/WhatsApp.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await ref.read(userPreferencesRepositoryProvider).saveProfileDetails(
        name: name,
        whatsAppPhone: phone,
      );
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete seu cadastro'),
        actions: const [HomeNavigationButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Para continuar, informe seu nome e o telefone de WhatsApp que serao usados automaticamente nos seus anuncios.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _whatsAppController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone / WhatsApp',
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isBusy ? null : _save,
                    child: _isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar e continuar'),
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
