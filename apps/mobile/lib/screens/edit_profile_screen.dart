import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile_photo/pick_profile_image.dart'
    if (dart.library.html) '../profile_photo/pick_profile_image_web.dart';
import '../services/auth_service.dart';

/// Screen to update display name, email, and optional profile photo (Supabase Storage `avatars`).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;
  String? _avatarUrl;
  Uint8List? _pickedImageBytes;
  String? _pickedName;

  AuthService? _authListenTarget;
  static const _avatarsBucket = 'avatars';

  static const _fieldLabelStyle = TextStyle(
    color: AppColors.bluUniversoDeep,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Dark text on white fields (system dark theme sets [onSurface] light → invisible text).
  static const _fieldValueStyle = TextStyle(
    color: AppColors.bluUniversoDeep,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  @override
  void initState() {
    super.initState();
    _applyUserAndProfileFillEmpty(
      Supabase.instance.client.auth.currentUser,
      null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_hydrateUserFromServerThenSeed());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    if (!identical(_authListenTarget, auth)) {
      _authListenTarget?.removeListener(_onAuthServiceChanged);
      _authListenTarget = auth;
      _authListenTarget!.addListener(_onAuthServiceChanged);
      _onAuthServiceChanged();
    }
  }

  @override
  void dispose() {
    _authListenTarget?.removeListener(_onAuthServiceChanged);
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onAuthServiceChanged() {
    if (!mounted) return;
    final auth = _authListenTarget;
    if (auth == null || auth.state.isLoading) return;
    _applyUserAndProfileFillEmpty(
      Supabase.instance.client.auth.currentUser,
      auth.profile,
    );
    setState(() {});
  }

  Future<void> _hydrateUserFromServerThenSeed() async {
    final client = Supabase.instance.client;
    try {
      await client.auth.refreshSession();
    } catch (_) {}
    User? user = client.auth.currentUser;
    try {
      final res = await client.auth.getUser();
      user = res.user ?? user;
    } catch (e) {
      debugPrint('EditProfile: getUser failed: $e');
    }
    if (!mounted) return;
    final auth = context.read<AuthService>();
    _applyUserAndProfileFillEmpty(user, auth.profile);
    setState(() {});
  }

  void _applyMetadataToScratch(
    Map<String, dynamic> meta,
    String emailFromUser,
    void Function(String first, String last, String email, String? avatar) sink,
  ) {
    var first = meta['name']?.toString().trim() ?? '';
    var last = meta['surname']?.toString().trim() ?? '';
    final full = meta['full_name']?.toString().trim() ?? '';
    if (first.isEmpty && last.isEmpty && full.isNotEmpty) {
      final parts = full.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) first = parts.first;
      if (parts.length > 1) last = parts.sublist(1).join(' ');
    }
    final email = emailFromUser.trim();
    final raw = meta['avatar_url']?.toString().trim();
    final avatar = raw != null && raw.isNotEmpty ? raw : null;
    sink(first, last, email, avatar);
  }

  void _applyUserAndProfileFillEmpty(User? user, Profile? profile) {
    if (user != null) {
      final meta = Map<String, dynamic>.from(user.userMetadata ?? {});
      _applyMetadataToScratch(meta, user.email ?? '', (first, last, email, avatar) {
        if (_nameController.text.trim().isEmpty && first.isNotEmpty) {
          _nameController.text = first;
        }
        if (_surnameController.text.trim().isEmpty && last.isNotEmpty) {
          _surnameController.text = last;
        }
        if (_emailController.text.trim().isEmpty && email.isNotEmpty) {
          _emailController.text = email;
        }
        if (_avatarUrl == null && avatar != null) {
          _avatarUrl = avatar;
        }
      });
    }

    final profileName = profile?.name?.trim();
    if (_nameController.text.trim().isEmpty &&
        _surnameController.text.trim().isEmpty &&
        profileName != null &&
        profileName.isNotEmpty) {
      final parts = profileName.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) _nameController.text = parts.first;
      if (parts.length > 1) {
        _surnameController.text = parts.sublist(1).join(' ');
      }
    }
    if (_emailController.text.trim().isEmpty &&
        profile != null &&
        profile.email.trim().isNotEmpty) {
      _emailController.text = profile.email.trim();
    }
  }

  String _fileExtension(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i >= name.length - 1) return 'jpg';
    final ext = name.substring(i + 1).toLowerCase();
    if (ext == 'jpeg') return 'jpg';
    if (['jpg', 'png', 'webp', 'gif'].contains(ext)) return ext;
    return 'jpg';
  }

  String _contentTypeForExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickPhoto() async {
    if (_saving || !mounted) return;
    try {
      final picked = await pickProfileImage();
      if (picked == null || !mounted) return;
      setState(() {
        _pickedImageBytes = picked.bytes;
        _pickedName = picked.name;
      });
    } catch (e, st) {
      debugPrint('EditProfile: pickProfileImage failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossibile selezionare la foto. Su web usa HTTPS; su mobile/desktop riavvia l\'app. ($e)',
            ),
          ),
        );
      }
    }
  }

  Future<String?> _uploadAvatarIfNeeded(String userId) async {
    if (_pickedImageBytes == null) return _avatarUrl;
    final ext = _fileExtension(_pickedName ?? 'photo.jpg');
    final objectPath = '$userId/profile.$ext';
    final client = Supabase.instance.client;
    try {
      await client.storage.from(_avatarsBucket).uploadBinary(
            objectPath,
            _pickedImageBytes!,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeForExt(ext),
            ),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossibile caricare la foto. Verifica il bucket Storage "avatars" sul progetto Supabase. ($e)',
            ),
          ),
        );
      }
      return null;
    }
    return client.storage.from(_avatarsBucket).getPublicUrl(objectPath);
  }

  Future<void> _save() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final surname = _surnameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || surname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome e cognome sono obbligatori.')),
      );
      return;
    }
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un indirizzo email.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final newAvatarUrl = await _uploadAvatarIfNeeded(user.id);
      if (_pickedImageBytes != null && newAvatarUrl == null) {
        return;
      }

      final merged = Map<String, dynamic>.from(user.userMetadata ?? {});
      merged['name'] = name;
      merged['surname'] = surname;
      if (newAvatarUrl != null && newAvatarUrl.isNotEmpty) {
        merged['avatar_url'] = newAvatarUrl;
      }

      final emailChanged = email.toLowerCase() != (user.email ?? '').toLowerCase();

      await client.auth.updateUser(
        UserAttributes(
          email: emailChanged ? email : null,
          data: merged,
        ),
      );

      await upsertProfileForUserId(client, user.id, {
        'email': email,
        'name': '$name $surname'.trim(),
      });

      if (!mounted) return;
      await context.read<AuthService>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo aggiornato.')),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _initialLetter {
    final n = _nameController.text.trim();
    if (n.isNotEmpty) return n.characters.first.toUpperCase();
    final s = _surnameController.text.trim();
    if (s.isNotEmpty) return s.characters.first.toUpperCase();
    final e = _emailController.text.trim();
    if (e.isNotEmpty) return e.characters.first.toUpperCase();
    return '?';
  }

  InputDecoration _fieldDecoration(String hintWhenEmpty) {
    return InputDecoration(
      hintText: hintWhenEmpty,
      hintStyle: const TextStyle(color: Color(0xFF9AA3B2), fontSize: 15, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.bluUniversoDeep, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.limeCreateHard, width: 1.6),
      ),
    );
  }

  Widget _labeledField({
    required String label,
    required String hintWhenEmpty,
    required TextEditingController controller,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    bool autocorrect = true,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: _fieldLabelStyle),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: _fieldValueStyle,
          cursorColor: AppColors.bluUniversoDeep,
          textCapitalization: capitalization,
          keyboardType: keyboardType,
          autocorrect: autocorrect,
          decoration: _fieldDecoration(hintWhenEmpty),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      appBar: AppBar(
        backgroundColor: AppColors.biancoOttico,
        foregroundColor: AppColors.bluUniversoDeep,
        elevation: 0,
        title: const Text(
          'Modifica profilo',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _saving ? null : () => unawaited(_pickPhoto()),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bluUniversoDeep,
                        border: Border.all(color: AppColors.limeCreateHard, width: 2.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _pickedImageBytes != null
                          ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                          : _avatarUrl != null
                              ? Image.network(
                                  _avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      _initialLetter,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _initialLetter,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Material(
                      color: AppColors.limeCreateHard,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _saving ? null : () => unawaited(_pickPhoto()),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.camera_alt_outlined, size: 20, color: AppColors.bluUniversoDeep),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tocca l\'immagine per cambiare la foto',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF697486), fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            const Text(
              'Dati account',
              style: TextStyle(
                color: AppColors.bluUniversoDeep,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'I valori attuali sono già inseriti: modifica solo ciò che vuoi aggiornare.',
              style: TextStyle(
                color: Color(0xFF697486),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            _labeledField(
              label: 'Nome',
              hintWhenEmpty: 'Es. Mario',
              controller: _nameController,
              capitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _labeledField(
              label: 'Cognome',
              hintWhenEmpty: 'Es. Rossi',
              controller: _surnameController,
              capitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            _labeledField(
              label: 'Email',
              hintWhenEmpty: 'nome@esempio.it',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            const SizedBox(height: 8),
            const Text(
              'Se cambi email, Supabase può inviarti un link di conferma secondo le impostazioni del progetto.',
              style: TextStyle(color: Color(0xFF697486), fontSize: 11, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bluUniversoDeep,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Salva', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
