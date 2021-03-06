import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:lunofono_player/src/media_player/single_medium_controller.dart';

import '../../../util/test_asset_bundle.dart' show TestAssetBundle;

class NoCheckSize extends Size {
  const NoCheckSize() : super(0.0, 0.0);
}

final globalSuccessKey = GlobalKey(debugLabel: 'successKey');

Size globalSize;

void expectLoading(WidgetTester tester, TestWidget widget) {
  expect(find.byKey(widget.loadingKey), findsOneWidget);
  expect(find.byKey(widget.errorKey), findsNothing);
  expect(find.byKey(globalSuccessKey), findsNothing);
  expect(globalSize, null);
}

void expectError(WidgetTester tester, TestWidget widget) {
  expect(find.byKey(widget.errorKey), findsOneWidget);
  expect(find.byKey(widget.loadingKey), findsNothing);
  expect(find.byKey(globalSuccessKey), findsNothing);
  expect(globalSize, null);
}

Widget expectSuccess(WidgetTester tester, TestWidget widget,
    {Size size = const NoCheckSize(), Type findWidget}) {
  expect(find.byKey(globalSuccessKey), findsOneWidget);
  expect(find.byKey(widget.loadingKey), findsNothing);
  expect(find.byKey(widget.errorKey), findsNothing);
  if (size is! NoCheckSize) {
    expect(globalSize, size);
  }
  if (findWidget != null) {
    final foundWidget = find.byType(findWidget);
    expect(foundWidget, findsOneWidget);
    return tester.firstWidget(foundWidget);
  }
  return null;
}

class TestWidget extends StatelessWidget {
  final Key errorKey;
  final Key loadingKey;
  final SingleMediumController controller;
  final AssetBundle bundle;
  TestWidget(this.controller, {AssetBundle bundle})
      : assert(controller != null),
        errorKey = GlobalKey(debugLabel: 'errorKey'),
        loadingKey = GlobalKey(debugLabel: 'loadingKey'),
        bundle = bundle ?? TestAssetBundle() {
    globalSize = null;
  }

  Future<Size> _initializeAndPlay(BuildContext context) async {
    final size = await controller.initialize(context);
    globalSize = size;
    await controller.play(context);
    return size;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultAssetBundle(
        bundle: bundle,
        // Needed so we pass the context with the overridden DefaultAssetBundle
        child: Builder(
          builder: (context) => FutureBuilder<Size>(
            future: _initializeAndPlay(context),
            builder: (BuildContext context, AsyncSnapshot<Size> snapshot) {
              if (snapshot.hasData) {
                return controller.build(context);
              }
              if (snapshot.hasError) {
                return Text(
                  'Error loading ${controller.medium.resource}: ${snapshot.error}',
                  key: errorKey,
                );
              }
              return Text('Loading ${controller.medium.resource}...',
                  key: loadingKey);
            },
          ),
        ),
      ),
    );
  }
}
