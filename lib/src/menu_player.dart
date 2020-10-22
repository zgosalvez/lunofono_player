import 'package:flutter/material.dart';

import 'package:flutter_grid_button/flutter_grid_button.dart'
    show GridButton, GridButtonItem;

import 'package:lunofono_bundle/lunofono_bundle.dart' show Menu, GridMenu;

import 'button_player.dart' show ButtonPlayer;
import 'dynamic_dispatch_registry.dart' show DynamicDispatchRegistry;

/// Register all builtin types
///
/// When new builtin types are added, they should be registered by this
/// function, which is used by [MenuPlayerRegistry.builtin()].
void _registerBuiltin(MenuPlayerRegistry registry) {
  // New menus should be registered here
  registry.register(GridMenu, (menu) => GridMenuPlayer(menu as GridMenu));
}

/// A wrapper to manage how a [Menu] is played by the player.
///
/// This class also manages a registry of implementations for the different
/// concrete types of [Menu]. To get an menu wrapper, [MenuPlayer.wrap()]
/// should be used.
abstract class MenuPlayer {
  /// The [MenuPlayerRegistry] used to dispatch the calls.
  static var registry = MenuPlayerRegistry.builtin();

  /// Dispatches the call dynamically by using the [registry].
  ///
  /// The dispatch is done based on this [runtimeType], so only concrete leaf
  /// types can be dispatched. It asserts if a type is not registered.
  static MenuPlayer wrap(Menu menu) {
    final wrap = registry.getFunction(menu);
    assert(wrap != null, 'Unimplemented MenuPlayer for ${menu.runtimeType}');
    return wrap(menu);
  }

  /// The underlaying model's [Menu].
  Menu get menu;

  /// Builds the UI for this [menu].
  Widget build(BuildContext context);
}

class GridMenuPlayer extends MenuPlayer {
  /// The [GridMenu] that this widget represents.
  @override
  final GridMenu menu;

  /// The number of rows in the underlaying [menu].
  int get rows => menu.rows;

  /// The number of columns in the underlaying [menu].
  int get columns => menu.columns;

  /// The list of [ButtonPlayer]s wrapping this [menu.buttons].
  final List<ButtonPlayer> buttons;

  /// Gets the [Button] at position ([row], [column]) in the grid.
  ///
  /// TODO: Swap rows and cols if the orientation is forced?
  ButtonPlayer buttonAt(int row, int column) => buttons[row * columns + column];

  /// Constructs a [GridMenuPlayer] from a [GridMenu].
  ///
  /// This also wrap all the [menu.buttons] to store [ButtonPlayer]s instead.
  GridMenuPlayer(this.menu)
      : assert(menu != null),
        buttons = List<ButtonPlayer>.from(
            menu.buttons.map<ButtonPlayer>((b) => ButtonPlayer.wrap(b)));

  /// Builds the UI for this [menu].
  @override
  Widget build(BuildContext context) {
    return GridMenuWidget(this);
  }
}

/// A Widget to play a [GridMenu].
class GridMenuWidget extends StatelessWidget {
  /// The [GridMenu] that this widget represents.
  final GridMenuPlayer menu;

  /// Constructs a widget for a [menu].
  const GridMenuWidget(
    this.menu, {
    Key key,
  }) : super(key: key);

  /// Builds the UI for this widget.
  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 26);
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: GridButton(
        textStyle: textStyle,
        hideSurroundingBorder: true,
        onPressed: (dynamic value) {
          final button = value as ButtonPlayer;
          button.action.act(context, button);
        },
        items: _buildButtonsGrid(context),
      ),
    );
  }

  /// Builds a grid of buttons for the menu.
  ///
  /// The grid is represented by a list of rows and a row is a list of buttons
  /// (the columns of that row).
  List<List<GridButtonItem>> _buildButtonsGrid(BuildContext context) {
    final rows = <List<GridButtonItem>>[];
    for (var i = 0; i < menu.rows; i++) {
      rows.add([]);
      for (var j = 0; j < menu.columns; j++) {
        rows.last.add(menu.buttonAt(i, j).create(context));
      }
    }
    return rows;
  }
}

/// A function type to build the UI of a [Menu].
typedef WrapFunction = MenuPlayer Function(Menu menu);

/// A registry to map from [Menu] types to [BuildFunction].
class MenuPlayerRegistry extends DynamicDispatchRegistry<Menu, WrapFunction> {
  /// Constructs an empty registry.
  MenuPlayerRegistry();

  /// Constructs a registry with builtin types registered.
  MenuPlayerRegistry.builtin() {
    _registerBuiltin(this);
  }
}
