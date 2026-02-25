import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:shared/shared.dart' hide AppTheme;

import '../theme/app_theme.dart';
import '../services/auth_service.dart';
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
  Municipality? _selectedComune;
  bool _acceptedTerms = false;
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
      if (!_formKey.currentState!.validate() || _selectedComune == null || !_acceptedTerms) return;
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
          _createdAncode = _drafts.isNotEmpty ? _drafts.first.toAncodePlaceholder() : null;
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
    final bl = await Supabase.instance.client
        .from('blacklist')
        .select('id')
        .eq('normalized_code', d.code)
        .maybeSingle();
    if (bl != null) throw Exception('Codice non disponibile (blacklist)');

    await Supabase.instance.client.from('ancodes').insert({
      'code': d.code,
      'normalized_code': d.code,
      'type': d.type.name,
      'url': d.url,
      'note_text': d.noteText,
      'municipality_id': d.municipalityId,
      'owner_user_id': Supabase.instance.client.auth.currentUser!.id,
      'status': 'active',
    });
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
        appBar: AppBar(
          backgroundColor: AppColors.bluUniverso,
          elevation: 0,
          leading: IconButton(
            icon: const Text('*', style: TextStyle(color: AppColors.azzurroCiano, fontSize: 28)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'ANCODE',
            style: TextStyle(color: AppColors.biancoOttico, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'CREA un nuovo ANCODE',
                    style: TextStyle(
                      color: AppColors.biancoOttico,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Personalizza il tuo codice: collega un link o una nota, scegli il comune e la durata',
                    style: TextStyle(
                      color: AppColors.biancoOttico.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'CODICE Ancode',
                      labelStyle: const TextStyle(color: AppColors.biancoOttico),
                      hintText: 'ES: CASA20',
                      hintStyle: TextStyle(color: AppColors.bluPolvere.withOpacity(0.8)),
                      helperText: 'max. 30 caratteri, solo lettere maiuscole.',
                      helperStyle: TextStyle(color: AppColors.biancoOttico.withOpacity(0.7), fontSize: 12),
                    ),
                    style: const TextStyle(color: AppColors.bluUniverso),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9*]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (v) => validateCode(v ?? ''),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Tipo di contenuto',
                    style: TextStyle(color: AppColors.biancoOttico, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Link/URL')),
                            ButtonSegment(value: false, label: Text('Nota/Testo')),
                          ],
                          selected: {_isLink},
                          onSelectionChanged: (s) => setState(() => _isLink = s.first),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.biancoOttico;
                              }
                              return AppColors.bluPolvere.withOpacity(0.3);
                            }),
                            foregroundColor: WidgetStateProperty.all(AppColors.bluUniverso),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_isLink)
                    TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'Inserisci il link a cui vuoi collegare questo ANCODE',
                        labelStyle: const TextStyle(color: AppColors.biancoOttico),
                        hintText: 'https://esempio.com',
                        hintStyle: TextStyle(color: AppColors.bluPolvere.withOpacity(0.8)),
                      ),
                      style: const TextStyle(color: AppColors.bluUniverso),
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
                        labelText: 'Testo nota',
                        labelStyle: const TextStyle(color: AppColors.biancoOttico),
                      ),
                      style: const TextStyle(color: AppColors.bluUniverso),
                      maxLines: 4,
                      validator: (v) =>
                          !_isLink && (v == null || v.trim().isEmpty)
                              ? 'Inserisci testo'
                              : null,
                    ),
                  const SizedBox(height: 20),
                  _ComunePicker(
                    selected: _selectedComune,
                    onSelected: (m) => setState(() => _selectedComune = m),
                  ),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    value: _acceptedTerms,
                    onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                    title: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: AppColors.biancoOttico, fontSize: 14),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isCreating ? null : () {
                            if (_formKey.currentState!.validate() &&
                                _selectedComune != null &&
                                _acceptedTerms) _addCode();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.biancoOttico,
                            side: const BorderSide(color: AppColors.verdeCosmico),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Crea pacchetto'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isCreating ? null : _commit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.verdeCosmico,
                            foregroundColor: AppColors.bluUniverso,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isCreating
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Procedi con il pagamento'),
                        ),
                      ),
                    ],
                  ),
                  if (_drafts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Codici da creare: ${_drafts.length}',
                      style: const TextStyle(color: AppColors.biancoOttico, fontWeight: FontWeight.w600),
                    ),
                    ..._drafts.map((d) => ListTile(
                          title: Text(d.code, style: const TextStyle(color: AppColors.biancoOttico)),
                          subtitle: Text(d.municipalityId, style: TextStyle(color: AppColors.biancoOttico.withOpacity(0.7))),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: AppColors.biancoOttico),
                            onPressed: () => setState(() => _drafts.remove(d)),
                          ),
                        )),
                    ElevatedButton(
                      onPressed: _isCreating ? null : _commit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.verdeCosmico,
                        foregroundColor: AppColors.bluUniverso,
                      ),
                      child: const Text('Crea tutti'),
                    ),
                  ],
                ],
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
    if (mounted) setState(() {
      _results = list;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppColors.biancoOttico : AppColors.bluUniverso;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _queryController,
          decoration: InputDecoration(
            labelText: 'Comune',
            labelStyle: TextStyle(color: labelColor),
            hintText: 'Digita per cercare il Comune',
            hintStyle: TextStyle(color: AppColors.bluPolvere.withOpacity(0.8)),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          style: const TextStyle(color: AppColors.bluUniverso),
          onChanged: _search,
          validator: (_) =>
              widget.selected == null ? 'Seleziona un Comune' : null,
        ),
        if (widget.selected != null) ...[
          const SizedBox(height: 8),
          Chip(
            label: Text(widget.selected!.name, style: const TextStyle(color: AppColors.bluUniverso)),
            backgroundColor: AppColors.verdeCosmico,
            onDeleted: () => widget.onSelected(null),
          ),
        ],
        if (_results.isNotEmpty)
          Card(
            color: AppColors.biancoOttico,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final m = _results[i];
                  return ListTile(
                    title: Text(m.name, style: const TextStyle(color: AppColors.bluUniverso)),
                    subtitle: m.province != null ? Text(m.province!, style: const TextStyle(color: AppColors.bluPolvere)) : null,
                    onTap: () {
                      widget.onSelected(m);
                      _queryController.clear();
                      setState(() => _results = []);
                    },
                  );
                },
              ),
            ),
          ),
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
    return Scaffold(
      appBar: AppBar(title: Text('*${ancode.code}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Link breve:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(shortlink),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => Clipboard.setData(ClipboardData(text: shortlink)),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copia'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Share.share(shortlink),
                    icon: const Icon(Icons.share),
                    label: const Text('Condividi'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              RepaintBoundary(
                key: GlobalKey(),
                child: QrImageView(
                  data: shortlink,
                  version: QrVersions.auto,
                  size: 200,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await Printing.layoutPdf(
                    onLayout: (format) async {
                      final pdf = pw.Document();
                      pdf.addPage(
                        pw.Page(
                          pageFormat: format,
                          build: (ctx) => pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('*${ancode.code}', style: pw.TextStyle(fontSize: 24)),
                              pw.SizedBox(height: 16),
                              pw.Text(shortlink, style: const pw.TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                      return pdf.save();
                    },
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text('Esporta PDF'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(shortlink)),
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
