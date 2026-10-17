import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../bootstrap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../domain/chat_message.dart';
import '../../domain/conversation.dart';
import '../bloc/thread_bloc.dart';
import '../bloc/thread_event.dart';
import '../bloc/thread_state.dart';

class ThreadPage extends StatelessWidget {
  const ThreadPage({required this.conversation, super.key});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ThreadBloc>(
      create: (_) =>
          getIt<ThreadBloc>(param1: conversation.id)..add(const ThreadOpened()),
      child: ThreadView(conversation: conversation),
    );
  }
}

/// The page body without its own `BlocProvider`, so tests can inject a Bloc.
class ThreadView extends StatefulWidget {
  const ThreadView({required this.conversation, super.key});

  final Conversation conversation;

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final body = _input.text.trim();
    if (body.isEmpty) return;
    context.read<ThreadBloc>().add(ThreadMessageSent(body));
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(widget.conversation.clinicianName, style: AppTextStyles.h2),
      ),
      body: SafeArea(
        child: BlocConsumer<ThreadBloc, ThreadState>(
          listenWhen: (previous, current) =>
              previous.failure != current.failure && current.failure != null,
          listener: (context, state) {
            AppToast.error(context, state.failure!.message);
            // Hand an unsent message back rather than losing it.
            final unsent = state.unsentBody;
            if (unsent != null && _input.text.isEmpty) _input.text = unsent;
          },
          builder: (context, state) {
            return Column(
              children: [
                Expanded(
                  child: state.status == ThreadStatus.loading &&
                          state.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : state.messages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet. Say hello.',
                                style: AppTextStyles.bodyMuted,
                              ),
                            )
                          : ListView.builder(
                              // Newest at the bottom, anchored there.
                              reverse: true,
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: state.messages.length,
                              itemBuilder: (context, index) => _Bubble(
                                message: state.messages[
                                    state.messages.length - 1 - index],
                              ),
                            ),
                ),
                _Composer(controller: _input, onSend: _send),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.teal : AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: AppTextStyles.body.copyWith(
                color: mine ? AppColors.white : AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.isPending
                  ? 'Sending…'
                  : DateFormat('h:mm a').format(message.sentAt),
              style: AppTextStyles.caption.copyWith(
                color: mine ? AppColors.white70 : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Write a message',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          IconButton(
            onPressed: onSend,
            tooltip: 'Send',
            icon: const Icon(Icons.send, color: AppColors.teal),
          ),
        ],
      ),
    );
  }
}
