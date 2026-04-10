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

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, this.prefillCode});

  final String? prefillCode;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _urlController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLink = true;
  Municipality? _selectedComune = const Municipality(
    istatCode: 'ALL',
    name: 'All',
  );
  bool _acceptedTerms = false;
  bool _isExclusive = false;
  int _termMonths = 1;
  bool _isCreating = false;
  String? _error;
  List<_DraftCode> _drafts = [];
  Ancode? _createdAncode;

  @override
  void initState() {
    super.initState();
    if (widget.prefillCode != null && widget.prefillCode!.isNotEmpty) {
      _codeController.text = widget.prefillCode!;
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
    final code = normalizeCodeInput(_codeController.text);
    if (code.isEmpty) return;
    if (!isValidCodeFormat(code)) return;
    if (_isLink && _urlController.text.trim().isEmpty) return;
    if (!_isLink && _noteController.text.trim().isEmpty) return;
    if (_selectedComune == null) return;
    if (!_acceptedTerms) return;

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
      if (!_formKey.currentState!.validate() ||
          _selectedComune == null ||
          !_acceptedTerms) return;
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

  Future<void> _createOne(_DraftCode d) async {
    await AncodeService.createAncode(
      code: d.code,
      type: d.type,
      municipalityId: d.municipalityId,
      isExclusiveItaly: _isExclusive,
      url: d.url,
      noteText: d.noteText,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 8),
                  const Text(
                    'CREA un nuovo ANCODE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.biancoOttico,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Personalizza il tuo codice: collega un link o una nota, scegli il comune e la durata',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.biancoOttico.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'INSERISCI IL TUO ANCODE',
                    style: TextStyle(
                      color: AppColors.biancoOttico,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: 'ES: CASA20',
                      hintStyle: const TextStyle(color: AppColors.placeholderGrey, fontSize: 16),
                      filled: true,
                      fillColor: AppColors.biancoOttico,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                        borderSide: const BorderSide(color: AppColors.verdeCosmico, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                        borderSide: const BorderSide(color: AppColors.verdeCosmico, width: 2),
                      ),
                      helperText: 'max. 30 caratteri, solo lettere maiuscole.',
                      helperStyle: TextStyle(
                          color: AppColors.biancoOttico.withOpacity(0.7),
                          fontSize: 12),
                    ),
                    style: const TextStyle(color: AppColors.bluUniverso, fontSize: 18),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9*]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (v) => validateCode(v ?? ''),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Content type *',
                    style: TextStyle(
                        color: AppColors.biancoOttico,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          value: true,
                          groupValue: _isLink,
                          onChanged: (_) => setState(() => _isLink = true),
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.lavanda,
                          title: const Text('Link / URL', style: TextStyle(color: AppColors.biancoOttico)),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          value: false,
                          groupValue: _isLink,
                          onChanged: (_) => setState(() => _isLink = false),
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.lavanda,
                          title: Text('Note / Text', style: TextStyle(color: AppColors.biancoOttico.withOpacity(0.8))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_isLink)
                    TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'https://espenp.io',
                        hintStyle: TextStyle(color: AppColors.placeholderGrey.withOpacity(0.9), fontSize: 16),
                        filled: true,
                        fillColor: AppColors.biancoOttico,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(40),
                          borderSide: const BorderSide(color: AppColors.verdeCosmico, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(40),
                          borderSide: const BorderSide(color: AppColors.verdeCosmico, width: 2),
                        ),
                      ),
                      style: const TextStyle(color: AppColors.bluUniverso, fontSize: 18),
                      keyboardType: TextInputType.url,
                      validator: (v) =>
                          _isLink && (v == null || v.trim().isEmpty)
                              ? 'Inserisci URL'
                              : null,
                    )
                  else
                    TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText: 'Scrivi qui...',
                        hintStyle: TextStyle(color: AppColors.placeholderGrey.withOpacity(0.9), fontSize: 24),
                        filled: true,
                        fillColor: AppColors.biancoOttico,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(color: AppColors.verdeCosmico, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(color: AppColors.verdeCosmico, width: 2),
                        ),
                      ),
                      style: const TextStyle(color: AppColors.bluUniverso, fontSize: 24),
                      maxLines: 4,
                      validator: (v) =>
                          !_isLink && (v == null || v.trim().isEmpty)
                              ? 'Inserisci testo'
                              : null,
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'Region of Area',
                    style: TextStyle(color: AppColors.biancoOttico.withOpacity(0.95), fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _ComunePicker(
                    selected: _selectedComune,
                    onSelected: (m) => setState(() => _selectedComune = m),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Term',
                    style: TextStyle(color: AppColors.biancoOttico.withOpacity(0.95), fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<int>(
                    value: 1,
                    groupValue: _termMonths,
                    onChanged: (v) => setState(() => _termMonths = v ?? 1),
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF3B59FF),
                    title: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.biancoOttico,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('1 Month', style: TextStyle(color: AppColors.bluUniverso)),
                    ),
                  ),
                  RadioListTile<int>(
                    value: 12,
                    groupValue: _termMonths,
                    onChanged: (v) => setState(() => _termMonths = v ?? 12),
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF3B59FF),
                    title: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.verdeCosmicoSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('12 Month (Yearly)', style: TextStyle(color: AppColors.bluUniverso)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    value: _isExclusive,
                    onChanged: (v) => setState(() => _isExclusive = v ?? false),
                    title: const Text(
                      'Make this code exclusive (prevents use in other municipalities)',
                      style: TextStyle(color: AppColors.biancoOttico, fontSize: 14),
                    ),
                    activeColor: AppColors.verdeCosmico,
                    checkColor: AppColors.bluUniverso,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    value: _acceptedTerms,
                    onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                    title: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            color: AppColors.biancoOttico, fontSize: 14),
                        children: [
                          const TextSpan(text: 'Accetto i '),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () {},
                              child: const Text(
                                'termini e condizioni',
                                style: TextStyle(
                                  color: AppColors.azzurroCiano,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    activeColor: AppColors.verdeCosmico,
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
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: AppColors.limeNeobrut, blurRadius: 0, offset: Offset(0, 6)),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: _isCreating
                          ? null
                          : () {
                              if (_formKey.currentState!.validate() &&
                                  _selectedComune != null &&
                                  _acceptedTerms) {
                                _commit();
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.bluUniversoDeep,
                        foregroundColor: AppColors.biancoOttico,
                        minimumSize: const Size.fromHeight(58),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.biancoOttico),
                            )
                          : const Text('Generate Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Package Benifits',
                    style: TextStyle(color: AppColors.biancoOttico, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _benefitRow('15 % percent discount on total price'),
                  _benefitRow('Centralized managment of all codes'),
                  _benefitRow('Aggregated package statistics'),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _benefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.lavanda, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.biancoOttico.withOpacity(0.95), fontSize: 14),
            ),
          ),
        ],
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

  void _search(String q) async {
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final list = await AncodeService.searchMunicipalities(q);
    if (mounted)
      setState(() {
        _results = list;
        _searching = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final selectedText = widget.selected?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          readOnly: true,
          controller: TextEditingController(text: selectedText),
          style: const TextStyle(color: AppColors.bluUniverso, fontSize: 18),
          decoration: InputDecoration(
            hintText: '^',
            hintStyle: const TextStyle(color: AppColors.placeholderGrey, fontSize: 18),
            filled: true,
            fillColor: AppColors.biancoOttico,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.biancoOttico.withOpacity(0.7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.biancoOttico.withOpacity(0.9)),
            ),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _isOpen = !_isOpen),
              icon: Icon(
                _isOpen ? Icons.close : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF6C7280),
              ),
            ),
          ),
          onTap: () => setState(() => _isOpen = !_isOpen),
          validator: (_) => widget.selected == null ? 'Seleziona un Comune' : null,
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
