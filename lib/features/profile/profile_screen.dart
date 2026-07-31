import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/app_page_shell.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../data/services/supabase_client_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _avatarBucket = 'profile-avatars';
  static const _maxAvatarBytes = 5 * 1024 * 1024;

  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  bool _loading = true;
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _sendingRecovery = false;
  bool _pickingAvatar = false;
  String _avatarUrl = '';
  String _originalEmail = '';
  Uint8List? _pendingAvatar;
  String _pendingAvatarExtension = 'jpg';
  String _pendingAvatarMime = 'image/jpeg';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await ref.read(userPreferencesRepositoryProvider).load();
      final email =
          ref.read(supabaseClientProvider).auth.currentUser?.email ?? '';
      if (!mounted) return;
      _nameController.text = prefs.displayName;
      _phoneController.text = prefs.whatsAppPhone;
      _emailController.text = email;
      setState(() {
        _avatarUrl = prefs.avatarUrl;
        _originalEmail = email;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(_friendlyError(error), isError: true);
    }
  }

  Future<void> _chooseAvatar() async {
    setState(() => _pickingAvatar = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxAvatarBytes) {
        _showMessage('A foto deve ter no máximo 5 MB.', isError: true);
        return;
      }

      final extension = _safeImageExtension(file.name);
      if (extension == null) {
        _showMessage('Escolha uma imagem JPG, PNG ou WebP.', isError: true);
        return;
      }

      if (!mounted) return;
      setState(() {
        _pendingAvatar = bytes;
        _pendingAvatarExtension = extension;
        _pendingAvatarMime = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };
      });
    } catch (error) {
      _showMessage(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _pickingAvatar = false);
    }
  }

  String? _safeImageExtension(String name) {
    final extension = name.split('.').last.toLowerCase();
    if (extension == 'jpg' || extension == 'jpeg') return 'jpg';
    if (extension == 'png' || extension == 'webp') return extension;
    return null;
  }

  Future<String> _uploadPendingAvatar() async {
    final bytes = _pendingAvatar;
    if (bytes == null) return _avatarUrl;

    final client = ref.read(supabaseClientProvider);
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sessão expirada.');

    final path = '${user.id}/avatar.$_pendingAvatarExtension';
    await client.storage
        .from(_avatarBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _pendingAvatarMime,
            cacheControl: '3600',
          ),
        );
    final publicUrl = client.storage.from(_avatarBucket).getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final newAvatarUrl = await _uploadPendingAvatar();
      await ref
          .read(userPreferencesRepositoryProvider)
          .saveProfileDetails(
            name: _nameController.text.trim(),
            whatsAppPhone: _phoneController.text.trim(),
            avatarUrl: newAvatarUrl,
          );

      final requestedEmail = _emailController.text.trim();
      final emailChanged =
          requestedEmail.toLowerCase() != _originalEmail.toLowerCase();
      if (emailChanged) {
        await client.auth.updateUser(UserAttributes(email: requestedEmail));
      }

      if (!mounted) return;
      setState(() {
        _avatarUrl = newAvatarUrl;
        _pendingAvatar = null;
        _originalEmail = requestedEmail;
      });
      _showMessage(
        emailChanged
            ? 'Perfil salvo. Confirme a troca de e-mail pelas mensagens enviadas pelo Supabase.'
            : 'Perfil atualizado com sucesso.',
      );
    } catch (error) {
      _showMessage(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _savingPassword = true);
    try {
      await ref
          .read(supabaseClientProvider)
          .auth
          .updateUser(UserAttributes(password: _passwordController.text));
      _passwordController.clear();
      _passwordConfirmationController.clear();
      _showMessage('Senha alterada com sucesso.');
    } catch (error) {
      _showMessage(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _sendRecoveryEmail() async {
    final email =
        ref.read(supabaseClientProvider).auth.currentUser?.email ?? '';
    if (email.isEmpty) {
      _showMessage('A conta não possui um e-mail cadastrado.', isError: true);
      return;
    }
    setState(() => _sendingRecovery = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      _showMessage('Enviamos as instruções de recuperação para $email.');
    } catch (error) {
      _showMessage(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _sendingRecovery = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
      );
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.toLowerCase().contains('email address is invalid')) {
      return 'Informe um e-mail válido.';
    }
    if (message.toLowerCase().contains('password should be at least')) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }
    if (message.toLowerCase().contains('session')) {
      return 'Sua sessão expirou. Entre novamente.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: AppPageShell(
        maxWidth: 860,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(
                    name: _nameController.text,
                    avatarUrl: _avatarUrl,
                    pendingAvatar: _pendingAvatar,
                    busy: _pickingAvatar,
                    onChooseAvatar: _chooseAvatar,
                  ),
                  const SizedBox(height: 20),
                  _section(
                    title: 'Informações do perfil',
                    subtitle:
                        'Estes dados identificam você nas áreas da comunidade e nos contatos do marketplace.',
                    icon: Icons.badge_outlined,
                    child: Form(
                      key: _profileFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Nick / nome público',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().length < 2
                                ? 'Informe um nick com pelo menos 2 caracteres.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Telefone / WhatsApp',
                              hintText: '(31) 99999-9999',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final digits = (value ?? '').replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              if (digits.length < 10 || digits.length > 13) {
                                return 'Informe um telefone válido com DDD.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-mail da conta',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                              helperText:
                                  'A alteração precisa ser confirmada por e-mail.',
                            ),
                            validator: (value) {
                              final email = (value ?? '').trim();
                              return RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(email)
                                  ? null
                                  : 'Informe um e-mail válido.';
                            },
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _savingProfile ? null : _saveProfile,
                              icon: _savingProfile
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Salvar perfil'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _section(
                    title: 'Segurança da conta',
                    subtitle:
                        'Troque sua senha nesta sessão ou peça um link de recuperação.',
                    icon: Icons.security_outlined,
                    child: Form(
                      key: _passwordFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Nova senha',
                              prefixIcon: Icon(Icons.lock_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => (value ?? '').length < 6
                                ? 'Use pelo menos 6 caracteres.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordConfirmationController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirmar nova senha',
                              prefixIcon: Icon(Icons.lock_reset_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value != _passwordController.text
                                ? 'As senhas não coincidem.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: _savingPassword
                                    ? null
                                    : _changePassword,
                                icon: const Icon(Icons.password_outlined),
                                label: const Text('Alterar senha'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _sendingRecovery
                                    ? null
                                    : _sendRecoveryEmail,
                                icon: const Icon(
                                  Icons.mark_email_read_outlined,
                                ),
                                label: const Text('Recuperar por e-mail'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const _PhoneRecoveryNotice(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final Uint8List? pendingAvatar;
  final bool busy;
  final VoidCallback onChooseAvatar;

  const _ProfileHeader({
    required this.name,
    required this.avatarUrl,
    required this.pendingAvatar,
    required this.busy,
    required this.onChooseAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ImageProvider<Object>? image = pendingAvatar != null
        ? MemoryImage(pendingAvatar!)
        : avatarUrl.isNotEmpty
        ? NetworkImage(avatarUrl)
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 20,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: image,
              child: image == null
                  ? Icon(
                      Icons.person,
                      size: 46,
                      color: theme.colorScheme.onPrimaryContainer,
                    )
                  : null,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Seu perfil' : name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : onChooseAvatar,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Escolher foto'),
                ),
                const SizedBox(height: 4),
                Text(
                  'JPG, PNG ou WebP, até 5 MB.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneRecoveryNotice extends StatelessWidget {
  const _PhoneRecoveryNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sms_outlined, color: theme.colorScheme.secondary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Recuperação por telefone ainda não está ativa. O número do perfil é usado para contato no WhatsApp; para recuperar a conta por SMS, ele precisa ser verificado por um provedor de autenticação.',
            ),
          ),
        ],
      ),
    );
  }
}
