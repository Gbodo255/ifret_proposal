import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/store.dart';
import '../routes.dart';
import '../services/device.dart';
import '../theme/tokens.dart';
import '../widgets/brand.dart';
import '../widgets/extras.dart';
import '../widgets/forms.dart';
import '../widgets/ui.dart';

/// Conversations d'un rôle, filtrées par la recherche, en cours d'abord.
class ConversationList extends StatelessWidget {
  const ConversationList(this.role, {super.key, this.query = ''});
  final Role role;
  final String query;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final all = context.store.conversations.where((c) => c.role == role && (q.isEmpty || '${c.name} ${c.subtitle} ${c.last?.text}'.toLowerCase().contains(q))).toList();
    if (all.isEmpty) return EmptyCard(LucideIcons.messageCircle, 'Aucune conversation', q.isEmpty ? 'Tes échanges apparaîtront ici.' : 'Rien ne correspond à « $query ».');
    Widget group(String label, List<Conversation> items) => Labeled(
          label,
          child: Grp([
            for (final c in items)
              SetRow(
                leading: Avatar(c.name, verified: c.verified),
                title: c.name,
                subtitle: c.subtitle,
                subtitle2: c.typing ? 'En train d’écrire…' : c.last?.text,
                roomy: true,
                trailing: TimeDot(c.last?.time ?? '', count: c.unread > 0 ? c.unread : null),
                onTap: () => context.go(R.chat, args: c.id),
              ),
          ]),
        );
    final active = all.where((c) => c.active).toList(), others = all.where((c) => !c.active).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        if (active.isNotEmpty) group(role == Role.chargeur ? 'Course en cours' : 'Mission en cours', active),
        if (others.isNotEmpty) group('Autres conversations', others),
      ],
    );
  }
}

/// Conversation : messages, réponses rapides, photo jointe, appel.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, this.conversationId});
  final String? conversationId;

  static const _quick = ['Tu es où ?', 'D’accord, merci', 'Appelle-moi'];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = context.store;
    final chat = store.conversation(conversationId);
    // Ouvrir la conversation la marque comme lue, une fois l'écran dessiné.
    if (chat.unread > 0) WidgetsBinding.instance.addPostFrameCallback((_) => store.read(chat));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMax),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                  child: Row(
                    spacing: 10,
                    children: [
                      IconBtn(LucideIcons.arrowLeft, label: 'Retour', onTap: () => Navigator.maybePop(context)),
                      Avatar(chat.name, size: 32, verified: chat.verified),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(chat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.b),
                            Lab(chat.typing ? 'En train d’écrire…' : chat.subtitle, maxLines: 1),
                          ],
                        ),
                      ),
                      IconBtn(LucideIcons.phone, label: 'Appeler ${chat.name}', tone: IbTone.outline, onTap: () => callNumber(context, chat.phone)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 10,
                      children: [
                        for (final line in chat.lines)
                          if (line.me == null)
                            Sys(line.text)
                          else if (line.photo != null)
                            _PhotoBubble(line)
                          else
                            Msg(line.text, line.time, me: line.me!),
                        if (chat.typing) const Align(alignment: Alignment.centerLeft, child: _Typing()),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [for (final text in _quick) Tag(text, tone: Tone.outline, height: 32, onTap: () => store.send(chat, text))],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ChatInput(
                  onSend: (text) => store.send(chat, text),
                  onAttach: () async {
                    final path = await pickPhoto(context);
                    if (path != null) store.send(chat, 'Photo', photo: path);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoBubble extends StatelessWidget {
  const _PhotoBubble(this.line);
  final ChatLine line;

  @override
  Widget build(BuildContext context) => Align(
        alignment: line.me! ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 2,
          children: [
            Container(
              width: 180,
              height: 180,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: context.c.fill, borderRadius: BorderRadius.circular(kRadius)),
              child: photoImage(line.photo!),
            ),
            Lab(line.time),
          ],
        ),
      );
}

/// Trois points qui battent pendant que l'autre personne écrit.
class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'En train d’écrire',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: context.c.fill, borderRadius: BorderRadius.circular(kRadius)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              for (var i = 0; i < 3; i++)
                Loop(
                  duration: const Duration(milliseconds: 1000),
                  phase: i * .18,
                  builder: (context, t, child) => Opacity(opacity: .3 + .7 * (1 - (2 * t - 1).abs()), child: child),
                  child: Container(width: 7, height: 7, decoration: BoxDecoration(color: context.c.muted, shape: BoxShape.circle)),
                ),
            ],
          ),
        ),
      );
}
