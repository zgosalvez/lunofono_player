@Tags(['unit', 'player'])

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart' show Fake;

import 'package:lunofono_bundle/lunofono_bundle.dart';
import 'package:lunofono_player/src/media_player/controller_registry.dart'
    show ControllerRegistry;
import 'package:lunofono_player/src/media_player/single_medium_controller.dart'
    show SingleMediumController, Size;

import 'package:lunofono_player/src/media_player/multi_medium_controller.dart'
    show MultiMediumController;

// XXX: This test should ideally fake the ControllerRegistry, but we can't do so
// now because of a very obscure problem with the dart compiler/flutter test
// driver. For details please see this issue:
// https://github.com/flutter/flutter/issues/65324
void main() {
  group('MultiMediumController', () {
    final registry = ControllerRegistry();
    _registerControllers(registry);

    final audibleMedium =
        _FakeAudibleSingleMedium('audible', size: Size(0.0, 0.0));
    final audibleMedium2 =
        _FakeAudibleSingleMedium('visualizable', size: Size(10.0, 12.0));

    final audibleMultiMedium = MultiMedium(
        AudibleMultiMediumTrack(<Audible>[audibleMedium, audibleMedium2]));

    final multiMedium = MultiMedium(
      AudibleMultiMediumTrack(<Audible>[audibleMedium, audibleMedium2]),
      backgroundTrack: _FakeVisualizableBackgroundMultiMediumTrack(
        <Visualizable>[
          _FakeVisualizableSingleMedium('visualizable1', size: Size(1.0, 1.0)),
          _FakeVisualizableSingleMedium('visualizable2', size: Size(2.0, 2.0)),
        ],
      ),
    );

    group('constructor', () {
      group('asserts on', () {
        test('null multimedium', () {
          expect(() => MultiMediumController(null, registry),
              throwsAssertionError);
        });
        test('null registry', () {
          expect(() => MultiMediumController(audibleMultiMedium, null),
              throwsAssertionError);
        });
      });
    });

    test('play cycle works with main track only', () async {
      var finished = false;
      final controller = MultiMediumController(audibleMultiMedium, registry,
          onMediumFinished: (context) => finished = true);
      expect(finished, isFalse);
      expect(controller.allInitialized, isFalse);
      expect(controller.backgroundTrackController, isEmpty);
      controller.mainTrackController.mediaState
          .forEach((s) => expect(s.controller.asFake.calls, isEmpty));

      var notifyCalled = false;
      final checkInitialized = () {
        expect(finished, isFalse);
        expect(controller.allInitialized, isTrue);
        expect(controller.backgroundTrackController, isEmpty);
        expect(controller.mainTrackController.current.controller.asFake.calls,
            ['initialize', 'play']);
        expect(controller.mainTrackController.last.controller.asFake.calls,
            ['initialize']);
        notifyCalled = true;
      };
      controller.addListener(checkInitialized);

      await controller.initialize(_FakeContext());
      expect(notifyCalled, isTrue);
      final first = controller.mainTrackController.current;

      controller.removeListener(checkInitialized);
      notifyCalled = false;
      final updateNotifyCalled = () => notifyCalled = true;
      controller.addListener(updateNotifyCalled);

      // First medium finishes
      controller.mainTrackController.current.controller
          .onMediumFinished(_FakeContext());
      expect(notifyCalled, isFalse);

      controller.removeListener(updateNotifyCalled);

      // Second (and last) medium finishes, onMediumFinished should be called.
      controller.mainTrackController.current.controller
          .onMediumFinished(_FakeContext());
      expect(notifyCalled, isFalse);
      expect(finished, isTrue);
      expect(controller.allInitialized, isTrue);
      expect(controller.backgroundTrackController, isEmpty);
      expect(controller.mainTrackController.current, isNull);
      expect(first.controller.asFake.calls, ['initialize', 'play']);
      expect(controller.mainTrackController.last.controller.asFake.calls,
          ['initialize', 'play']);

      await controller.dispose();
      expect(first.controller.asFake.calls, ['initialize', 'play', 'dispose']);
      expect(controller.mainTrackController.last.controller.asFake.calls,
          ['initialize', 'play', 'dispose']);
    });

    group('play cycle works with main and background track', () {
      bool finished;
      int notifyCalls;

      setUp(() {
        finished = false;
        notifyCalls = 0;
      });

      void updateNotifyCalled() => notifyCalls++;

      Future<MultiMediumController> testInitialize() async {
        final controller = MultiMediumController(multiMedium, registry,
            onMediumFinished: (context) => finished = true);
        expect(finished, isFalse);
        expect(controller.allInitialized, isFalse);
        expect(controller.backgroundTrackController, isNotEmpty);
        controller.mainTrackController.mediaState
            .forEach((s) => expect(s.controller.asFake.calls, isEmpty));
        controller.backgroundTrackController.mediaState
            .forEach((s) => expect(s.controller.asFake.calls, isEmpty));

        var notifyCalled = false;
        final checkInitialized = () {
          expect(finished, isFalse);
          expect(controller.allInitialized, isTrue);
          expect(controller.backgroundTrackController, isNotEmpty);
          expect(controller.mainTrackController.current.controller.asFake.calls,
              ['initialize', 'play']);
          expect(controller.mainTrackController.last.controller.asFake.calls,
              ['initialize']);
          expect(
              controller
                  .backgroundTrackController.current.controller.asFake.calls,
              ['initialize', 'play']);
          expect(
              controller.backgroundTrackController.last.controller.asFake.calls,
              ['initialize']);
          notifyCalled = true;
        };
        controller.addListener(checkInitialized);

        await controller.initialize(_FakeContext());
        expect(notifyCalled, isTrue);

        controller.removeListener(checkInitialized);
        return controller;
      }

      void testFirstMediaPlayed(MultiMediumController controller) async {
        final firstMain = controller.mainTrackController.current;
        final firstBack = controller.backgroundTrackController.current;

        // First main medium finishes
        controller.mainTrackController.current.controller
            .onMediumFinished(_FakeContext());
        expect(notifyCalls, 0);
        expect(controller.mainTrackController.current,
            same(controller.mainTrackController.last));
        expect(firstMain.controller.asFake.calls, ['initialize', 'play']);
        expect(controller.mainTrackController.last.controller.asFake.calls,
            ['initialize', 'play']);
        expect(controller.backgroundTrackController.current, same(firstBack));
        expect(firstBack.controller.asFake.calls, ['initialize', 'play']);
        expect(
            controller.backgroundTrackController.last.controller.asFake.calls,
            ['initialize']);

        // First background medium finishes
        controller.backgroundTrackController.current.controller
            .onMediumFinished(_FakeContext());
        expect(notifyCalls, 0);
        expect(controller.mainTrackController.current,
            same(controller.mainTrackController.last));
        expect(firstMain.controller.asFake.calls, ['initialize', 'play']);
        expect(controller.mainTrackController.last.controller.asFake.calls,
            ['initialize', 'play']);
        expect(controller.backgroundTrackController.current,
            same(controller.backgroundTrackController.last));
        expect(firstBack.controller.asFake.calls, ['initialize', 'play']);
        expect(
            controller.backgroundTrackController.last.controller.asFake.calls,
            ['initialize', 'play']);
      }

      test('when background track finishes first', () async {
        final controller = await testInitialize();
        final firstMain = controller.mainTrackController.current;
        final firstBack = controller.backgroundTrackController.current;

        controller.addListener(updateNotifyCalled);

        await testFirstMediaPlayed(controller);

        // Second background medium finishes
        controller.backgroundTrackController.current.controller
            .onMediumFinished(_FakeContext());
        expect(notifyCalls, 0);
        expect(controller.mainTrackController.current,
            same(controller.mainTrackController.last));
        expect(firstMain.controller.asFake.calls, ['initialize', 'play']);
        expect(controller.mainTrackController.last.controller.asFake.calls,
            ['initialize', 'play']);
        expect(controller.backgroundTrackController.current, isNull);
        expect(firstBack.controller.asFake.calls, ['initialize', 'play']);
        expect(
            controller.backgroundTrackController.last.controller.asFake.calls,
            ['initialize', 'play']);

        controller.removeListener(updateNotifyCalled);

        // Second (and last) main medium finishes, onMediumFinished should be
        // called.
        controller.mainTrackController.current.controller
            .onMediumFinished(_FakeContext());
        expect(notifyCalls, 0);
        expect(finished, isTrue);
        expect(controller.allInitialized, isTrue);
        expect(controller.backgroundTrackController, isNotEmpty);
        expect(controller.mainTrackController.current, isNull);
        expect(firstMain.controller.asFake.calls, ['initialize', 'play']);
        expect(controller.mainTrackController.last.controller.asFake.calls,
            ['initialize', 'play']);
        expect(controller.backgroundTrackController.current, isNull);
        expect(firstBack.controller.asFake.calls, ['initialize', 'play']);
        expect(
            controller.backgroundTrackController.last.controller.asFake.calls,
            ['initialize', 'play']);

        await controller.dispose();
        expect(firstMain.controller.asFake.calls,
            ['initialize', 'play', 'dispose']);
        expect(controller.mainTrackController.last.controller.asFake.calls,
            ['initialize', 'play', 'dispose']);
        expect(firstBack.controller.asFake.calls,
            ['initialize', 'play', 'dispose']);
        expect(
            controller.backgroundTrackController.last.controller.asFake.calls,
            ['initialize', 'play', 'dispose']);
      });

      test('when main track finishes first', () async {
        final controller = await testInitialize();
        final firstMain = controller.mainTrackController.current;
        final firstBack = controller.backgroundTrackController.current;

        controller.addListener(updateNotifyCalled);

        await testFirstMediaPlayed(controller);

        // Second (and last) main medium finishes, onMediumFinished should be
        // called.
        controller.mainTrackController.current.controller
            .onMediumFinished(_FakeContext());
        expect(notifyCalls, 0);
        expect(finished, isTrue);
        expect(controller.allInitialized, isTrue);
        expect(controller.backgroundTrackController, isNotEmpty);
        expect(controller.mainTrackController.current, isNull);
        expect(firstMain.controller.asFake.calls, ['initialize', 'play']);
        expect(controller.mainTrackController.last.controller.asFake.calls,
            ['initialize', 'play']);
        expect(controller.backgroundTrackController.current,
            controller.backgroundTrackController.last);
        expect(firstBack.controller.asFake.calls, ['initialize', 'play']);
        expect(
            controller.backgroundTrackController.last.controller.asFake.calls,
            ['initialize', 'play', 'pause']);

        controller.removeListener(updateNotifyCalled);

        await controller.dispose();
        expect(firstMain.controller.asFake.calls,
            ['initialize', 'play', 'dispose']);
        expect(controller.mainTrackController.last.controller.asFake.calls,
            ['initialize', 'play', 'dispose']);
        expect(firstBack.controller.asFake.calls,
            ['initialize', 'play', 'dispose']);
        expect(
            controller.backgroundTrackController.last.controller.asFake.calls,
            ['initialize', 'play', 'pause', 'dispose']);
      });
    });

    test('toString()', () {
      expect(
        MultiMediumController(multiMedium, registry,
            onMediumFinished: (context) => null).toString(),
        'MultiMediumController(main: MultiMediumTrackController(audible, '
        'current: 0, media: 2), '
        'background: MultiMediumTrackController(visualizable, '
        'current: 0, media: 2))',
      );
      expect(
        MultiMediumController(audibleMultiMedium, registry).toString(),
        'MultiMediumController(main: MultiMediumTrackController(audible, '
        'current: 0, media: 2))',
      );
    });

    test('debugFillProperties() and debugDescribeChildren()', () {
      final identityHash = RegExp(r'#[0-9a-f]{5}');

      expect(
          MultiMediumController(multiMedium, registry,
                  onMediumFinished: (context) => null)
              .toStringDeep()
              .replaceAll(identityHash, ''),
          'MultiMediumController\n'
          ' │ notifies when all media finished\n'
          ' │ main:\n'
          ' │   MultiMediumTrackController(audible, currentIndex: 0, mediaState.length: 2)\n'
          ' │ background:\n'
          ' │   MultiMediumTrackController(visualizble, currentIndex: 0, mediaState.length: 2)\n'
          ' │\n'
          ' ├─main: MultiMediumTrackController\n'
          ' │ │ audible\n'
          ' │ │ currentIndex: 0\n'
          ' │ │ mediaState.length: 2\n'
          ' │ │\n'
          ' │ ├─0: SingleMediumState\n'
          ' │ │   medium: _FakeAudibleSingleMedium(resource: audible, maxDuration:\n'
          ' │ │     8760:00:00.000000)\n'
          ' │ │   size: <uninitialized>\n'
          ' │ │\n'
          ' │ └─1: SingleMediumState\n'
          ' │     medium: _FakeAudibleSingleMedium(resource: visualizable,\n'
          ' │       maxDuration: 8760:00:00.000000)\n'
          ' │     size: <uninitialized>\n'
          ' │\n'
          ' └─background: MultiMediumTrackController\n'
          '   │ visualizble\n'
          '   │ currentIndex: 0\n'
          '   │ mediaState.length: 2\n'
          '   │\n'
          '   ├─0: SingleMediumState\n'
          '   │   medium: _FakeVisualizableSingleMedium(resource: visualizable1,\n'
          '   │     maxDuration: 8760:00:00.000000)\n'
          '   │   size: <uninitialized>\n'
          '   │\n'
          '   └─1: SingleMediumState\n'
          '       medium: _FakeVisualizableSingleMedium(resource: visualizable2,\n'
          '         maxDuration: 8760:00:00.000000)\n'
          '       size: <uninitialized>\n'
          '');

      expect(
          MultiMediumController(audibleMultiMedium, registry)
              .toStringDeep()
              .replaceAll(identityHash, ''),
          'MultiMediumController\n'
          ' │ main:\n'
          ' │   MultiMediumTrackController(audible, currentIndex: 0, mediaState.length: 2)\n'
          ' │\n'
          ' ├─main: MultiMediumTrackController\n'
          ' │ │ audible\n'
          ' │ │ currentIndex: 0\n'
          ' │ │ mediaState.length: 2\n'
          ' │ │\n'
          ' │ ├─0: SingleMediumState\n'
          ' │ │   medium: _FakeAudibleSingleMedium(resource: audible, maxDuration:\n'
          ' │ │     8760:00:00.000000)\n'
          ' │ │   size: <uninitialized>\n'
          ' │ │\n'
          ' │ └─1: SingleMediumState\n'
          ' │     medium: _FakeAudibleSingleMedium(resource: visualizable,\n'
          ' │       maxDuration: 8760:00:00.000000)\n'
          ' │     size: <uninitialized>\n'
          ' │\n'
          ' └─background: MultiMediumTrackController\n'
          '     empty\n'
          '');
    });
  });
}

