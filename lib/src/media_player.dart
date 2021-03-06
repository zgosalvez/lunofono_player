import 'package:flutter/material.dart';

import 'package:provider/provider.dart' show ChangeNotifierProvider, Consumer;

import 'package:lunofono_bundle/lunofono_bundle.dart' show MultiMedium;

import 'media_player/controller_registry.dart' show ControllerRegistry;
import 'media_player/multi_medium_controller.dart' show MultiMediumController;
import 'media_player/multi_medium_player.dart' show MultiMediumPlayer;

/// A media player widget.
///
/// The player can play a [MultiMedium] via [SingleMediumController] plug-ins
/// that are obtained via the [ControllerRegistry]. It handles the playing and
/// synchronization of the [multimedium.mainTrack] and
/// [multimedium.backgroundTrack] and also the asynchronous nature of the player
/// controllers, by showing a progress indicator while the media is loading, and
/// the media afterwards, or a [MediaPlayerError] if an error occurred.
///
/// If a medium is played for which there is no [SingleMediumController]
/// registered in the [ControllerRegistry], a [MediaPlayerError] will be shown
/// instead of that medium.
///
/// All the orchestration behind the scenes is performed by
/// a [MultiMediumController] that is provided via a [ChangeNotifierProvider].
class MediaPlayer extends StatelessWidget {
  /// The medium to play by this player.
  final MultiMedium multimedium;

  /// The background color for this player.
  final Color backgroundColor;

  /// The action to perform when this player stops.
  final void Function(BuildContext) onMediaStopped;

  /// The [ControllerRegistry] to create [SingleMediumController]s.
  final ControllerRegistry registry;

  /// Constructs a new [MediaPlayer].
  ///
  /// The player will play the [multimedium] with a background color
  /// [backgroundColor] (or black if null is used). When the media stops
  /// playing, either because it was played completely or because it was stopped
  /// by the user, the [onMediaStopped] callback will be called (if non-null).
  ///
  /// If a [registry] is provided, then it is used to create the controller for
  /// the media inside the [multimedium]. Otherwise
  /// [ControllerRegistry.instance] is used.
  const MediaPlayer({
    @required this.multimedium,
    Color backgroundColor,
    this.onMediaStopped,
    this.registry,
    Key key,
  })  : assert(multimedium != null),
        backgroundColor = backgroundColor ?? Colors.black,
        super(key: key);

  /// Builds the UI for this widget.
  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<MultiMediumController>(
        create: (context) => MultiMediumController(
          multimedium,
          registry ?? ControllerRegistry.instance,
          onMediumFinished: onMediaStopped,
        )..initialize(context),
        child: Consumer<MultiMediumController>(
            child: Material(
              elevation: 0,
              color: backgroundColor,
              child: Center(
                child: MultiMediumPlayer(),
              ),
            ),
            builder: (context, model, child) {
              return GestureDetector(
                onTap: () {
                  // XXX: For now the stop reaction is hardcoded to the tap.
                  // Also we should handle errors in the pause()'s future
                  model.mainTrackController.pauseCurrent(context);
                  model.backgroundTrackController.pauseCurrent(context);
                  onMediaStopped?.call(context);
                },
                child: child,
              );
            }),
      );
}
