import 'package:flutter/material.dart'
    show BuildContext, Navigator, MaterialPageRoute, Colors;

import 'package:lunofono_bundle/lunofono_bundle.dart'
    show Playable, MultiMedium, SingleMedium, Audio, Image, Video, Color;

import 'dynamic_dispatch_registry.dart' show DynamicDispatchRegistry;
import 'media_player.dart' show MediaPlayer;

/// Register all builtin types
///
/// When new builtin types are added, they should be registered by this
/// function, which is used by [PlayablePlayerRegistry.builtin()].
void _registerBuiltin(PlayablePlayerRegistry registry) {
  // New actions should be registered here
  MultiMediumPlayer singleMediumPlayer(Playable playable) =>
      MultiMediumPlayer(MultiMedium.fromSingleMedium(playable as SingleMedium));
  registry.register(Audio, (playable) => singleMediumPlayer(playable));
  registry.register(Image, (playable) => singleMediumPlayer(playable));
  registry.register(Video, (playable) => singleMediumPlayer(playable));
  registry.register(
      MultiMedium, (playable) => MultiMediumPlayer(playable as MultiMedium));
}

/// A wrapper to manage how a [Playable] is played by the player.
///
/// This class also manages a registry of implementations for the different
/// concrete types of [Playable]. To get a playable wrapper, [PlayablePlayer.wrap()]
/// should be used.
abstract class PlayablePlayer {
  /// The [PlayablePlayerRegistry] used to dispatch the calls.
  static var registry = PlayablePlayerRegistry.builtin();

  /// Dispatches the call dynamically by using the [registry].
  ///
  /// The dispatch is done based on this [runtimeType], so only concrete leaf
  /// types can be dispatched. It asserts if a type is not registered.
  static PlayablePlayer wrap(Playable playable) {
    final wrap = registry.getFunction(playable);
    assert(wrap != null,
        'Unimplemented PlayablePlayer for ${playable.runtimeType}');
    return wrap(playable);
  }

  /// The underlaying model's [Playable].
  Playable get playable;

  /// Plays this [Playable] with an optional [backgroundColor].
  void play(BuildContext context, [Color backgroundColor]);
}

class MultiMediumPlayer extends PlayablePlayer {
  /// The underlaying model's [SingleMedium].
  @override
  final MultiMedium playable;

  /// Constructs a [SingleMediumPlayer] using [playable] as the underlaying
  /// [Playable].
  MultiMediumPlayer(this.playable) : assert(playable != null);

  /// Plays a [SingleMedium] by pushing a new page with a [MediaPlayer].
  ///
  /// If [backgroundColor] is provided and non-null, it will be used as the
  /// [MediaPlayer.backgroundColor]. Otherwise, [Colors.black] will be used.
  @override
  void play(BuildContext context, [Color backgroundColor]) {
    Navigator.push<MediaPlayer>(
      context,
      MaterialPageRoute<MediaPlayer>(
        builder: (BuildContext context) => MediaPlayer(
          multimedium: playable,
          backgroundColor: backgroundColor ?? Colors.black,
          onMediaStopped: (context) => Navigator.pop(context),
        ),
      ),
    );
  }
}

// From here, it's just boilerplate and it shouldn't be changed unless the
// architecture changes.

/// A function type to play a [Playable].
typedef WrapFunction = PlayablePlayer Function(Playable playable);

/// A registry to map from [Playable] types [PlayFunction].
class PlayablePlayerRegistry
    extends DynamicDispatchRegistry<Playable, WrapFunction> {
  /// Constructs an empty registry.
  PlayablePlayerRegistry();

  /// Constructs a registry with builtin types registered.
  PlayablePlayerRegistry.builtin() {
    _registerBuiltin(this);
  }
}
