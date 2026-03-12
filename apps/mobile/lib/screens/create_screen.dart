import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared/shared.dart';

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
  bool _isLink = true;
  String _region = 'All';
  bool _isExclusive = false;
  bool _isSubmitting = false;

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

  static const double _radius = 24;
  static const double _greenBorder = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bluUniverso,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'CREA un nuovo ANCODE',
                style: TextStyle(
                  color: AppColors.biancoOttico,
                  fontSize: 22,
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
              const SizedBox(height: 28),
              const Text(
                'INSERISCI IL TUO ANCODE',
                style: TextStyle(
                  color: AppColors.biancoOttico,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _darkField(
                controller: _codeController,
                hint: 'es. CASA20',
                helper: 'max. 30 caratteri, solo lettere maiuscole.',
                isCodeField: true,
              ),
              const SizedBox(height: 24),
              const Text(
                'Content type *',
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
                    ? 'Enter the link you want to connect this ANCODE to'
                    : 'Enter your note text',
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
                'Region of Area',
                style: TextStyle(
                  color: AppColors.biancoOttico,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _darkDropdown(
                value: _region,
                items: const ['All'],
                onChanged: (v) => setState(() => _region = v ?? 'All'),
              ),
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
                        'Make this code exclusive (prevents use in other municipalities)',
                        style: TextStyle(
                          color: AppColors.biancoOttico.withOpacity(0.95),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _generateCodeButton(),
              const SizedBox(height: 100),
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
            inputFormatters: isCodeField ? [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9*]'))] : null,
            textCapitalization: isCodeField ? TextCapitalization.characters : TextCapitalization.none,
            keyboardType: keyboardType,
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

  Widget _darkDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, color: AppColors.bluPolvere),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: AppColors.bluPolvere)))).toList(),
        onChanged: onChanged,
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
                      'Generate Code',
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

  void _onGenerateCode() {
    final code = _codeController.text.replaceAll(RegExp(r'[\s*]'), '').toUpperCase();
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
    setState(() => _isSubmitting = true);
    // TODO: call create API (Supabase) when wired
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Creazione codice in arrivo – connetti l’API')),
        );
      }
    });
  }
}
