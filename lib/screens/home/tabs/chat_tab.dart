import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/components/components.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/services/services.dart';

class ChatTab extends StatefulWidget {
  final FocusNode? focusNode;
  const ChatTab({super.key, this.focusNode});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  static const int _maxImages = 5;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatProvider _chatProvider;

  /// Compressed JPEG bytes for images picked but not yet sent. Cleared after
  /// a successful dispatch in `_handleSend`.
  final List<Uint8List> _pendingImages = [];

  bool _isRecording = false;
  final AudioRecordingService _audioService = AudioRecordingService();

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    _chatProvider.addListener(_onChatProviderUpdate);
    _controller.addListener(_onTextChanged);
    _audioService.onAutoStopped(_handleAutoStopped);
  }

  @override
  void dispose() {
    _chatProvider.removeListener(_onChatProviderUpdate);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _audioService.cancel();
    super.dispose();
  }

  void _onChatProviderUpdate() {
    if (!mounted) return;
    final provider = context.read<ChatProvider>();
    if (provider.isStreaming) {
      _scrollToBottomIfNearBottom();
    }
  }

  /// Keep the send button reactive to typing — enabled state depends on
  /// `_controller.text` and `_pendingImages`.
  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _scrollToBottomIfNearBottom() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final isNearBottom = position.pixels >= position.maxScrollExtent - 100;
      if (isNearBottom) {
        _scrollToBottom();
      }
    }
  }

  void _onPromptTap(ChatProvider provider, int index) {
    _controller.text = provider.suggestedPrompts[index].prompt;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    provider.selectPrompt(index);
    FocusScope.of(context).requestFocus(widget.focusNode);
  }

  void _onActionTap(ChatProvider provider, int index) {
    final action = provider.suggestedPrompts[provider.activePromptIndex!].actions[index];
    _controller.text = '${_controller.text} $action';
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    provider.selectAction();
  }

  Future<void> _showAttachmentSheet() async {
    if (_pendingImages.length >= _maxImages) {
      _showSnackBar('Maximum 5 images per message');
      return;
    }
    final l10n = context.read<LocaleProvider>();
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.translate('take_photo')),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.translate('choose_from_library')),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    if (_pendingImages.length >= _maxImages) return;
    final file = await ImagePickerService().pickFromCamera();
    if (!mounted || file == null) return;
    await _processAndAdd([file]);
  }

  Future<void> _pickFromGallery() async {
    final remaining = _maxImages - _pendingImages.length;
    if (remaining <= 0) return;
    final files = await ImagePickerService().pickFromGallery(maxCount: remaining);
    if (!mounted || files.isEmpty) return;
    await _processAndAdd(files);
  }

  Future<void> _processAndAdd(List<XFile> files) async {
    // Cap defensively — service already trims, but camera path sends 1 too.
    final remaining = _maxImages - _pendingImages.length;
    final toProcess = files.take(remaining).toList();

    int oversizeCount = 0;
    int failCount = 0;
    final results = await Future.wait(
      toProcess.map((f) async {
        try {
          return await ImageProcessingService().processPickedImage(f);
        } on OversizeImageException {
          oversizeCount++;
          return null;
        } catch (_) {
          failCount++;
          return null;
        }
      }),
    );

    if (!mounted) return;
    final l10n = context.read<LocaleProvider>();
    final valid = results.whereType<Uint8List>().toList();
    if (valid.isNotEmpty) {
      setState(() => _pendingImages.addAll(valid));
    }
    if (oversizeCount > 0) {
      _showSnackBar('Image too large after compression');
    }
    if (failCount > 0) {
      _showSnackBar(l10n.translate('image_load_failed'));
    }
    if (files.length > toProcess.length) {
      _showSnackBar('Maximum 5 images per message');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    final images = List<Uint8List>.of(_pendingImages);
    if (text.isEmpty && images.isEmpty) return;

    _controller.clear();
    setState(() => _pendingImages.clear());

    try {
      FocusManager.instance.primaryFocus?.unfocus();
      await context.read<ChatProvider>().sendMessage(
            text,
            imageBytes: images.isEmpty ? null : images,
          );
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _onMicTap() async {
    if (_isRecording) return;

    if (!await _audioService.hasPermission()) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Microphone Access Required'),
          content: const Text(
            'Microphone permission is disabled. Please enable it in Settings to record voice notes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return;
    }

    await _audioService.start();
    if (mounted) setState(() => _isRecording = true);
  }

  Future<void> _stopAndSend() async {
    final provider = context.read<ChatProvider>();
    final bytes = await _audioService.stop();
    if (mounted) setState(() => _isRecording = false);
    if (bytes != null && bytes.isNotEmpty) {
      await provider.sendMessage('', audioBytes: bytes);
    }
  }

  Future<void> _cancelRecording() async {
    await _audioService.cancel();
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _handleAutoStopped(Uint8List? bytes) async {
    final provider = context.read<ChatProvider>();
    if (mounted) setState(() => _isRecording = false);
    if (bytes != null && bytes.isNotEmpty) {
      await provider.sendMessage('', audioBytes: bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleProvider>();
    return Column(
      children: [
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (context, provider, child) {
              final messages = provider.messages;
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return ChatBubble(message: message);
                },
              );
            },
          ),
        ),
        Consumer<ChatProvider>(
          builder: (context, provider, _) {
            if (provider.suggestedPrompts.isEmpty) return const SizedBox.shrink();
            return SuggestedPromptsBar(
              prompts: provider.suggestedPrompts,
              activePromptIndex: provider.activePromptIndex,
              showingActions: provider.showingActions,
              onPromptTap: (index) => _onPromptTap(provider, index),
              onActionTap: (index) => _onActionTap(provider, index),
            );
          },
        ),
        if (_pendingImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ImagePreviewStrip(
              images: _pendingImages,
              onRemove: (i) => setState(() => _pendingImages.removeAt(i)),
              hintLabel: l10n.translate('max_images_hint').replaceAll('{count}', '$_maxImages'),
            ),
          ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildInputArea() {
    final isStreaming = context.watch<ChatProvider>().isStreaming;
    final l10n = context.watch<LocaleProvider>();
    final canSend = !isStreaming && (_controller.text.trim().isNotEmpty || _pendingImages.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isRecording
            ? _RecordingBar(
                key: const ValueKey('recording'),
                elapsedStream: _audioService.elapsedStream,
                amplitudeStream: _audioService.amplitudeStream,
                onCancel: _cancelRecording,
                onStop: _stopAndSend,
              )
            : _buildComposer(isStreaming, canSend, l10n),
      ),
    );
  }

  Widget _buildComposer(bool isStreaming, bool canSend, LocaleProvider l10n) {
    return Row(
      key: const ValueKey('composer'),
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(left: 16.0),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(24.0)),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: widget.focusNode,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: l10n.translate('chat_hint'),
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => canSend ? _handleSend() : null,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_photo_alternate_outlined, color: (isStreaming || _isRecording) ? Colors.grey : Theme.of(context).colorScheme.primary, size: 22),
                  onPressed: (isStreaming || _isRecording) ? null : _showAttachmentSheet,
                  tooltip: 'Attach image',
                  splashRadius: 20,
                ),
                Semantics(
                  label: 'Record voice message',
                  child: IconButton(
                    icon: Icon(
                      Icons.mic_none_outlined,
                      color: (isStreaming || _isRecording) ? Colors.grey : Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                    onPressed: (isStreaming || _isRecording) ? null : _onMicTap,
                    tooltip: 'Record voice message',
                    splashRadius: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _SendButton(onTap: canSend ? _handleSend : null),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: enabled ? Theme.of(context).colorScheme.primary : Colors.grey,
          shape: BoxShape.circle,
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  final Stream<Duration> elapsedStream;
  final Stream<double> amplitudeStream;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  const _RecordingBar({
    super.key,
    required this.elapsedStream,
    required this.amplitudeStream,
    required this.onCancel,
    required this.onStop,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onCancel,
            tooltip: 'Cancel recording',
            color: Colors.grey[600],
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StreamBuilder<double>(
                  stream: amplitudeStream,
                  initialData: 0.0,
                  builder: (context, snapshot) {
                    final amplitude = snapshot.data ?? 0.0;
                    return Transform.scale(
                      scale: 0.9 + amplitude * 0.3,
                      child: Icon(
                        Icons.mic,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                StreamBuilder<Duration>(
                  stream: elapsedStream,
                  initialData: Duration.zero,
                  builder: (context, snapshot) {
                    final elapsed = snapshot.data ?? Duration.zero;
                    return Text(
                      _formatDuration(elapsed),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _SendButton(onTap: onStop),
        ],
      ),
    );
  }
}
