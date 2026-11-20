import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import 'ui.dart';

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = formatPhone(newValue.text);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class IfTextField extends StatefulWidget {
  const IfTextField({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.placeholder,
    this.prefix,
    this.suffix,
    this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.minLines = 1,
    this.filled = false,
    this.error,
    this.controller,
  });

  /// Message d'erreur affiché sous le champ, à la place de l'aide.
  final String? error;
  final TextEditingController? controller;

  final String? label;
  final String? hint;
  final String? initialValue;
  final String? placeholder;
  final String? prefix;
  final String? suffix;
  final IconData? icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final int minLines;

  /// Zone de texte grise sans bordure (explication libre).
  final bool filled;

  @override
  State<IfTextField> createState() => _IfTextFieldState();
}

class _IfTextFieldState extends State<IfTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final multi = widget.minLines > 1;
    Widget affix(String text, {required bool end}) => Container(
          padding: end ? const EdgeInsets.only(left: 8) : const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            border: Border(left: end ? BorderSide(color: c.line) : BorderSide.none, right: end ? BorderSide.none : BorderSide(color: c.line)),
          ),
          child: Text(text, style: TextStyle(fontSize: 15, fontWeight: end ? FontWeight.w400 : FontWeight.w500, color: end ? c.muted : c.ink)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (widget.label != null) Text(widget.label!, style: const TextStyle(fontWeight: FontWeight.w500)),
        GestureDetector(
          onTap: _focus.requestFocus,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(horizontal: widget.filled ? 14 : 12, vertical: multi ? 12 : 0),
            decoration: BoxDecoration(
              color: widget.filled ? c.fill : c.surface,
              borderRadius: BorderRadius.circular(kRadius),
              border: widget.filled && !_focus.hasFocus ? null : Border.all(color: widget.error != null ? c.danger : (_focus.hasFocus ? c.ink : c.lineStrong), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: multi ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              spacing: 8,
              children: [
                if (widget.icon != null) Icon(widget.icon, color: c.muted),
                if (widget.prefix != null) affix(widget.prefix!, end: false),
                Expanded(
                  child: TextFormField(
                    focusNode: _focus,
                    controller: widget.controller,
                    initialValue: widget.controller == null ? widget.initialValue : null,
                    keyboardType: widget.keyboardType,
                    inputFormatters: widget.inputFormatters,
                    autofillHints: widget.autofillHints,
                    onChanged: widget.onChanged,
                    minLines: widget.minLines,
                    maxLines: multi ? 6 : 1,
                    style: TextStyle(fontSize: widget.filled ? 14 : 15, height: 22 / 15, color: c.ink),
                    decoration: InputDecoration.collapsed(hintText: widget.placeholder, hintStyle: TextStyle(color: c.muted)),
                  ),
                ),
                if (widget.suffix != null) affix(widget.suffix!, end: true),
              ],
            ),
          ),
        ),
        if (widget.error != null)
          Semantics(liveRegion: true, child: Text(widget.error!, style: Ts.small.copyWith(fontWeight: FontWeight.w600, color: c.danger)))
        else if (widget.hint != null)
          Text(widget.hint!, style: Ts.small.copyWith(color: c.muted)),
      ],
    );
  }
}

class PhoneField extends StatelessWidget {
  const PhoneField({super.key, this.label = 'Numéro de téléphone', this.initialValue = '', this.hint, this.onChanged, this.error});
  final String? error;
  final String label;
  final String initialValue;
  final String? hint;

  /// Reçoit les chiffres seuls, sans espaces.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => IfTextField(
        label: label,
        hint: hint,
        error: error,
        prefix: '+229',
        placeholder: '01 97 00 00 00',
        initialValue: formatPhone(initialValue),
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        inputFormatters: [_PhoneFormatter()],
        onChanged: onChanged == null ? null : (v) => onChanged!(v.replaceAll(' ', '')),
      );
}

/// Code à cases. Un seul champ invisible reçoit la saisie : le clavier,
/// le collage et le remplissage automatique du SMS fonctionnent d'un bloc.
class OtpInput extends StatefulWidget {
  const OtpInput({super.key, this.length = 6, this.onChanged, required this.label, this.large = false, this.controller});
  final int length;
  final ValueChanged<String>? onChanged;
  final String label;

  /// Grandes cases grises du code de livraison.
  final bool large;

  /// Pour vider le champ depuis l'écran (code refusé).
  final TextEditingController? controller;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final _controller = widget.controller ?? TextEditingController();
  final _focus = FocusNode();

