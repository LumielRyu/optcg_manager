import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sale_folder.dart';
import '../services/supabase_client_provider.dart';

final saleFolderRepositoryProvider = Provider<SaleFolderRepository>((ref) {
  return SaleFolderRepository(ref.watch(supabaseClientProvider));
});

class SaleFolderRepository {
  static const _columns = 'id, user_id, game_slug, name, created_at';

  final SupabaseClient _client;

  const SaleFolderRepository(this._client);

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Usuario nao autenticado.');
    return user;
  }

  Future<List<SaleFolder>> listFolders(String gameSlug) async {
    final user = _requireUser();
    final rows = await _client
        .from('sale_folders')
        .select(_columns)
        .eq('user_id', user.id)
        .eq('game_slug', gameSlug)
        .order('name');
    return rows
        .map((row) => SaleFolder.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<SaleFolder> createFolder(String gameSlug, String name) async {
    final user = _requireUser();
    final normalizedName = _validateName(name);
    final row = await _client
        .from('sale_folders')
        .insert({
          'user_id': user.id,
          'game_slug': gameSlug,
          'name': normalizedName,
        })
        .select(_columns)
        .single();
    return SaleFolder.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> renameFolder(String folderId, String name) async {
    final user = _requireUser();
    await _client
        .from('sale_folders')
        .update({'name': _validateName(name)})
        .eq('id', folderId)
        .eq('user_id', user.id);
  }

  Future<void> deleteFolder(String folderId) async {
    final user = _requireUser();
    await _client
        .from('sale_folders')
        .delete()
        .eq('id', folderId)
        .eq('user_id', user.id);
  }

  String _validateName(String value) {
    final name = value.trim();
    if (name.isEmpty || name.length > 60) {
      throw StateError('Informe um nome de pasta entre 1 e 60 caracteres.');
    }
    return name;
  }
}
