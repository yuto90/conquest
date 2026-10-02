import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../profile/profile_avatars.dart';
import '../profile/profile_read_providers.dart';
import '../profile/profile_repository.dart';
import 'tactical_theme.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.avatarKey, this.size = 48});
  final String avatarKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = ProfileAvatars.assets[avatarKey];
    return ExcludeSemantics(
      child: asset == null
          ? Icon(Icons.person_outline, size: size)
          : Image.asset(
              asset,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(Icons.person_outline, size: size),
            ),
    );
  }
}

class ProfileEditor extends ConsumerStatefulWidget {
  const ProfileEditor({super.key, required this.profile});
  final PlayerProfile profile;

  static Future<bool?> open(BuildContext context, PlayerProfile profile) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/my-page/edit'),
          builder: (_) => ProfileEditor(profile: profile),
        ),
      );

  @override
  ConsumerState<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<ProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _avatar;
  bool _nameChanged = false;
  bool _saving = false;
  bool _failed = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.displayName ?? '');
    _avatar = ProfileAvatars.assets.containsKey(widget.profile.avatarKey)
        ? widget.profile.avatarKey
        : ProfileAvatars.defaultKey;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _keepsDefault =>
      widget.profile.displayName == null && !_nameChanged && _name.text.isEmpty;
  String? get _displayName => _keepsDefault ? null : _name.text.trim();
  bool get _dirty =>
      _displayName != widget.profile.displayName ||
      _avatar != widget.profile.avatarKey;

  String? _validate(String? raw) {
    if (_keepsDefault) return null;
    final value = (raw ?? '').trim();
    if (value.characters.isEmpty ||
        value.characters.length > 20 ||
        RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(raw ?? '')) {
      return AppLocalizations.of(context).myPageInvalidName;
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final repository = await ref.read(playerProfileRepositoryProvider.future);
      await repository.editProfile(
        widget.profile.profileId,
        ProfileEdit(displayName: _displayName, avatarKey: _avatar),
      );
      if (!mounted) return;
      setState(() {
        _closing = true;
        _saving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _failed = true;
        });
    }
  }

  Future<void> _cancel() async {
    if (_saving || _closing) return;
    final l10n = AppLocalizations.of(context);
    final discard =
        !_dirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.myPageDiscardTitle),
                content: Text(l10n.myPageUnsavedChanges),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.myPageKeepEditing),
                  ),
                  TextButton(
                    key: const ValueKey('discard-profile-edit'),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.myPageDiscard),
                  ),
                ],
              ),
            ) ==
            true;
    if (!discard || !mounted) return;
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: _closing || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        key: const ValueKey('profile-editor'),
        backgroundColor: TacticalPalette.background,
        appBar: AppBar(
          title: Text(l10n.myPageEdit),
          backgroundColor: TacticalPalette.surface,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _dirty
                            ? l10n.myPageUnsavedChanges
                            : l10n.myPageLocalDevice,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('profile-name'),
                        controller: _name,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: l10n.myPageName,
                          hintText: l10n.myPageDefaultName,
                          helperText: l10n.myPageNameHint,
                          helperMaxLines: 4,
                          errorMaxLines: 4,
                          filled: true,
                          fillColor: TacticalPalette.paper,
                        ),
                        validator: _validate,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() => _nameChanged = true),
                        onFieldSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.myPageAvatar,
                        style: TacticalTypography.of(
                          context,
                        ).display(fontSize: 20),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final (index, key)
                              in ProfileAvatars.assets.keys.indexed)
                            Semantics(
                              selected: _avatar == key,
                              child: OutlinedButton(
                                key: ValueKey('profile-avatar-$key'),
                                onPressed: _saving
                                    ? null
                                    : () => setState(() => _avatar = key),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _avatar == key
                                      ? TacticalPalette.surface
                                      : TacticalPalette.paper,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ProfileAvatar(avatarKey: key),
                                    Text(
                                      l10n.myPageAvatarChoice(
                                        number: index + 1,
                                      ),
                                    ),
                                    if (_avatar == key)
                                      const Icon(Icons.check, size: 20),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_failed)
                        Semantics(
                          liveRegion: true,
                          child: Text(l10n.myPageSaveError),
                        ),
                      if (_saving)
                        Semantics(
                          liveRegion: true,
                          child: Text(l10n.myPageSaving),
                        ),
                      FilledButton(
                        key: const ValueKey('save-profile'),
                        onPressed: _saving ? null : _save,
                        child: Text(
                          _failed ? l10n.myPageRetry : l10n.myPageSave,
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('cancel-profile-edit'),
                        onPressed: _saving ? null : _cancel,
                        child: Text(l10n.cancel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