  void _refresh() => setState(() {});

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final value = _controller.text;
    final large = widget.large;
    return Semantics(
      label: widget.label,
      child: Stack(
        alignment: large ? Alignment.center : Alignment.centerLeft,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: large ? Alignment.center : Alignment.centerLeft,
            child: Row(
              spacing: large ? 10 : 8,
              children: [
                for (var i = 0; i < widget.length; i++)
                  () {
                    final current = _focus.hasFocus && i == value.length;
                    return Container(
                      width: large ? 64 : 48,
                      height: large ? 76 : 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: large && !current ? c.fill : c.surface,
                        borderRadius: BorderRadius.circular(kRadius),
                        border: large && !current
                            ? null
                            : Border.all(color: current ? c.ink : c.lineStrong, width: 1.5),
                      ),
                      child: Text(i < value.length ? value[i] : '', style: Ts.num(large ? 32 : 26)),
                    );
                  }(),
              ],
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(widget.length)],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(border: InputBorder.none),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IfCheckbox extends StatelessWidget {
  const IfCheckbox({super.key, required this.label, this.description, required this.value, required this.onChanged});
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      checked: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? c.primary : c.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: value ? c.onPrimary : c.lineStrong, width: 1.5),
                ),
                child: value ? Icon(LucideIcons.check, size: 16, color: c.onPrimary) : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 15, height: 22 / 15)),
                    if (description != null) Text(description!, style: Ts.small.copyWith(color: c.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.label, required this.value, required this.onChanged, this.min = 1, this.max = 999});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget button(IconData icon, String name, int next) {
      final enabled = next >= min && next <= max;
      return Box(
        width: 40,
        height: 40,
        radius: kRadius,
        color: c.surface,
        border: BorderSide(color: enabled ? c.lineStrong : c.line, width: 1.5),
        label: name,
        onTap: enabled ? () => onChanged(next) : null,
        child: Icon(icon, color: enabled ? c.ink : c.muted.withValues(alpha: .5)),
      );
    }

    return Row(
      spacing: 16,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        Row(
          spacing: 8,
          children: [
            button(LucideIcons.minus, 'Diminuer', value - 1),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 56),
              child: Semantics(liveRegion: true, child: Text('$value', textAlign: TextAlign.center, style: Ts.h2)),
            ),
            button(LucideIcons.plus, 'Augmenter', value + 1),
          ],
        ),
      ],
    );
  }
}


class PaymentMethodPicker extends StatelessWidget {
  const PaymentMethodPicker({super.key, required this.value, required this.onChanged, required this.phone});
  final String value;
  final ValueChanged<String> onChanged;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('Payer avec', style: TextStyle(fontWeight: FontWeight.w500))),
        for (final MapEntry(key: id, value: name) in mobileMoney.entries)
          Box(
            radius: kRadius,
            color: value == id ? c.primarySoft : c.surface,
            border: BorderSide(color: value == id ? c.ink : c.lineStrong, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            selected: value == id,
            onTap: () => onChanged(id),
            child: Row(
              spacing: 12,
              children: [
                // shortcut: initiale à la place du logo, à remplacer quand l'agrégateur de paiement fournit les logos officiels.
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.fillSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.line)),
                  child: Text(name[0], style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w500)),
                      Text('+229 ${formatPhone(phone)}', style: Ts.small.copyWith(color: c.muted)),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value == id ? c.primary : c.surface,
                    border: Border.all(color: value == id ? c.onPrimary : c.lineStrong, width: 1.5),
                  ),
                  child: value == id ? Container(width: 8, height: 8, decoration: BoxDecoration(color: c.onPrimary, shape: BoxShape.circle)) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Note de 1 à 5 étoiles.
class RatingInput extends StatelessWidget {
  const RatingInput({super.key, required this.value, required this.onChanged, required this.label, this.size = 36});
  final int value;
  final ValueChanged<int> onChanged;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          for (var i = 1; i <= 5; i++)
            Semantics(
              label: '$i ${i > 1 ? 'étoiles' : 'étoile'}',
              button: true,
              selected: value == i,
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  // Étoile pleine jaune cernée d'encre : le jaune seul ne contraste pas assez sur blanc.
                  child: Stack(
                    children: [
                      if (i <= value) Icon(Icons.star_rounded, size: size + 4, color: c.primary),
                      Icon(Icons.star_outline_rounded, size: size + 4, color: i <= value ? c.ink : c.lineStrong),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatInput extends StatefulWidget {
  const ChatInput({super.key, required this.onSend, this.onAttach});
  final ValueChanged<String> onSend;
  final VoidCallback? onAttach;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    setState(_controller.clear);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final empty = _controller.text.trim().isEmpty;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: BorderSide(color: c.lineStrong, width: 1.5));
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: Row(
        spacing: 4,
        children: [
          if (widget.onAttach != null) IconBtn(LucideIcons.camera, label: 'Joindre une photo', tone: IbTone.ghost, size: 44, onTap: widget.onAttach),
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _controller,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                style: TextStyle(fontSize: 15, color: c.ink),
                decoration: InputDecoration(
                  hintText: 'Écrire un message',
                  hintStyle: TextStyle(color: c.muted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  enabledBorder: border,
                  focusedBorder: border.copyWith(borderSide: BorderSide(color: c.ink, width: 1.5)),
                ),
              ),
            ),
          ),
          Box(
            width: 44,
            height: 44,
            radius: kRadius,
            color: empty ? c.fillSoft : c.primary,
            label: 'Envoyer',
            onTap: empty ? null : _send,
            child: Icon(LucideIcons.send, color: empty ? c.muted : c.onPrimary),
          ),
        ],
      ),
    );
  }
}

// ───────────── Vérification des champs ─────────────

String? requiredError(String value, String message) => value.trim().isEmpty ? message : null;

/// Un numéro béninois compte 10 chiffres et commence par 01.
String? phoneError(String digits) {
  if (digits.isEmpty) return 'Indique un numéro de téléphone.';
  if (digits.length != 10) return 'Le numéro doit compter 10 chiffres.';
  if (!digits.startsWith('01')) return 'Un numéro béninois commence par 01.';
  return null;
}

/// L'e-mail est facultatif : seule une adresse mal formée est signalée.
String? emailError(String value) {
  final v = value.trim();
  if (v.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return null;
  return 'Cette adresse e-mail n’est pas valide.';
}
