import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import '../services/ancode_service.dart';
import 'auth/login_screen.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, this.prefillCode});

  final String? prefillCode;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _codeController = TextEditingController();
  final _urlController = TextEditingController();
  final _noteController = TextEditingController();
  final _comuneQueryController = TextEditingController();
  bool _isLink = true;
  Municipality? _selectedComune;
  List<Municipality> _comuneResults = [];
  bool _isSearchingComuni = false;
  bool _isExclusive = false;
  bool _isSubmitting = false;

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
    _comuneQueryController.dispose();
    super.dispose();
  }

  static const double _radius = 24;
  static const double _greenBorder = 2;
  static const _codeInputFormatter = _UppercaseAlnumFormatter(maxLength: 30);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bluUniverso,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Crea nuovo ANCODE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.biancoOttico,
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Genera il tuo codice personalizzato',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.biancoOttico.withOpacity(0.9),
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Inserisci il tuo ANCODE',
                        style: TextStyle(
                          color: AppColors.biancoOttico,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _darkField(
                        controller: _codeController,
                        hint: 'es. Sito Web Personale',
                        helper: 'Max 30 caratteri, solo lettere maiuscole e numeri, simboli e spazi non ammessi.',
                        isCodeField: true,
                        onChanged: _onCodeChanged,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Tipo di contenuto',
                        style: TextStyle(
                          color: AppColors.biancoOttico,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _segmentButton(
                              label: 'Link / URL',
                              selected: _isLink,
                              onTap: () => setState(() => _isLink = true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _segmentButton(
                              label: 'Note / Text',
                              selected: !_isLink,
                              onTap: () => setState(() => _isLink = false),
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
                          color: AppColors.biancoOttico.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _darkField(
                        controller: _isLink ? _urlController : _noteController,
                        hint: _isLink ? 'https://espenp.io' : 'Scrivi qui...',
                        maxLines: _isLink ? 1 : 4,
                        keyboardType: _isLink ? TextInputType.url : null,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Comune',
                        style: TextStyle(
                          color: AppColors.biancoOttico,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _darkField(
                        controller: _comuneQueryController,
                        hint: 'Digita per cercare il Comune',
                        keyboardType: TextInputType.text,
                        onChanged: _searchComune,
                      ),
                      if (_isSearchingComuni)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.biancoOttico),
                            ),
                          ),
                        ),
                      if (_selectedComune != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            label: Text(_selectedComune!.name, style: const TextStyle(color: AppColors.bluUniverso)),
                            backgroundColor: AppColors.verdeCosmico,
                            onDeleted: () => setState(() => _selectedComune = null),
                          ),
                        ),
                      ],
                      if (_comuneResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: AppColors.biancoOttico,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.verdeCosmico, width: _greenBorder),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _comuneResults.length,
                            itemBuilder: (context, index) {
                              final comune = _comuneResults[index];
                              return ListTile(
                                title: Text(comune.name, style: const TextStyle(color: AppColors.bluPolvere)),
                                subtitle: comune.province != null
                                    ? Text(comune.province!, style: const TextStyle(color: AppColors.placeholderGrey))
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedComune = comune;
                                    _comuneQueryController.clear();
                                    _comuneResults = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _isExclusive,
                              onChanged: (v) => setState(() => _isExclusive = v ?? false),
                              activeColor: AppColors.verdeCosmico,
                              checkColor: AppColors.bluUniverso,
                              side: const BorderSide(color: AppColors.biancoOttico),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Rendi questo codice esclusivo (previeni che venga usato in altre localita)',
                                style: TextStyle(
                                  color: AppColors.biancoOttico.withOpacity(0.95),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _generateCodeButton(),
                      SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String hint,
    String? helper,
    int maxLines = 1,
    bool isCodeField = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.biancoOttico,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: AppColors.verdeCosmico, width: _greenBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.verdeCosmico.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.placeholderGrey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            style: const TextStyle(color: AppColors.bluPolvere),
            inputFormatters: isCodeField ? const [_codeInputFormatter] : null,
            textCapitalization: isCodeField ? TextCapitalization.characters : TextCapitalization.none,
            keyboardType: keyboardType,
            onChanged: onChanged,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper,
            style: TextStyle(
              color: AppColors.biancoOttico.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _segmentButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.verdeCosmico : AppColors.biancoOttico,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.verdeCosmico,
              width: _greenBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.bluUniverso : AppColors.bluPolvere,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _generateCodeButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.biancoOttico,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.verdeCosmico, width: _greenBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.verdeCosmico.withOpacity(0.45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSubmitting ? null : _onGenerateCode,
          borderRadius: BorderRadius.circular(_radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: _isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bluUniverso),
                    )
                  : const Text(
                      'Genera codice',
                      style: TextStyle(
                        color: AppColors.bluUniverso,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _searchComune(String q) async {
    if (q.trim().length < 2) {
      if (mounted) {
        setState(() {
          _comuneResults = [];
          _isSearchingComuni = false;
        });
      }
      return;
    }
    setState(() => _isSearchingComuni = true);
    final result = await AncodeService.searchMunicipalities(q.trim());
    if (!mounted) return;
    setState(() {
      _comuneResults = result;
      _isSearchingComuni = false;
    });
  }

  Future<void> _onGenerateCode() async {
    final code = _normalizeCodeInput(_codeController.text);
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un codice ANCODE')),
      );
      return;
    }
    if (!isValidCodeFormat(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codice non valido (max 30 caratteri, solo lettere e numeri)')),
      );
      return;
    }
    if (_isLink && _urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il link')),
      );
      return;
    }
    if (!_isLink && _noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il testo della nota')),
      );
      return;
    }
    if (_selectedComune == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un Comune')),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
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
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AncodeService.createAncode(
        code: code,
        type: _isLink ? AncodeType.link : AncodeType.note,
        municipalityId: _selectedComune!.istatCode,
        isExclusiveItaly: _isExclusive,
        url: _isLink ? _urlController.text.trim() : null,
        noteText: !_isLink ? _noteController.text.trim() : null,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ANCODE creato con successo')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
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
