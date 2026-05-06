import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shared/shared.dart';

import '../services/siri_shortcut_service.dart';

import '../services/ancode_service.dart' show AncodeService, AncodeSearchResult;
import '../services/app_config.dart';
import '../services/auth_service.dart';
import 'code_resolve_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _codeInputFormatter = _UppercaseAlnumFormatter(maxLength: 30);
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  AncodeSearchResult? _lastResult;
  Ancode? _selectedMatch;
  bool _isSearching = false;
  StreamSubscription<String>? _siriSubscription;

  String _normalizeCodeInput(String value) => normalizeCodeInput(value);

  void _onCodeChanged(String value) {
    final normalized = _normalizeCodeInput(value);
    if (_lastResult != null || _selectedMatch != null) {
      setState(() {
        _lastResult = null;
        _selectedMatch = null;
      });
    }
    if (normalized == value) return;
    _controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _siriSubscription = SiriShortcutService.instance.searchCodeStream.listen(_onSiriSearchCode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SiriShortcutService.instance.consumeDeferredSiriSearchCode(_onSiriSearchCode);
    });
  }

  /// Applies a code from Siri / App Intents / URL handoff and runs public search.
  void _onSiriSearchCode(String normalized) {
    if (!mounted || normalized.isEmpty) return;
    _controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    unawaited(_onSearchSubmitted(normalized));
  }

  @override
  void dispose() {
    _siriSubscription?.cancel();
    _controller.removeListener(() => setState(() {}));
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSearchSubmitted(String value) async {
    final normalized = _normalizeCodeInput(value);
    if (normalized.isEmpty) return;
    if (_controller.text != normalized) {
      _controller.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    setState(() => _isSearching = true);
    try {
      final result = await AncodeService.search(normalized);
      if (mounted) {
        setState(() {
          _lastResult = result;
          _selectedMatch = result.uniqueMatch;
          _isSearching = false;
        });
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          unawaited(SiriShortcutService.instance.rememberLookupCodeForSiri(normalized));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResult = AncodeSearchResult(error: e.toString());
          _selectedMatch = null;
          _isSearching = false;
        });
      }
    }
  }

  void _onCodeResolved() {
    setState(() {
      _lastResult = null;
      _selectedMatch = null;
    });
  }

  /// Opens user-supplied URLs in the browser; avoids treating arbitrary note text as a host.
  static bool _looksLikeExplicitUrl(String value) {
    final t = value.trim().toLowerCase();
    return t.startsWith('http://') ||
        t.startsWith('https://') ||
        t.startsWith('www.');
  }

  /// Target string for an external open, or null to show in-app note content instead.
  String? _externalUrlRaw(Ancode match) {
    final u = match.url?.trim();
    if (u != null && u.isNotEmpty) return u;
    if (match.isLink) return AppConfig.shortlinkFor(match.normalizedCode);
    final note = match.noteText?.trim();
    if (note != null && note.isNotEmpty && _looksLikeExplicitUrl(note)) return note;
    return null;
  }

  Future<void> _openExternalFromMatch(Ancode match, String raw) async {
    if (match.status == AncodeStatus.grace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collegamento non disponibile durante il periodo di grazia.')),
      );
      return;
    }
    final uri = AncodeQrPdf.normalizeHttpUri(raw);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato del collegamento non valido.')),
      );
      return;
    }
    if (match.id.isNotEmpty) {
      try {
        await Supabase.instance.client.from('clicks').insert({'ancode_id': match.id});
      } catch (_) {}
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il collegamento.')),
      );
    }
  }

  Future<void> _showNoteContentDialog(Ancode match) async {
    if (!mounted) return;
    final body = (match.noteText ?? '').trim();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          match.code.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.bluUniversoDeep,
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            body.isEmpty ? '—' : body,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.bluPolvere,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Chiudi', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _openContent(Ancode match) async {
    final raw = _externalUrlRaw(match);
    if (raw != null) {
      await _openExternalFromMatch(match, raw);
      return;
    }
    await _showNoteContentDialog(match);
  }

  String _municipalityLabel(Ancode match) {
    if (match.isExclusiveItaly) return 'Italia';
    final name = match.municipality?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return match.municipalityId;
  }

  static const double _logoSize = 228;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 600;
    final idleCentered = isPhone && _lastResult == null;
    final topGap = isPhone ? 28.0 : 72.0;
    final logoSectionGap = isPhone ? 28.0 : 36.0;
    final tailGap = isPhone ? 24.0 : 100.0;
    final matches = <Ancode>[
      if (_lastResult?.uniqueMatch != null) _lastResult!.uniqueMatch!,
      ...?_lastResult?.multipleMatches,
    ];
    final hasContentMatch = matches.isNotEmpty;
    final hasMultipleMatches = (_lastResult?.multipleMatches?.length ?? 0) > 1;

    final logoAndCard = <Widget>[
      const AncodeLogo(
        size: _logoSize,
        showName: true,
        logoAssetPath: 'assets/logo.png',
        nameColor: AppColors.slateNavy,
        nameFontSize: 50,
      ),
      SizedBox(height: logoSectionGap),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WhiteLimePillSurface(
            height: 58,
            shadowDepth: 8,
            borderWidth: 1.5,
            outlineColor: AppColors.slateNavy,
            railColor: AppColors.limeMockup,
            extrusionDx: 4,
            depthOutlined: true,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                hintText: 'INSERISCI ANCODE',
                hintStyle: TextStyle(
                  color: AppColors.slateNavy,
                  fontSize: 17,
                  fontWeight: FontWeight.w300,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              ),
              style: const TextStyle(
                color: AppColors.slateNavy,
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              inputFormatters: const [_codeInputFormatter],
              onChanged: _onCodeChanged,
              onSubmitted: (String value) => unawaited(_onSearchSubmitted(value)),
            ),
          ),
          const SizedBox(height: 16),
          LimeRailPillButton(
            label: 'CERCA',
            height: 58,
            loading: _isSearching,
            fillColor: AppColors.slateNavy,
            shadowFaceColor: AppColors.limeMockup,
            extrusionDx: 4,
            depthOutlined: true,
            faceBorderColor: const Color(0xFF000000),
            depthBorderColor: const Color(0xFF000000),
            onPressed: _isSearching
                ? null
                : () {
                    unawaited(_onSearchSubmitted(_controller.text));
                  },
          ),
          if (hasMultipleMatches) ...[
            const SizedBox(height: 16),
            _CommuneDropdown(
              matches: _lastResult!.multipleMatches!,
              selectedMatch: _selectedMatch,
              labelFor: _municipalityLabel,
              onChanged: (match) => setState(() => _selectedMatch = match),
            ),
          ],
          if (hasContentMatch) ...[
            const SizedBox(height: 16),
            LimeFacePillButton(
              label: 'Vai al contenuto',
              height: 58,
              showOutline: true,
              outlineColor: AppColors.slateNavy,
              outlineWidth: 1.5,
              faceColor: AppColors.limeMockup,
              shadowFaceColor: AppColors.limeMockup,
              extrusionDx: 4,
              depthOutlined: true,
              depthOutlineColor: AppColors.slateNavy,
              depthOutlineWidth: 1.5,
              labelColor: AppColors.slateNavy,
              onPressed: _selectedMatch == null
                  ? null
                  : () async {
                      await _openContent(_selectedMatch!);
                    },
            ),
          ],
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final minH = constraints.maxHeight;
                final scrollChild = idleCentered
                    ? Align(
                        // Nudge block upward so space below the card (above bottom nav) is smaller
                        // than true vertical center (full-height Column + center caused a huge gap).
                        alignment: const Alignment(0, -0.38),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: logoAndCard,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: topGap),
                          ...logoAndCard,
                          if (_lastResult?.error != null) ...[
                            const SizedBox(height: 24),
                            Text(_lastResult!.error!, style: const TextStyle(color: AppColors.bluPolvere)),
                          ],
                          if (hasMultipleMatches) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Questo ANCODE esiste in più comuni. Scegli il comune per aprire il contenuto corretto.',
                              style: AppTypography.bodyRegular(
                                color: AppColors.placeholderGrey,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (_lastResult != null &&
                              _lastResult!.uniqueMatch == null &&
                              _lastResult!.multipleMatches == null &&
                              _lastResult!.similarCodes != null &&
                              _lastResult!.similarCodes!.isNotEmpty)
                            ..._lastResult!.similarCodes!.map(
                              (c) => ListTile(
                                title: Text(c, style: const TextStyle(color: AppColors.bluPolvere)),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CodeResolveScreen(code: c)),
                                ).then((_) => _onCodeResolved()),
                              ),
                            ),
                          SizedBox(height: tailGap),
                        ],
                      );

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minH),
                    child: scrollChild,
                  ),
                );
              },
            ),
            Positioned(
              top: 4,
              right: 8,
              child: Consumer<AuthService>(
                builder: (context, auth, _) {
                  if (!auth.isLoggedIn) return const SizedBox.shrink();
                  final red = Colors.red.shade700;
                  return TextButton.icon(
                    onPressed: () => context.read<AuthService>().signOut(),
                    icon: Icon(Icons.logout, size: 22, color: red),
                    label: Text(
                      'Esci',
                      style: TextStyle(
                        color: red,
                        fontWeight: FontWeight.w600,
                        fontSize: isPhone ? 15 : 16,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: red,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommuneDropdown extends StatelessWidget {
  const _CommuneDropdown({
    required this.matches,
    required this.selectedMatch,
    required this.labelFor,
    required this.onChanged,
  });

  final List<Ancode> matches;
  final Ancode? selectedMatch;
  final String Function(Ancode match) labelFor;
  final ValueChanged<Ancode?> onChanged;

  @override
  Widget build(BuildContext context) {
    return WhiteLimePillSurface(
      height: 64,
      shadowDepth: 8,
      borderWidth: 1.5,
      outlineColor: AppColors.slateNavy,
      railColor: AppColors.limeMockup,
      extrusionDx: 4,
      depthOutlined: true,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Ancode>(
          value: selectedMatch,
          hint: const Text(
            'Scegli il comune',
            style: TextStyle(
              color: AppColors.placeholderGrey,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          isExpanded: true,
          icon: const Padding(
            padding: EdgeInsets.only(right: 18),
            child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.slateNavy),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          dropdownColor: AppColors.biancoOttico,
          style: const TextStyle(
            color: AppColors.slateNavy,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          items: matches
              .map(
                (match) => DropdownMenuItem<Ancode>(
                  value: match,
                  child: Text(labelFor(match), overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _UppercaseAlnumFormatter extends TextInputFormatter {
  const _UppercaseAlnumFormatter({required this.maxLength});

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var normalized = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalized.length > maxLength) {
      normalized = normalized.substring(0, maxLength);
    }
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}