class _FakeContext extends Fake implements BuildContext {}

class _SingleMediumInfo {
  final Size size;
  final Exception exception;
  final Key widgetKey;
  _SingleMediumInfo(
    String location, {
    this.size,
    this.exception,
  })  : assert(location != null),
        assert(exception != null && size == null ||
            exception == null && size != null),
        widgetKey = GlobalKey(debugLabel: 'widgetKey(${location}');
}

abstract class _FakeSingleMedium extends SingleMedium {
  final _SingleMediumInfo info;
  _FakeSingleMedium(
    String location, {
    Size size,
    Exception exception,
  })  : info = _SingleMediumInfo(location, size: size, exception: exception),
        super(Uri.parse(location));
}

class _FakeAudibleSingleMedium extends _FakeSingleMedium implements Audible {
  _FakeAudibleSingleMedium(
    String location, {
    Size size,
    Exception exception,
  }) : super(location, size: size, exception: exception);
}

class _FakeVisualizableSingleMedium extends _FakeSingleMedium
    implements Visualizable {
  _FakeVisualizableSingleMedium(
    String location, {
    Size size,
    Exception exception,
  }) : super(location, size: size, exception: exception);
}

class _FakeVisualizableBackgroundMultiMediumTrack
    extends VisualizableBackgroundMultiMediumTrack implements Visualizable {
  _FakeVisualizableBackgroundMultiMediumTrack(List<Visualizable> media)
      : super(media);
}

