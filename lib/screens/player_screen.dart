import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/download.dart';
import '../services/engine.dart';
import '../utils/format_utils.dart';
import '../widgets/thumbnail.dart';

/// Reproductor de videos y audios descargados.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.entry, required this.engine});

  final HistoryEntry entry;
  final Engine engine;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    final uri = Uri.parse(widget.entry.uri);
    _controller = uri.scheme == 'file'
        ? VideoPlayerController.file(File(uri.toFilePath()))
        : VideoPlayerController.contentUri(uri);
    _controller.addListener(_onTick);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.play();
      _scheduleHide();
    }).catchError((Object e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo abrir el archivo. Puede que lo hayan borrado de la galería.');
    });
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (widget.entry.isAudio) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _togglePlay() {
    final value = _controller.value;
    if (value.isPlaying) {
      _controller.pause();
    } else {
      if (value.position >= value.duration) _controller.seekTo(Duration.zero);
      _controller.play();
    }
    _scheduleHide();
  }

  void _seekBy(int seconds) {
    final target = _controller.value.position + Duration(seconds: seconds);
    _controller.seekTo(target < Duration.zero ? Duration.zero : target);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share),
            onPressed: () => widget.engine.share(entry.uri, entry.mime),
          ),
          IconButton(
            tooltip: 'Abrir con otra app',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => widget.engine.openWith(entry.uri, entry.mime),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            )
          : !_ready
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControls,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(child: entry.isAudio ? _audioArt(entry) : _video()),
                      AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(ignoring: !_showControls, child: _controls()),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _video() {
    final ratio = _controller.value.aspectRatio;
    return AspectRatio(aspectRatio: ratio > 0 ? ratio : 9 / 16, child: VideoPlayer(_controller));
  }

  Widget _audioArt(HistoryEntry entry) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 240,
              height: 240,
              child: Thumbnail(network: entry.network, path: entry.thumbnailPath),
            ),
          ),
          const SizedBox(height: 20),
          Text(entry.title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          if (entry.author.isNotEmpty)
            Text(entry.author, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _controls() {
    final value = _controller.value;
    final duration = value.duration;
    final position = value.position > duration ? duration : value.position;
    final max = duration.inMilliseconds.toDouble();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.transparent, Colors.black54],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 40,
                color: Colors.white,
                onPressed: () => _seekBy(-10),
                icon: const Icon(Icons.replay_10),
              ),
              const SizedBox(width: 24),
              IconButton.filled(
                iconSize: 48,
                style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                onPressed: _togglePlay,
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 24),
              IconButton(
                iconSize: 40,
                color: Colors.white,
                onPressed: () => _seekBy(10),
                icon: const Icon(Icons.forward_10),
              ),
            ],
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Text(formatPosition(position), style: const TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: max <= 0 ? 0 : position.inMilliseconds.toDouble().clamp(0, max),
                      max: max <= 0 ? 1 : max,
                      onChanged: max <= 0
                          ? null
                          : (v) {
                              _controller.seekTo(Duration(milliseconds: v.round()));
                              _scheduleHide();
                            },
                    ),
                  ),
                  Text(formatPosition(duration), style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
