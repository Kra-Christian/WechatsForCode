import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:audioplayers/audioplayers.dart';
import '../config/theme.dart';
import '../models/message_model.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final bool showTime;
  final VoidCallback? onLongPress;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.showTime = true,
    this.onLongPress,
  }) : super(key: key);

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.onPlayerStateChanged.listen((state) {
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _player.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment:
                widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              _buildMessageContent(context),
              if (widget.showTime) const SizedBox(height: 2),
              if (widget.showTime) _buildTimeAndStatus(),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(
          begin: widget.isMe ? 0.3 : -0.3,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOutQuad,
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: widget.isMe ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight: widget.isMe ? const Radius.circular(4) : const Radius.circular(16),
    );

    final backgroundColor = widget.isMe
        ? AppTheme.sentMessageColor
        : AppTheme.receivedMessageColor;

    final textColor = widget.isMe
        ? AppTheme.sentMessageTextColor
        : AppTheme.receivedMessageTextColor;

    switch (widget.message.type) {
      case MessageType.image:
        return ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            color: backgroundColor.withOpacity(0.2),
            child: CachedNetworkImage(
              imageUrl: widget.message.content,
              placeholder: (context, url) => Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey.shade200,
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(height: 8),
                    const Text('Erreur de chargement',
                        style: TextStyle(color: Colors.red)),
                    const SizedBox(height: 4),
                    Text(
                      url.length > 30 ? '${url.substring(0, 30)}...' : url,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              fit: BoxFit.cover,
            ),
          ),
        ).animate().shimmer(delay: 200.ms, duration: 600.ms);

      case MessageType.emoji:
        return Text(
          widget.message.content,
          style: const TextStyle(fontSize: 35),
        );

      case MessageType.audio:
        return _buildAudioMessage(borderRadius, backgroundColor);

      case MessageType.text:
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            widget.message.content,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
            ),
          ),
        );
    }
  }

  Widget _buildAudioMessage(BorderRadius borderRadius, Color backgroundColor) {
    final maxMs = _duration.inMilliseconds.toDouble();
    final currentMs = min(_position.inMilliseconds.toDouble(), maxMs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
            iconSize: 32,
            color: widget.isMe ? Colors.white : Colors.black,
            onPressed: _toggleAudio,
          ),
          SizedBox(
            width: 150,
            child: Slider(
              min: 0,
              max: maxMs > 0 ? maxMs : 1,
              value: currentMs,
              onChanged: (value) {
                _player.seek(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
          Text(
            _formatDuration(_position),
            style: TextStyle(
              color: widget.isMe ? Colors.white : Colors.black,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.message.content));
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildTimeAndStatus() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeago.format(widget.message.timestamp, locale: 'fr_short'),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          if (widget.isMe) ...[
            const SizedBox(width: 4),
            Icon(
              widget.message.isRead ? Icons.done_all : Icons.done,
              size: 14,
              color:
                  widget.message.isRead ? Colors.blue : Colors.grey.shade600,
            ),
          ],
        ],
      ),
    );
  }
}
