import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:shared/shared.dart' hide AppTheme;

import '../theme/app_theme.dart';
import 'auth/login_screen.dart';
import '../services/ancode_service.dart';
import '../services/app_config.dart';
import '../services/plan_mode_service.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, this.prefillCode});

  final String? prefillCode;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
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
  Ancode? _createdAncode;

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
          _createdAncode =
              _drafts.isNotEmpty ? _drafts.first.toAncodePlaceholder() : null;
          _drafts = [];
          _isCreating = false;
        });
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
    await AncodeService.createAncode(
      code: d.code,
      type: d.type,
      municipalityId: d.municipalityId,
      isExclusiveItaly: _isExclusive,
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

  static const double _radius = 24;
  static const double _greenBorder = 1.5;

  BoxDecoration _fieldDecoration() {
    return BoxDecoration(
      color: AppColors.biancoOttico,
      borderRadius: BorderRadius.circular(_radius),
      border: Border.all(color: AppColors.verdeCosmico, width: _greenBorder),
      boxShadow: const [
        BoxShadow(
          color: AppColors.limeNeobrut,
          blurRadius: 0,
          offset: Offset(0, 6),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final titleSize = isPhone ? 44.0 : 50.0;
    final subtitleSize = isPhone ? 17.0 : 30.0;
    final sectionTitleSize = isPhone ? 36.0 : 34.0;
    final labelSize = isPhone ? 14.0 : 33.0;
    final fieldTextSize = isPhone ? 16.0 : 34.0;
    final fieldHintSize = isPhone ? 15.0 : 32.0;
    final fieldVerticalPadding = isPhone ? 14.0 : 22.0;
    final typeButtonTextSize = isPhone ? 16.0 : 32.0;
    final typeButtonVerticalPadding = isPhone ? 14.0 : 20.0;
    final buttonTextSize = isPhone ? 20.0 : 34.0;
    final currentPlan = PlanModeService.currentPlan(Supabase.instance.client.auth.currentUser);
    final isFreePlan = currentPlan == PlanModeService.free;
    final isBusinessPlan = currentPlan == PlanModeService.business;

    if (_createdAncode != null) {
      return _OutputScreen(
        ancode: _createdAncode!,
        onDone: () => setState(() => _createdAncode = null),
      );
    }
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppColors.bluUniverso,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    'Crea nuovo ANCODE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.biancoOttico,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Genera il tuo codice personalizzato',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.biancoOttico.withOpacity(0.75),
                      fontSize: subtitleSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Inserisci il tuo ANCODE',
                    style: TextStyle(
                      color: AppColors.biancoOttico.withOpacity(0.92),
                      fontSize: sectionTitleSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _fieldDecoration(),
                    child: TextFormField(
                      controller: _codeController,
                      style: TextStyle(color: AppColors.bluUniverso, fontSize: fieldTextSize),
                      decoration: InputDecoration(
                        hintText: 'es. Sito Web Personale',
                        hintStyle: TextStyle(color: AppColors.placeholderGrey, fontSize: fieldHintSize),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 26, vertical: fieldVerticalPadding),
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
                  const SizedBox(height: 10),
                  Text(
                    'Max 30 caratteri, solo lettere maiuscole e numeri, simboli e spazi non ammessi.',
                    style: TextStyle(color: AppColors.biancoOttico.withOpacity(0.72), fontSize: isPhone ? 12 : 18),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Tipo di contenuto',
                    style: TextStyle(
                      color: AppColors.biancoOttico.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                      fontSize: labelSize,
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
                    style: TextStyle(color: AppColors.biancoOttico.withOpacity(0.85), fontSize: labelSize),
                  ),
                  const SizedBox(height: 8),
                  if (_isLink)
                    Container(
                      decoration: _fieldDecoration(),
                      child: TextFormField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'https://espenp.io',
                          hintStyle: TextStyle(color: AppColors.placeholderGrey, fontSize: fieldHintSize),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 26, vertical: fieldVerticalPadding),
                        ),
                        style: TextStyle(color: AppColors.bluUniverso, fontSize: fieldTextSize),
                        keyboardType: TextInputType.url,
                        validator: (v) => _isLink && (v == null || v.trim().isEmpty) ? 'Inserisci URL' : null,
                      ),
                    )
                  else
                    Container(
                      decoration: _fieldDecoration(),
                      child: TextFormField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          hintText: 'Scrivi qui...',
                          hintStyle: TextStyle(color: AppColors.placeholderGrey, fontSize: fieldHintSize),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 26, vertical: fieldVerticalPadding),
                        ),
                        style: TextStyle(color: AppColors.bluUniverso, fontSize: fieldTextSize),
                        maxLines: 4,
                        validator: (v) => !_isLink && (v == null || v.trim().isEmpty) ? 'Inserisci testo' : null,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'Comune',
                    style: TextStyle(color: AppColors.biancoOttico.withOpacity(0.9), fontSize: labelSize),
                  ),
                  const SizedBox(height: 8),
                  _ComunePicker(
                    selected: _selectedComune,
                    onSelected: (m) => setState(() => _selectedComune = m),
                  ),
                  if (isBusinessPlan) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Schedule start/end (opzionale)',
                      style: TextStyle(color: AppColors.biancoOttico.withOpacity(0.9), fontSize: labelSize),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickScheduleDate(isStart: true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.biancoOttico,
                              side: BorderSide(color: AppColors.biancoOttico.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            ),
                            child: Text(
                              _scheduleStart == null
                                  ? 'Start Date'
                                  : _scheduleStart!.toLocal().toIso8601String().split('T').first,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickScheduleDate(isStart: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.biancoOttico,
                              side: BorderSide(color: AppColors.biancoOttico.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            ),
                            child: Text(
                              _scheduleEnd == null
                                  ? 'End Date'
                                  : _scheduleEnd!.toLocal().toIso8601String().split('T').first,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Se non impostato: attivo subito fino alla scadenza abbonamento.',
                        style: TextStyle(color: AppColors.biancoOttico.withOpacity(0.72), fontSize: isPhone ? 11 : 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  CheckboxListTile(
                    value: _isExclusive,
                    onChanged: (v) => setState(() => _isExclusive = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Rendi questo codice esclusivo (previeni che venga usato in altre localita)',
                      style: TextStyle(color: AppColors.biancoOttico.withOpacity(0.86), fontSize: isPhone ? 12 : 28),
                    ),
                    activeColor: AppColors.biancoOttico,
                    checkColor: AppColors.bluUniverso,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.verdeCosmico),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_radius),
                      boxShadow: const [
                        BoxShadow(color: AppColors.limeNeobrut, blurRadius: 0, offset: Offset(0, 6)),
                      ],
                    ),
                    child: FilledButton(
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
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.biancoOttico,
                        foregroundColor: AppColors.bluUniverso,
                        minimumSize: Size.fromHeight(isPhone ? 58 : 74),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bluUniverso),
                            )
                          : Text('Genera codice', style: TextStyle(fontSize: buttonTextSize, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_radius),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        decoration: BoxDecoration(
          color: selected ? AppColors.biancoOttico : AppColors.bluUniversoLight,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: AppColors.biancoOttico.withOpacity(selected ? 0.0 : 0.2)),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: AppColors.limeNeobrut,
                    blurRadius: 0,
                    offset: Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.bluUniverso : AppColors.biancoOttico.withOpacity(0.7),
              fontSize: textSize,
              fontWeight: FontWeight.w500,
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

  Ancode toAncodePlaceholder() => Ancode(
        id: '',
        code: code,
        normalizedCode: code,
        type: type,
        url: url,
        noteText: noteText,
        municipalityId: municipalityId,
        ownerUserId: '',
      );
}

class _ComunePicker extends StatefulWidget {
  const _ComunePicker({
    required this.selected,
    required this.onSelected,
  });

  final Municipality? selected;
  final ValueChanged<Municipality?> onSelected;

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
    final list = await AncodeService.searchMunicipalities(q);
    if (mounted)
      setState(() {
        _results = [const Municipality(istatCode: 'ALL', name: 'All'), ...list];
        _searching = false;
      });
  }

  Future<void> _loadDefaultOptions() async {
    setState(() => _searching = true);
    final list = await AncodeService.listMunicipalities(limit: 20);
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
    final pickerTextSize = isPhone ? 16.0 : 34.0;
    final pickerVerticalPadding = isPhone ? 14.0 : 22.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.biancoOttico,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.verdeCosmico, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.limeNeobrut,
                blurRadius: 0,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: TextFormField(
            readOnly: true,
            controller: TextEditingController(text: selectedText),
            style: TextStyle(color: AppColors.bluUniverso, fontSize: pickerTextSize),
            decoration: InputDecoration(
              hintText: '',
              hintStyle: TextStyle(color: AppColors.placeholderGrey, fontSize: pickerTextSize),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 26, vertical: pickerVerticalPadding),
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
                      style: const TextStyle(color: AppColors.bluUniverso),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: const TextStyle(color: AppColors.placeholderGrey),
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
                                  style: TextStyle(color: AppColors.bluPolvere, fontSize: 16),
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
                                      style: const TextStyle(color: AppColors.bluUniverso),
                                    ),
                                    subtitle: m.province != null
                                        ? Text(
                                            m.province!,
                                            style: const TextStyle(color: AppColors.bluPolvere),
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

class _OutputScreen extends StatelessWidget {
  const _OutputScreen({
    required this.ancode,
    required this.onDone,
  });

  final Ancode ancode;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final shortlink = AppConfig.shortlinkFor(ancode.normalizedCode);
    final directTarget = ancode.type == AncodeType.link ? (ancode.url ?? shortlink) : shortlink;
    return Scaffold(
      appBar: AppBar(title: Text('*${ancode.code}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Link breve:',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SelectableText(
                shortlink,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: shortlink));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copiato')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copia'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await SharePlus.instance.share(
                          ShareParams(text: shortlink),
                        );
                      } catch (_) {
                        await Clipboard.setData(ClipboardData(text: shortlink));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Condivisione non disponibile: link copiato')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Condividi'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: RepaintBoundary(
                  key: GlobalKey(),
                  child: QrImageView(
                    data: shortlink,
                    version: QrVersions.auto,
                    size: 200,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await Printing.layoutPdf(
                      onLayout: (format) async {
                        final pdf = pw.Document();
                        pdf.addPage(
                          pw.Page(
                            pageFormat: format,
                            build: (ctx) => pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('*${ancode.code}',
                                    style: pw.TextStyle(fontSize: 24)),
                                pw.SizedBox(height: 16),
                                pw.Text(shortlink,
                                    style: const pw.TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                        return pdf.save();
                      },
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF export error: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.print),
                label: const Text('Esporta PDF'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(directTarget);
                  if (uri == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link non valido')),
                      );
                    }
                    return;
                  }
                  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Impossibile aprire il link')),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Testa link'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onDone,
                child: const Text('Crea un altro'),
              ),
            ],
          ),
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
