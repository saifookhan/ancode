import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart' hide AppTheme;

import '../theme/app_theme.dart';
import 'auth/login_screen.dart';
import 'main_shell.dart';
import '../services/ancode_service.dart';
import '../services/plan_mode_service.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, this.prefillCode});

  final String? prefillCode;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  static const _fontFamily = AppFonts.family;
  static const _codeInputFormatter = _UppercaseAlnumFormatter(maxLength: 30);
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _urlController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLink = true;
  Municipality? _selectedComune = const Municipality(istatCode: 'ALL', name: 'All');
  bool _isExclusive = false;
  DateTime? _scheduleStart;
  DateTime? _scheduleEnd;
  bool _isCreating = false;
  String? _error;
  List<_DraftCode> _drafts = [];

  @override
  void initState() {
    super.initState();
    if (widget.prefillCode != null && widget.prefillCode!.isNotEmpty) {
      _codeController.text = _normalizeCodeInput(widget.prefillCode!);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _urlController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addCode() {
    final code = _normalizeCodeInput(_codeController.text);
    if (code.isEmpty) return;
    if (!isValidCodeFormat(code)) return;
    if (_isLink && _urlController.text.trim().isEmpty) return;
    if (!_isLink && _noteController.text.trim().isEmpty) return;
    if (_selectedComune == null) return;

    setState(() {
      _drafts.add(_DraftCode(
        code: code,
        type: _isLink ? AncodeType.link : AncodeType.note,
        url: _isLink ? _urlController.text.trim() : null,
        noteText: !_isLink ? _noteController.text.trim() : null,
        municipalityId: _selectedComune!.istatCode,
      ));
      _codeController.clear();
      _urlController.clear();
      _noteController.clear();
    });
  }

  Future<void> _commit() async {
    // If no drafts, add current form as one and then commit
    if (_drafts.isEmpty) {
      if (!_formKey.currentState!.validate()) return;
      if (_selectedComune == null) {
        setState(() => _error = 'Seleziona un Comune');
        return;
      }
      _addCode();
      if (_drafts.isEmpty) return; // e.g. validation failed
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Accedi per creare codici');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Accedi per creare codici'),
            action: SnackBarAction(
              label: 'Accedi',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            ),
          ),
        );
      }
      return;
    }
    setState(() {
      _error = null;
      _isCreating = true;
    });
    try {
      for (final d in _drafts) {
        await _createOne(d);
      }
      if (mounted) {
        setState(() {
          _drafts = [];
          _isCreating = false;
        });
        final shell = context.findAncestorStateOfType<MainShellState>();
        shell?.goToTab(MainShellState.dashboardTabIndex);
        shell?.refreshProfileCodesUsage();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isCreating = false;
        });
      }
    }
  }

  String _normalizeCodeInput(String value) {
    final cleaned = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return cleaned.length > 30 ? cleaned.substring(0, 30) : cleaned;
  }

  void _onCodeChanged(String value) {
    final normalized = _normalizeCodeInput(value);
    if (normalized == value) return;
    _codeController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  Future<void> _createOne(_DraftCode d) async {
    final plan = PlanModeService.currentPlan(Supabase.instance.client.auth.currentUser);
    final isBusinessPlan = plan == PlanModeService.business;
    final exclusiveItaly =
        plan == PlanModeService.free ? false : _isExclusive;
    await AncodeService.createAncode(
      code: d.code,
      type: d.type,
      municipalityId: d.municipalityId,
      isExclusiveItaly: exclusiveItaly,
      url: d.url,
      noteText: d.noteText,
      scheduleStart: isBusinessPlan ? _scheduleStart : null,
      scheduleEnd: isBusinessPlan ? _scheduleEnd : null,
    );
  }

  Future<void> _pickScheduleDate({
    required bool isStart,
  }) async {
    final now = DateTime.now();
    final initial = isStart ? (_scheduleStart ?? now) : (_scheduleEnd ?? _scheduleStart ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _scheduleStart = DateTime(picked.year, picked.month, picked.day);
        if (_scheduleEnd != null && _scheduleEnd!.isBefore(_scheduleStart!)) {
          _scheduleEnd = _scheduleStart;
        }
      } else {
        _scheduleEnd = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  static const double _pillShadow = 8;
  static const double _pillRadius = 999;
  /// Same neo-brut stack as home “INSERISCI ANCODE”.
  static const double _pillBorderW = 1.5;
  static const double _pillExtrusion = 4;
  static const Color _typeInactiveBorder = Color(0xFF5C5C8A);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final titleSize = isPhone ? 40.0 : 44.0;
    final subtitleSize = isPhone ? 16.0 : 18.0;
    final fieldTextSize = isPhone ? 16.0 : 18.0;
    final fieldHintSize = isPhone ? 15.0 : 16.0;
    final typeButtonTextSize = isPhone ? 16.0 : 17.0;
    final typeButtonVerticalPadding = isPhone ? 14.0 : 16.0;
    final buttonTextSize = isPhone ? 20.0 : 22.0;
    const pillFieldH = 58.0;
    final pillNoteH = isPhone ? 140.0 : 160.0;
    final currentPlan = PlanModeService.currentPlan(Supabase.instance.client.auth.currentUser);
    final isFreePlan = currentPlan == PlanModeService.free;
    final isBusinessPlan = currentPlan == PlanModeService.business;

    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppColors.creaScreenBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AncodeCreateTopBar(
                backgroundColor: AppColors.creaScreenBackground,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),
                        Center(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Crea nuovo ANCODE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  color: AppColors.biancoOttico,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Genera il tuo codice personalizzato',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  color: AppColors.biancoOttico.withOpacity(0.62),
                                  fontSize: subtitleSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Inserisci il tuo ANCODE',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            color: AppColors.biancoOttico.withOpacity(0.58),
                            fontSize: isPhone ? 13.5 : 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        WhiteLimePillSurface(
                          height: pillFieldH,
                          shadowDepth: _pillShadow,
                          borderWidth: _pillBorderW,
                          outlineColor: AppColors.slateNavy,
                          railColor: AppColors.limeMockup,
                          extrusionDx: _pillExtrusion,
                          depthOutlined: true,
                          child: TextFormField(
                            controller: _codeController,
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              color: AppColors.bluUniverso,
                              fontSize: fieldTextSize,
                            ),
                            decoration: InputDecoration(
                              hintText: 'es. Sito Web Personale',
                              hintStyle: TextStyle(
                                fontFamily: _fontFamily,
                                color: AppColors.placeholderGrey,
                                fontSize: fieldHintSize,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: const [_codeInputFormatter],
                            onChanged: (value) {
                              _onCodeChanged(value);
                              setState(() {});
                            },
                            validator: (v) => validateCode(v ?? ''),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Tipo di contenuto',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            color: AppColors.biancoOttico.withOpacity(0.58),
                            fontWeight: FontWeight.w500,
                            fontSize: isPhone ? 13.5 : 14.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _typeButton(
                                label: 'Link / URL',
                                selected: _isLink,
                                onTap: () => setState(() => _isLink = true),
                                textSize: typeButtonTextSize,
                                verticalPadding: typeButtonVerticalPadding,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _typeButton(
                                label: 'Nota/Testo',
                                selected: !_isLink,
                                onTap: () => setState(() => _isLink = false),
                                textSize: typeButtonTextSize,
                                verticalPadding: typeButtonVerticalPadding,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _isLink
                              ? 'Inserisci il link che vuoi connettere all\'ANCODE'
                              : 'Inserisci la tua nota',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            color: AppColors.biancoOttico.withOpacity(0.58),
                            fontSize: isPhone ? 13.5 : 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isLink)
                          WhiteLimePillSurface(
                            height: pillFieldH,
                            shadowDepth: _pillShadow,
                            borderWidth: _pillBorderW,
                            outlineColor: AppColors.slateNavy,
                            railColor: AppColors.limeMockup,
                            extrusionDx: _pillExtrusion,
                            depthOutlined: true,
                            child: TextFormField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                hintText: 'https://espenp.io',
                                hintStyle: TextStyle(
                                  fontFamily: _fontFamily,
                                  color: AppColors.placeholderGrey,
                                  fontSize: fieldHintSize,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                              ),
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                color: AppColors.bluUniverso,
                                fontSize: fieldTextSize,
                              ),
                              keyboardType: TextInputType.url,
                              validator: (v) =>
                                  _isLink && (v == null || v.trim().isEmpty)
                                      ? 'Inserisci URL'
                                      : null,
                            ),
                          )
                        else
                          WhiteLimePillSurface(
                            height: pillNoteH,
                            shadowDepth: _pillShadow,
                            borderWidth: _pillBorderW,
                            outlineColor: AppColors.slateNavy,
                            railColor: AppColors.limeMockup,
                            extrusionDx: _pillExtrusion,
                            depthOutlined: true,
                            cornerRadius: 10,
                            child: TextFormField(
                              controller: _noteController,
                              textAlign: TextAlign.center,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                hintText: 'Aggiungi una nota o un testo',
                                hintStyle: TextStyle(
                                  fontFamily: _fontFamily,
                                  color: AppColors.placeholderGrey,
                                  fontSize: fieldHintSize,
                                ),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                              ),
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                color: AppColors.bluUniverso,
                                fontSize: fieldTextSize,
                              ),
                              maxLines: 4,
                              validator: (v) =>
                                  !_isLink && (v == null || v.trim().isEmpty)
                                      ? 'Inserisci testo'
                                      : null,
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          'Comune',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            color: AppColors.biancoOttico.withOpacity(0.58),
                            fontSize: isPhone ? 13.5 : 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ComunePicker(
                          selected: _selectedComune,
                          onSelected: (m) => setState(() => _selectedComune = m),
                          pillHeight: pillFieldH,
                        ),
                        if (isBusinessPlan) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Schedule start/end (opzionale)',
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              color: AppColors.biancoOttico.withOpacity(0.58),
                              fontSize: isPhone ? 13.5 : 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _SchedulePillButton(
                                  label: _scheduleStart == null
                                      ? 'Start Date'
                                      : _scheduleStart!
                                          .toLocal()
                                          .toIso8601String()
                                          .split('T')
                                          .first,
                                  onTap: () => _pickScheduleDate(isStart: true),
                                  fontFamily: _fontFamily,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SchedulePillButton(
                                  label: _scheduleEnd == null
                                      ? 'End Date'
                                      : _scheduleEnd!
                                          .toLocal()
                                          .toIso8601String()
                                          .split('T')
                                          .first,
                                  onTap: () => _pickScheduleDate(isStart: false),
                                  fontFamily: _fontFamily,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Se non impostato: attivo subito fino alla scadenza abbonamento.',
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                color: AppColors.biancoOttico.withOpacity(0.52),
                                fontSize: isPhone ? 11 : 13,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _ExclusiveCircleSelector(
                          fontFamily: _fontFamily,
                          isPhone: isPhone,
                          enabled: !isFreePlan,
                          selected: isFreePlan ? false : _isExclusive,
                          onChanged: (v) => setState(() => _isExclusive = v),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.verdeCosmico),
                          ),
                        ],
                        const SizedBox(height: 24),
                        WhiteLimePillButton(
                          height: isPhone ? 58 : 72,
                          shadowDepth: _pillShadow,
                          fontSize: buttonTextSize,
                          extrusionDx: _pillExtrusion,
                          railColor: AppColors.limeMockup,
                          outlineColor: AppColors.slateNavy,
                          depthOutlined: true,
                          borderWidth: _pillBorderW,
                          labelColor: AppColors.slateNavy,
                          onPressed: _isCreating
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate() &&
                                      _selectedComune != null) {
                                    _commit();
                                  } else if (_selectedComune == null) {
                                    setState(() => _error = 'Seleziona un Comune');
                                  }
                                },
                          loading: _isCreating,
                          label: 'Genera codice',
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required double textSize,
    required double verticalPadding,
  }) {
    const h = 50.0;
    if (selected) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_pillRadius),
          child: WhiteLimePillSurface(
            height: h,
            shadowDepth: _pillShadow,
            borderWidth: _pillBorderW,
            outlineColor: AppColors.slateNavy,
            railColor: AppColors.limeMockup,
            extrusionDx: _pillExtrusion,
            depthOutlined: true,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  color: AppColors.slateNavy,
                  fontSize: textSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_pillRadius),
        child: Container(
          height: h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.bluUniversoLight,
            borderRadius: BorderRadius.circular(_pillRadius),
            border: Border.all(color: _typeInactiveBorder, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: _fontFamily,
              color: AppColors.biancoOttico.withOpacity(0.68),
              fontSize: textSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular on/off control with label for “codice esclusivo” on Crea (radio-style, not a square checkbox).
class _ExclusiveCircleSelector extends StatelessWidget {
  const _ExclusiveCircleSelector({
    required this.fontFamily,
    required this.isPhone,
    required this.enabled,
    required this.selected,
    required this.onChanged,
  });

  final String fontFamily;
  final bool isPhone;
  final bool enabled;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rendi questo codice esclusivo',
      hint: enabled ? 'Attiva o disattiva' : 'Non disponibile nel piano FREE',
      toggled: selected && enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onChanged(!selected) : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.biancoOttico.withOpacity(enabled ? 0.52 : 0.28),
                            width: 2,
                          ),
                          color: selected && enabled
                              ? AppColors.biancoOttico
                              : Colors.transparent,
                        ),
                        child: selected && enabled
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.slateNavy,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Rendi questo codice esclusivo (previeni che venga usato in altre località)',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          color: AppColors.biancoOttico.withOpacity(enabled ? 0.78 : 0.42),
                          fontSize: isPhone ? 12.5 : 15,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!enabled) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Text(
                      'Disponibile con piano Pro o Business.',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: AppColors.biancoOttico.withOpacity(0.5),
                        fontSize: isPhone ? 11.5 : 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SchedulePillButton extends StatelessWidget {
  const _SchedulePillButton({
    required this.label,
    required this.onTap,
    required this.fontFamily,
  });

  final String label;
  final VoidCallback onTap;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: WhiteLimePillSurface(
          height: 52,
          shadowDepth: _CreateScreenState._pillShadow,
          borderWidth: _CreateScreenState._pillBorderW,
          outlineColor: AppColors.slateNavy,
          railColor: AppColors.limeMockup,
          extrusionDx: _CreateScreenState._pillExtrusion,
          depthOutlined: true,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: fontFamily,
                  color: AppColors.bluUniversoDeep,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftCode {
  _DraftCode({
    required this.code,
    required this.type,
    this.url,
    this.noteText,
    required this.municipalityId,
  });

  final String code;
  final AncodeType type;
  final String? url;
  final String? noteText;
  final String municipalityId;
}

class _ComunePicker extends StatefulWidget {
  const _ComunePicker({
    required this.selected,
    required this.onSelected,
    required this.pillHeight,
  });

  final Municipality? selected;
  final ValueChanged<Municipality?> onSelected;
  final double pillHeight;

  @override
  State<_ComunePicker> createState() => _ComunePickerState();
}

class _ComunePickerState extends State<_ComunePicker> {
  final _queryController = TextEditingController();
  List<Municipality> _results = [];
  bool _searching = false;
  bool _isOpen = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      await _loadDefaultOptions();
      return;
    }
    setState(() => _searching = true);
    final list = await AncodeService.searchRegionCities(q);
    if (mounted)
      setState(() {
        _results = [const Municipality(istatCode: 'ALL', name: 'All'), ...list];
        _searching = false;
      });
  }

  Future<void> _loadDefaultOptions() async {
    setState(() => _searching = true);
    final list = await AncodeService.listRegionCities();
    if (!mounted) return;
    setState(() {
      _results = [const Municipality(istatCode: 'ALL', name: 'All'), ...list];
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedText = widget.selected?.name ?? 'All';
    final isPhone = MediaQuery.of(context).size.width < 600;
    final pickerTextSize = isPhone ? 16.0 : 18.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WhiteLimePillSurface(
          height: widget.pillHeight,
          shadowDepth: _CreateScreenState._pillShadow,
          borderWidth: _CreateScreenState._pillBorderW,
          outlineColor: AppColors.slateNavy,
          railColor: AppColors.limeMockup,
          extrusionDx: _CreateScreenState._pillExtrusion,
          depthOutlined: true,
          child: TextFormField(
            readOnly: true,
            controller: TextEditingController(text: selectedText),
            style: TextStyle(fontFamily: _CreateScreenState._fontFamily, color: AppColors.bluUniverso, fontSize: pickerTextSize),
            decoration: InputDecoration(
              hintText: '',
              hintStyle: TextStyle(fontFamily: _CreateScreenState._fontFamily, color: AppColors.placeholderGrey, fontSize: pickerTextSize),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              suffixIcon: IconButton(
                onPressed: () async {
                  final next = !_isOpen;
                  setState(() => _isOpen = next);
                  if (next) await _loadDefaultOptions();
                },
                icon: Icon(
                  _isOpen ? Icons.close : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF6C7280),
                  size: isPhone ? 22 : 30,
                ),
              ),
            ),
            onTap: () async {
              final next = !_isOpen;
              setState(() => _isOpen = next);
              if (next) await _loadDefaultOptions();
            },
            validator: (_) => widget.selected == null ? 'Seleziona un Comune' : null,
          ),
        ),
        if (_isOpen) ...[
          const SizedBox(height: 8),
          Card(
            color: AppColors.biancoOttico,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    child: TextField(
                      controller: _queryController,
                      onChanged: _search,
                      style: const TextStyle(fontFamily: _CreateScreenState._fontFamily, color: AppColors.bluUniverso),
                      decoration: InputDecoration(
                        hintText: 'Cerca comune',
                        hintStyle: const TextStyle(fontFamily: _CreateScreenState._fontFamily, color: AppColors.placeholderGrey),
                        prefixIcon: const Icon(Icons.search, color: AppColors.placeholderGrey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: AppColors.biancoOttico,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFB8BEC8)),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE6E6E6)),
                  Expanded(
                    child: _searching
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _results.isEmpty
                            ? const Center(
                                child: Text(
                                  'No record',
                                  style: TextStyle(fontFamily: _CreateScreenState._fontFamily, color: AppColors.bluPolvere, fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _results.length,
                                itemBuilder: (_, i) {
                                  final m = _results[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      m.name,
                                      style: const TextStyle(fontFamily: _CreateScreenState._fontFamily, color: AppColors.bluUniverso),
                                    ),
                                    subtitle: m.province != null
                                        ? Text(
                                            m.province!,
                                            style: const TextStyle(fontFamily: _CreateScreenState._fontFamily, color: AppColors.bluPolvere),
                                          )
                                        : null,
                                    onTap: () {
                                      widget.onSelected(m);
                                      _queryController.clear();
                                      setState(() {
                                        _results = [];
                                        _isOpen = false;
                                      });
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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
