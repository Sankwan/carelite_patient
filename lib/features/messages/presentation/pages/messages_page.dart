import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../home/presentation/widgets/avatar_circle.dart';
import '../../domain/conversation.dart';
import '../../domain/open_conversation.dart';
import '../bloc/conversations_bloc.dart';
import '../bloc/conversations_event.dart';
import '../bloc/conversations_state.dart';
import '../bloc/messages_badge_bloc.dart';
import '../bloc/messages_badge_event.dart';
import 'thread_page.dart';

/// The patient's conversations with their clinicians.
///
/// A conversation exists once the patient and clinician share an
/// appointment and one of them starts it. Today only the clinician can
/// start one: the clinician list does not expose the user id the server
/// needs (PT-C10 in docs/BACKEND_REQUESTS_PATIENT.md).
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Messages', style: AppTextStyles.h1),
      ),
      body: SafeArea(
        child: BlocConsumer<ConversationsBloc, ConversationsState>(
          listenWhen: (previous, current) =>
              previous.failure != current.failure && current.failure != null,
          listener: (context, state) =>
              AppToast.error(context, state.failure!.message),
          builder: (context, state) {
            if (state.status == ConversationsStatus.loading &&
                state.conversations.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            final bloc = context.read<ConversationsBloc>();
            return RefreshIndicator(
              onRefresh: () async => bloc.add(const ConversationsRefreshed()),
              child: state.conversations.isEmpty
                  ? const _Empty()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: state.conversations.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) => _ConversationTile(
                        conversation: state.conversations[index],
                        onTap: () => _open(context, state.conversations[index]),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Conversation conversation) async {
    final bloc = context.read<ConversationsBloc>();
    final open = getIt<OpenConversation>()..id = conversation.id;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ThreadPage(conversation: conversation),
      ),
    );
    open.id = null;
    // Unread counts and the last-message preview changed while it was open.
    bloc.add(const ConversationsRefreshed());
    getIt<MessagesBadgeBloc>().add(const MessagesBadgeRefreshed());
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = conversation.lastMessage;
    final unread = conversation.hasUnread;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              AvatarCircle(name: conversation.clinicianName),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.clinicianName,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview == null
                          ? 'No messages yet'
                          : '${conversation.lastMessageIsMine ? 'You: ' : ''}$preview',
                      style: unread
                          ? AppTextStyles.body.copyWith(color: AppColors.ink)
                          : AppTextStyles.bodyMuted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (conversation.lastMessageAt != null)
                    Text(
                      _timeLabel(conversation.lastMessageAt!),
                      style: AppTextStyles.caption,
                    ),
                  if (unread) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      ),
                      child: Text(
                        '${conversation.unreadCount}',
                        semanticsLabel: '${conversation.unreadCount} unread',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeLabel(DateTime time) {
    final now = DateTime.now();
    final sameDay =
        time.year == now.year && time.month == now.month && time.day == now.day;
    return sameDay ? DateFormat('h:mm a').format(time) : DateFormat('d MMM').format(time);
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: const [
        SizedBox(height: AppSpacing.xxl),
        Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.muted),
        SizedBox(height: AppSpacing.md),
        Text(
          'No messages yet',
          textAlign: TextAlign.center,
          style: AppTextStyles.h2,
        ),
        SizedBox(height: AppSpacing.sm),
        Text(
          'After an appointment, your clinician can message you here, and you '
          'can reply.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMuted,
        ),
      ],
    );
  }
}