void _registerControllers(ControllerRegistry registry) {
  SingleMediumController createController(SingleMedium medium,
      {void Function(BuildContext) onMediumFinished}) {
    final fakeMedium = medium as _FakeSingleMedium;
    final c = _FakeSingleMediumController(fakeMedium,
        widgetKey: fakeMedium.info.widgetKey,
        onMediumFinished: onMediumFinished);
    return c;
  }

  registry.register(_FakeAudibleSingleMedium, createController);
  registry.register(_FakeVisualizableSingleMedium, createController);
}

class _FakeSingleMediumController extends Fake
    implements SingleMediumController {
  @override
  _FakeSingleMedium medium;

  @override
  Key widgetKey;

  @override
  void Function(BuildContext context) onMediumFinished;

  final calls = <String>[];

  _FakeSingleMediumController(
    this.medium, {
    Key widgetKey,
    this.onMediumFinished,
  })  : assert(medium != null),
        widgetKey = widgetKey ?? GlobalKey(debugLabel: 'mediumKey');

  Future<T> _errorOr<T>(String name, [T value]) {
    calls.add(name);
    return medium.info.exception != null
        ? Future.error(medium.info.exception)
        : Future<T>.value(value);
  }

  @override
  Future<Size> initialize(BuildContext context) =>
      _errorOr('initialize', medium.info.size);

  @override
  Future<void> play(BuildContext context) => _errorOr<void>('play');

  @override
  Future<void> pause(BuildContext context) => _errorOr<void>('pause');

  @override
  Future<void> dispose() => _errorOr<void>('dispose');

  @override
  Widget build(BuildContext context) {
    calls.add('build');
    return Container(key: widgetKey);
  }
}

extension _AsFakeSingleMediumController on SingleMediumController {
  _FakeSingleMediumController get asFake => this as _FakeSingleMediumController;
}

// vim: set foldmethod=syntax foldminlines=3 :
