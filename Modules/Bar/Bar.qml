import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Notification
import qs.Modules.Panels.Settings
import qs.Services.Compositor
import qs.Services.Media
import qs.Services.UI
import qs.Widgets
import "../../Helpers/ColorsConvert.js" as ColorsConvert

// Bar Component
Item {
  id: root

  // This property will be set by MainScreen
  property ShellScreen screen: null

  // Filter widgets to only include those that exist in the registry
  // This prevents errors when plugins are missing or widgets are being cleaned up
  function filterValidWidgets(widgets: list<var>): list<var> {
    if (!widgets)
      return [];
    return widgets.filter(function (w) {
      return w && w.id && BarWidgetRegistry.hasWidget(w.id);
    });
  }

  // Hot corner: trigger click on first widget in a section
  function triggerFirstWidgetInSection(sectionName: string) {
    var widgets = BarService.getWidgetsBySection(sectionName, screen?.name);
    for (var i = 0; i < widgets.length; i++) {
      var widget = widgets[i];
      if (widget && widget.visible && widget.widgetId !== "Spacer") {
        if (typeof widget.clicked === "function") {
          widget.clicked();
        }
        return;
      }
    }
  }

  // Hot corner: trigger click on last widget in a section
  function triggerLastWidgetInSection(sectionName: string) {
    var widgets = BarService.getWidgetsBySection(sectionName, screen?.name);
    for (var i = widgets.length - 1; i >= 0; i--) {
      var widget = widgets[i];
      if (widget && widget.visible && widget.widgetId !== "Spacer") {
        if (typeof widget.clicked === "function") {
          widget.clicked();
        }
        return;
      }
    }
  }

  // Expose bar region for click-through mask
  readonly property var barRegion: barContentLoader.item?.children[0] || null

  // Expose the actual bar Item for unified background system
  readonly property var barItem: barRegion

  // Bar positioning properties (per-screen)
  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
  readonly property bool barFloating: Settings.data.bar.barType === "floating"

  // Bar density (per-screen)
  readonly property string barDensity: Settings.getBarDensityForScreen(screen?.name)

  // Bar sizing based on per-screen density
  readonly property real barHeight: Style.getBarHeightForDensity(barDensity, barIsVertical)
  readonly property real capsuleHeight: Style.getCapsuleHeightForDensity(barDensity, barHeight)
  readonly property real barFontSize: Style.getBarFontSizeForDensity(barHeight, capsuleHeight, barIsVertical)

  // Bar widgets (per-screen) - initial configuration
  // Note: Updates are handled via Connections to BarService.widgetsRevisionChanged
  readonly property var barWidgets: Settings.getBarWidgetsForScreen(screen?.name)

  // Stable ListModels for each section - prevents Repeater recreation on settings changes
  property ListModel leftWidgetsModel: ListModel {}
  property ListModel centerWidgetsModel: ListModel {}
  property ListModel rightWidgetsModel: ListModel {}

  // Guard: set when Bar is destroyed; prevents Qt.callLater callbacks from running
  // during/after teardown (avoids SIGSEGV in QV4::Object::insertMember when rapid
  // workspace switch causes load/unload overlap with async widget incubation)
  property bool _destroyed: false
  Component.onDestruction: root._destroyed = true

  // Sync a ListModel with widget data, preserving delegates when only settings change
  function syncWidgetModel(model, newWidgets) {
    var validWidgets = filterValidWidgets(newWidgets);

    // Build list of current IDs in model
    var currentIds = [];
    for (var i = 0; i < model.count; i++) {
      currentIds.push(model.get(i).id);
    }

    // Build list of new IDs
    var newIds = validWidgets.map(w => w.id);

    // Check if structure changed (different IDs or order)
    var structureChanged = currentIds.length !== newIds.length;
    if (!structureChanged) {
      for (var i = 0; i < currentIds.length; i++) {
        if (currentIds[i] !== newIds[i]) {
          structureChanged = true;
          break;
        }
      }
    }

    Logger.d("Bar", "syncWidgetModel:", currentIds.join("|"), "→", newIds.join("|"), "changed:", structureChanged);

    if (structureChanged) {
      // Rebuild model - IDs changed
      model.clear();
      for (var i = 0; i < validWidgets.length; i++) {
        model.append(validWidgets[i]);
      }
    }
    // If structure didn't change, delegates are preserved and will read fresh settings
  }

  // Sync models when widget revision changes
  // Note: We use Connections instead of onBarWidgetsChanged because getBarWidgetsForScreen
  // returns the same object reference (Settings.data.bar.widgets) even when content changes,
  // so QML won't detect the change via property binding.
  Connections {
    target: BarService
    function onWidgetsRevisionChanged() {
      Logger.d("Bar", "onWidgetsRevisionChanged, revision:", BarService.widgetsRevision, "screen:", root.screen?.name);
      Qt.callLater(root._syncFromRevision);
    }
  }

  function _syncFromRevision() {
    if (root._destroyed)
      return;
    var widgets = Settings.getBarWidgetsForScreen(screen?.name);
    if (widgets) {
      syncWidgetModel(leftWidgetsModel, widgets.left);
      syncWidgetModel(centerWidgetsModel, widgets.center);
      syncWidgetModel(rightWidgetsModel, widgets.right);
    }
  }

  // Initialize models — deferred to next event-loop tick via Qt.callLater to avoid
  // re-entrant incubation: Component.onCompleted fires during QQmlObjectCreator::finalize,
  // and ListModel.append synchronously creates Repeater delegates whose own finalization
  // can corrupt the V4 heap (SIGSEGV in QV4::Object::insertMember).
  Component.onCompleted: {
    Logger.d("Bar", "Bar Component.onCompleted for screen:", screen?.name);
    Qt.callLater(root._initModels);
  }

  function _initModels() {
    if (root._destroyed)
      return;
    var widgets = Settings.getBarWidgetsForScreen(screen?.name);
    if (widgets) {
      syncWidgetModel(leftWidgetsModel, widgets.left);
      syncWidgetModel(centerWidgetsModel, widgets.center);
      syncWidgetModel(rightWidgetsModel, widgets.right);
    }
  }

  // Fill the parent (the Loader)
  anchors.fill: parent

  // Register bar when screen becomes available
  onScreenChanged: {
    if (screen && screen.name) {
      Logger.d("Bar", "Bar screen set to:", screen.name);
      Logger.d("Bar", "  Position:", barPosition, "Floating:", barFloating);
      BarService.registerBar(screen.name);
    }
  }

  // Wait for screen to be set before loading bar content
  Loader {
    id: barContentLoader
    anchors.fill: parent
    active: {
      if (root.screen === null || root.screen === undefined) {
        return false;
      }

      var monitors = Settings.data.bar.monitors || [];
      var result = monitors.length === 0 || monitors.includes(root.screen.name);
      return result;
    }

    sourceComponent: Item {
      anchors.fill: parent

      // Bar container - Content
      Item {
        id: bar

        // Wheel scroll handling (empty bar area)
        property int barWheelAccumulatedDelta: 0
        property bool barWheelCooldown: false
        readonly property string barWheelAction: {
          return Settings.data.bar.mouseWheelAction || "none";
        }
        readonly property string barRightClickAction: Settings.data.bar.rightClickAction || "controlCenter"

        // Position and size the bar content based on orientation
        x: (root.barPosition === "right") ? (parent.width - root.barHeight) : 0
        y: (root.barPosition === "bottom") ? (parent.height - root.barHeight) : 0
        width: root.barIsVertical ? root.barHeight : parent.width
        height: root.barIsVertical ? parent.height : root.barHeight

        // Corner states for new unified background system
        // State -1: No radius (flat/square corner)
        // State 0: Normal (inner curve)
        // State 1: Horizontal inversion (outer curve on X-axis)
        // State 2: Vertical inversion (outer curve on Y-axis)
        readonly property int topLeftCornerState: {
          // Floating bar: always simple rounded corners
          if (barFloating)
            return 0;
          // Top bar: top corners against screen edge = no radius
          if (barPosition === "top")
            return -1;
          // Left bar: top-left against screen edge = no radius
          if (barPosition === "left")
            return -1;
          // Bottom/Right bar with outerCorners: inverted corner
          if (Settings.data.bar.outerCorners && (barPosition === "bottom" || barPosition === "right")) {
            return barIsVertical ? 1 : 2; // horizontal invert for vertical bars, vertical invert for horizontal
          }
          // No outerCorners = square
          return -1;
        }

        readonly property int topRightCornerState: {
          // Floating bar: always simple rounded corners
          if (barFloating)
            return 0;
          // Top bar: top corners against screen edge = no radius
          if (barPosition === "top")
            return -1;
          // Right bar: top-right against screen edge = no radius
          if (barPosition === "right")
            return -1;
          // Bottom/Left bar with outerCorners: inverted corner
          if (Settings.data.bar.outerCorners && (barPosition === "bottom" || barPosition === "left")) {
            return barIsVertical ? 1 : 2;
          }
          // No outerCorners = square
          return -1;
        }

        readonly property int bottomLeftCornerState: {
          // Floating bar: always simple rounded corners
          if (barFloating)
            return 0;
          // Bottom bar: bottom corners against screen edge = no radius
          if (barPosition === "bottom")
            return -1;
          // Left bar: bottom-left against screen edge = no radius
          if (barPosition === "left")
            return -1;
          // Top/Right bar with outerCorners: inverted corner
          if (Settings.data.bar.outerCorners && (barPosition === "top" || barPosition === "right")) {
            return barIsVertical ? 1 : 2;
          }
          // No outerCorners = square
          return -1;
        }

        readonly property int bottomRightCornerState: {
          // Floating bar: always simple rounded corners
          if (barFloating)
            return 0;
          // Bottom bar: bottom corners against screen edge = no radius
          if (barPosition === "bottom")
            return -1;
          // Right bar: bottom-right against screen edge = no radius
          if (barPosition === "right")
            return -1;
          // Top/Left bar with outerCorners: inverted corner
          if (Settings.data.bar.outerCorners && (barPosition === "top" || barPosition === "left")) {
            return barIsVertical ? 1 : 2;
          }
          // No outerCorners = square
          return -1;
        }

        function isPointOverWidget(xPos, yPos) {
          var widgets = BarService.getAllWidgetInstances(null, screen.name);
          for (var i = 0; i < widgets.length; i++) {
            var widget = widgets[i];
            if (!widget || !widget.visible || widget.widgetId === "Spacer") {
              continue;
            }
            var localPos = mapToItem(widget, xPos, yPos);

            if (root.barIsVertical) {
              if (localPos.y >= -Style.marginS && localPos.y <= widget.height + Style.marginS) {
                return true;
              }
            } else {
              if (localPos.x >= -Style.marginS && localPos.x <= widget.width + Style.marginS) {
                return true;
              }
            }
          }
          return false;
        }

        function switchWorkspaceByOffset(offset) {
          if (!root.screen || CompositorService.workspaces.count === 0)
            return;

          var screenName = root.screen.name.toLowerCase();
          var candidates = [];
          for (var i = 0; i < CompositorService.workspaces.count; i++) {
            var ws = CompositorService.workspaces.get(i);
            var matchesScreen = CompositorService.globalWorkspaces || (ws.output && ws.output.toLowerCase() === screenName);
            if (matchesScreen)
              candidates.push(ws);
          }

          if (candidates.length <= 1)
            return;

          var current = -1;
          for (var j = 0; j < candidates.length; j++) {
            if (candidates[j].isFocused) {
              current = j;
              break;
            }
          }
          if (current < 0)
            current = 0;

          var next = current + offset;
          if (Settings.data.bar.mouseWheelWrap) {
            next = next % candidates.length;
            if (next < 0)
              next = candidates.length - 1;
          } else {
            if (next < 0 || next >= candidates.length)
              return;
          }

          if (next === current)
            return;
          CompositorService.switchToWorkspace(candidates[next]);
        }

        function handleEmptyBarClick(action, followMouse, command, mouse) {
          if (action === "none")
            return;
          if (action === "controlCenter") {
            var controlCenterPanel = PanelService.getPanel("controlCenterPanel", screen);
            controlCenterPanel?.toggle(null, followMouse ? mapToItem(null, mouse.x, mouse.y) : "ControlCenter");
            mouse.accepted = true;
          } else if (action === "settings") {
            var settingsPanel = PanelService.getPanel("settingsPanel", screen);
            settingsPanel?.toggle(null, followMouse ? mapToItem(null, mouse.x, mouse.y) : null);
            mouse.accepted = true;
          } else if (action === "launcherPanel") {
            var launcherPanel = PanelService.getPanel("launcherPanel", screen);
            launcherPanel?.toggle(null, followMouse ? mapToItem(null, mouse.x, mouse.y) : null);
            mouse.accepted = true;
          } else if (action === "command") {
            runCustomCommand(command);
            mouse.accepted = true;
          }
        }

        function runCustomCommand(command) {
          if (!command || command.trim() === "")
            return;

          const processString = "import QtQuick; import Quickshell.Io; Process { command: [\"sh\", \"-lc\", \"\"] }";

          try {
            const processObj = Qt.createQmlObject(processString, root, "BarCommandProcess_" + Date.now());
            processObj.command = ["sh", "-lc", command];

            processObj.exited.connect(function (exitCode) {
              if (exitCode !== 0) {
                ToastService.showError(I18n.tr("toast.custom-command-failed.title"), I18n.tr("toast.custom-command-failed.description", {
                                                                                               command: command,
                                                                                               code: exitCode
                                                                                             }));
              }
              processObj.destroy();
            });

            processObj.running = true;
          } catch (e) {
            Logger.e("Bar", "Failed to start custom command:", e);
            ToastService.showError(I18n.tr("toast.custom-command-failed.title"), I18n.tr("toast.custom-command-failed.description", {
                                                                                           command: command,
                                                                                           code: "start_error"
                                                                                         }));
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.RightButton | Qt.MiddleButton
          // Keep enabled even when actions are "none" so we still swallow right/middle on
          // empty bar gaps. Otherwise Qt Quick's context-menu path can crash on Wayland
          // (QQuickDeliveryAgentPrivate::contextMenuTargets / mapToScene).
          enabled: true
          hoverEnabled: false
          preventStealing: true
          onClicked: mouse => {
                       if (mouse.button === Qt.RightButton) {
                         if (bar.isPointOverWidget(mouse.x, mouse.y))
                         return;
                         bar.handleEmptyBarClick(bar.barRightClickAction, Settings.data.bar.rightClickFollowMouse, Settings.data.bar.rightClickCommand, mouse);
                         mouse.accepted = true;
                         return;
                       }
                       if (mouse.button === Qt.MiddleButton) {
                         if (bar.isPointOverWidget(mouse.x, mouse.y))
                         return;
                         bar.handleEmptyBarClick(Settings.data.bar.middleClickAction || "none", Settings.data.bar.middleClickFollowMouse, Settings.data.bar.middleClickCommand, mouse);
                         mouse.accepted = true;
                         return;
                       }
                     }
        }

        // Debounce timer for wheel interactions
        Timer {
          id: barWheelDebounce
          interval: 150
          repeat: false
          onTriggered: {
            bar.barWheelCooldown = false;
            bar.barWheelAccumulatedDelta = 0;
          }
        }

        // Scroll on empty bar area action
        WheelHandler {
          id: barWheelHandler
          target: bar
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          enabled: bar.barWheelAction !== "none"

          onWheel: function (event) {
            if (bar.isPointOverWidget(event.x, event.y))
              return;

            var dy = event.angleDelta.y;
            var dx = event.angleDelta.x;
            var useDy = Math.abs(dy) >= Math.abs(dx);
            var delta = useDy ? dy : dx;
            var step = 120;

            if (bar.barWheelAction === "volume") {
              if (Settings.data.bar.reverseScroll)
                delta *= -1;

              bar.barWheelAccumulatedDelta += delta;
              if (bar.barWheelAccumulatedDelta >= step) {
                AudioService.increaseVolume();
                bar.barWheelAccumulatedDelta = 0;
                event.accepted = true;
              } else if (bar.barWheelAccumulatedDelta <= -step) {
                AudioService.decreaseVolume();
                bar.barWheelAccumulatedDelta = 0;
                event.accepted = true;
              }
              return;
            }

            if (bar.barWheelCooldown)
              return;

            bar.barWheelAccumulatedDelta += delta;
            if (Math.abs(bar.barWheelAccumulatedDelta) >= step) {
              var direction = bar.barWheelAccumulatedDelta > 0 ? -1 : 1;
              if (Settings.data.bar.reverseScroll)
                direction *= -1;
              if (bar.barWheelAction === "workspace") {
                bar.switchWorkspaceByOffset(direction);
              } else if (bar.barWheelAction === "content") {
                CompositorService.scrollWorkspaceContent(direction);
              }
              bar.barWheelCooldown = true;
              barWheelDebounce.restart();
              bar.barWheelAccumulatedDelta = 0;
              event.accepted = true;
            }
          }
        }

        Loader {
          anchors.fill: parent
          sourceComponent: root.barIsVertical ? verticalBarComponent : horizontalBarComponent
        }
      }
    }
  }

  // For vertical bars
  Component {
    id: verticalBarComponent
    Item {
      anchors.fill: parent
      clip: true

      // Top edge hot corner - triggers first widget in left (top) section
      MouseArea {
        width: parent.width
        height: Style.marginS
        x: 0
        y: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) {
          if (mouse.button !== Qt.LeftButton) {
            mouse.accepted = true;
            return;
          }
          root.triggerFirstWidgetInSection("left");
        }
      }

      // Bottom edge hot corner - triggers last widget in right (bottom) section
      MouseArea {
        width: parent.width
        height: Style.marginS
        x: 0
        anchors.bottom: parent.bottom
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) {
          if (mouse.button !== Qt.LeftButton) {
            mouse.accepted = true;
            return;
          }
          root.triggerLastWidgetInSection("right");
        }
      }

      // Calculate margin to center widgets vertically within the bar height
      readonly property real verticalBarMargin: Math.round((root.barHeight - root.capsuleHeight) / 2)

      // Top section (left widgets)
      ColumnLayout {
        id: vTopSection
        x: Style.pixelAlignCenter(parent.width, width)
        anchors.top: parent.top
        anchors.topMargin: verticalBarMargin + Settings.data.bar.contentPadding
        spacing: Settings.data.bar.widgetSpacing

        Repeater {
          model: root.leftWidgetsModel
          delegate: BarWidgetLoader {
            required property var model
            required property int index

            widgetId: model.id || ""
            widgetScreen: root.screen
            widgetProps: ({
                            "widgetId": model.id,
                            "section": "left",
                            "sectionWidgetIndex": index,
                            "sectionWidgetsCount": root.leftWidgetsModel.count
                          })
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      // Center section (center widgets)
      ColumnLayout {
        id: vCenterSection
        x: Style.pixelAlignCenter(parent.width, width)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Settings.data.bar.widgetSpacing

        Repeater {
          model: root.centerWidgetsModel
          delegate: BarWidgetLoader {
            required property var model
            required property int index

            widgetId: model.id || ""
            widgetScreen: root.screen
            widgetProps: ({
                            "widgetId": model.id,
                            "section": "center",
                            "sectionWidgetIndex": index,
                            "sectionWidgetsCount": root.centerWidgetsModel.count
                          })
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      // Bottom section (right widgets)
      ColumnLayout {
        id: vBottomSection
        x: Style.pixelAlignCenter(parent.width, width)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: verticalBarMargin + Settings.data.bar.contentPadding
        spacing: Settings.data.bar.widgetSpacing

        Repeater {
          model: root.rightWidgetsModel
          delegate: BarWidgetLoader {
            required property var model
            required property int index

            widgetId: model.id || ""
            widgetScreen: root.screen
            widgetProps: ({
                            "widgetId": model.id,
                            "section": "right",
                            "sectionWidgetIndex": index,
                            "sectionWidgetsCount": root.rightWidgetsModel.count
                          })
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      // ---- Sumi scene chrome (backgroundStyle === "sumi") ----
      // Ink brush rail: a thin vertical hairline threading the sections,
      // with a small square tick at each end — sumi's paper-and-ink motif.
      readonly property bool sumiMode: Settings.data.bar.backgroundStyle === "sumi"

      Rectangle {
        visible: parent.sumiMode
        x: Style.pixelAlignCenter(parent.width, Style.borderS)
        y: vTopSection.y + vTopSection.height + Style.marginM
        width: Style.borderS
        height: Math.max(0, vBottomSection.y - Style.marginM - y)
        color: Qt.rgba(NColor.mOnSurface.r, NColor.mOnSurface.g, NColor.mOnSurface.b, 0.22)
        z: -1
      }

      // Top end tick (ink square)
      Rectangle {
        visible: parent.sumiMode
        x: Style.pixelAlignCenter(parent.width, Style.marginXS)
        y: vTopSection.y + vTopSection.height + Style.marginXS
        width: Style.marginXS
        height: Style.marginXS
        color: Qt.rgba(NColor.mOnSurface.r, NColor.mOnSurface.g, NColor.mOnSurface.b, 0.45)
        z: -1
      }

      // Bottom end tick (ink square)
      Rectangle {
        visible: parent.sumiMode
        x: Style.pixelAlignCenter(parent.width, Style.marginXS)
        y: vBottomSection.y - Style.marginM + Style.marginXS / 2
        width: Style.marginXS
        height: Style.marginXS
        color: Qt.rgba(NColor.mOnSurface.r, NColor.mOnSurface.g, NColor.mOnSurface.b, 0.45)
        z: -1
      }

      // Section separators — short horizontal ink rules between the three
      // vertical groups, echoing sumi's ruled-paper motif.
      Rectangle {
        visible: parent.sumiMode && vTopSection.height > 0 && vCenterSection.height > 0
        x: Style.pixelAlignCenter(parent.width, Math.round(parent.width * 0.5))
        y: vTopSection.y + vTopSection.height + Style.marginXS
        width: Math.round(parent.width * 0.5)
        height: Style.borderS
        color: Qt.rgba(NColor.mOnSurface.r, NColor.mOnSurface.g, NColor.mOnSurface.b, 0.18)
        z: -1
      }

      Rectangle {
        visible: parent.sumiMode && vCenterSection.height > 0 && vBottomSection.height > 0
        x: Style.pixelAlignCenter(parent.width, Math.round(parent.width * 0.5))
        y: vBottomSection.y - Style.marginXS - Style.borderS
        width: Math.round(parent.width * 0.5)
        height: Style.borderS
        color: Qt.rgba(NColor.mOnSurface.r, NColor.mOnSurface.g, NColor.mOnSurface.b, 0.18)
        z: -1
      }
    }
  }

  // For horizontal bars
  Component {
    id: horizontalBarComponent
    Item {
      anchors.fill: parent
      clip: true

      // Left edge hot corner - triggers first widget in left section
      MouseArea {
        width: Style.marginS
        height: parent.height
        x: 0
        y: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) {
          if (mouse.button !== Qt.LeftButton) {
            mouse.accepted = true;
            return;
          }
          root.triggerFirstWidgetInSection("left");
        }
      }

      // Right edge hot corner - triggers last widget in right section
      MouseArea {
        width: Style.marginS
        height: parent.height
        anchors.right: parent.right
        y: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) {
          if (mouse.button !== Qt.LeftButton) {
            mouse.accepted = true;
            return;
          }
          root.triggerLastWidgetInSection("right");
        }
      }

      // Calculate margin to center widgets horizontally within the bar height
      readonly property real horizontalBarMargin: Math.round((root.barHeight - root.capsuleHeight) / 2)

      // Left Section
      RowLayout {
        id: leftSection
        objectName: "leftSection"
        anchors.left: parent.left
        anchors.leftMargin: horizontalBarMargin + Settings.data.bar.contentPadding
        y: Style.pixelAlignCenter(parent.height, height)
        spacing: Settings.data.bar.widgetSpacing

        Repeater {
          model: root.leftWidgetsModel
          delegate: BarWidgetLoader {
            required property var model
            required property int index

            widgetId: model.id || ""
            widgetScreen: root.screen
            widgetProps: ({
                            "widgetId": model.id,
                            "section": "left",
                            "sectionWidgetIndex": index,
                            "sectionWidgetsCount": root.leftWidgetsModel.count
                          })
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }

      // Center Section
      RowLayout {
        id: centerSection
        objectName: "centerSection"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Style.pixelAlignCenter(parent.height, height)
        spacing: Settings.data.bar.widgetSpacing

        Repeater {
          model: root.centerWidgetsModel
          delegate: BarWidgetLoader {
            required property var model
            required property int index

            widgetId: model.id || ""
            widgetScreen: root.screen
            widgetProps: ({
                            "widgetId": model.id,
                            "section": "center",
                            "sectionWidgetIndex": index,
                            "sectionWidgetsCount": root.centerWidgetsModel.count
                          })
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }

      // Right Section
      RowLayout {
        id: rightSection
        objectName: "rightSection"
        anchors.right: parent.right
        anchors.rightMargin: horizontalBarMargin + Settings.data.bar.contentPadding
        y: Style.pixelAlignCenter(parent.height, height)
        spacing: Settings.data.bar.widgetSpacing

        Repeater {
          model: root.rightWidgetsModel
          delegate: BarWidgetLoader {
            required property var model
            required property int index

            widgetId: model.id || ""
            widgetScreen: root.screen
            widgetProps: ({
                            "widgetId": model.id,
                            "section": "right",
                            "sectionWidgetIndex": index,
                            "sectionWidgetsCount": root.rightWidgetsModel.count
                          })
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }

      // ---- Section background pills (backgroundStyle === "islands") ----
      // One rounded island behind each section — evokes the multi-island ryoku
      // bars (imi M3, sukunabikona). Only rendered for the "islands" style.
      Rectangle {
        visible: Settings.data.bar.backgroundStyle === "islands" && leftSection.width > 0
        x: leftSection.x - Style.marginXS
        width: leftSection.width + Style.margin2XS
        height: root.capsuleHeight
        y: Style.pixelAlignCenter(parent.height, height)
        radius: Style.radiusS
        color: Qt.rgba(NColor.mSurfaceVariant.r, NColor.mSurfaceVariant.g, NColor.mSurfaceVariant.b, 0.9)
        border.width: Style.borderS
        border.color: Qt.rgba(NColor.mOnSurface.r, NColor.mOnSurface.g, NColor.mOnSurface.b, 0.2)
        z: -1
      }

      Rectangle {
        visible: Settings.data.bar.backgroundStyle === "islands" && centerSection.width > 0
        x: centerSection.x - Style.marginXS
        width: centerSection.width + Style.margin2XS
        height: root.capsuleHeight
        y: Style.pixelAlignCenter(parent.height, height)
        radius: Style.radiusS
        color: Qt.rgba(NColor.mSurfaceVariant.r, NColor.mSurfaceVariant.g, NColor.mSurfaceVariant.b, 0.9)
        border.width: Style.borderS
        border.color: Qt.rgba(NColor.mOnSurface.r, NColor.mOnSurface.g, NColor.mOnSurface.b, 0.2)
        z: -1
      }

      Rectangle {
        visible: Settings.data.bar.backgroundStyle === "islands" && rightSection.width > 0
        x: rightSection.x - Style.marginXS
        width: rightSection.width + Style.margin2XS
        height: root.capsuleHeight
        y: Style.pixelAlignCenter(parent.height, height)
        radius: Style.radiusS
        color: Qt.rgba(NColor.mSurfaceVariant.r, NColor.mSurfaceVariant.g, NColor.mSurfaceVariant.b, 0.9)
        border.width: Style.borderS
        border.color: Qt.rgba(NColor.mOnSurface.r, NColor.mOnSurface.g, NColor.mOnSurface.b, 0.2)
        z: -1
      }

      // ---- Orbit scene chrome (backgroundStyle === "orbit") ----
      readonly property bool orbitMode: Settings.data.bar.backgroundStyle === "orbit"
      // Vertical center of the decorative trajectory line (slightly below middle).
      readonly property real orbitLineY: Math.round(parent.height * 0.56)

      // 1px trajectory hairline spanning the bar, behind all sections.
      Rectangle {
        visible: parent.orbitMode
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        y: parent.orbitLineY
        height: Style.borderS
        color: Qt.rgba(NColor.mOutline.r, NColor.mOutline.g, NColor.mOutline.b, 0.55)
        z: -2
      }

      // Left end dot of the trajectory.
      Rectangle {
        visible: parent.orbitMode
        x: Style.marginM - width / 2
        y: parent.orbitLineY - height / 2 - Style.borderS / 2
        width: Style.marginM + Style.marginXXS   // ~7px scaled
        height: width
        radius: width / 2
        color: NColor.mPrimary
        opacity: 0.8
        z: -2
      }

      // Right end dot of the trajectory.
      Rectangle {
        visible: parent.orbitMode
        x: parent.width - Style.marginM - width / 2
        y: parent.orbitLineY - height / 2 - Style.borderS / 2
        width: Style.marginM + Style.marginXXS
        height: width
        radius: width / 2
        color: NColor.mPrimary
        opacity: 0.8
        z: -2
      }

      // Central clock pill behind the center section (the orbit "clockCore").
      Rectangle {
        visible: parent.orbitMode && centerSection.width > 0
        x: centerSection.x - Style.marginL
        width: centerSection.width + Style.marginL * 2
        height: Math.min(parent.height, root.capsuleHeight + Style.margin2XS)
        y: Style.pixelAlignCenter(parent.height, height)
        radius: height / 2
        color: Qt.rgba(NColor.mSurface.r, NColor.mSurface.g, NColor.mSurface.b, 0.97)
        border.width: Style.borderS
        border.color: Qt.rgba(NColor.mPrimary.r, NColor.mPrimary.g, NColor.mPrimary.b, 0.56)
        z: -1
      }

      // ---- Chroma scene chrome (backgroundStyle === "chroma") ----
      // Chroma's signature: discrete full-height cards floating with gaps,
      // the clock card the only accent-coloured one.
      // Left cluster card (surface).
      Rectangle {
        visible: Settings.data.bar.backgroundStyle === "chroma" && leftSection.width > 0
        x: leftSection.x - Style.marginM
        width: leftSection.width + Style.marginM * 2
        height: parent.height
        radius: Style.radiusXS
        color: Qt.rgba(NColor.mSurfaceVariant.r, NColor.mSurfaceVariant.g, NColor.mSurfaceVariant.b, 0.85)
        z: -1
      }

      // Right cluster card (surface).
      Rectangle {
        visible: Settings.data.bar.backgroundStyle === "chroma" && rightSection.width > 0
        x: rightSection.x - Style.marginM
        width: rightSection.width + Style.marginM * 2
        height: parent.height
        radius: Style.radiusXS
        color: Qt.rgba(NColor.mSurfaceVariant.r, NColor.mSurfaceVariant.g, NColor.mSurfaceVariant.b, 0.85)
        z: -1
      }

      // Clock card — the single accent module (accent(0) = lighter primary).
      Rectangle {
        id: chromaClockCard
        visible: Settings.data.bar.backgroundStyle === "chroma" && centerSection.width > 0
        x: centerSection.x - Style.marginM
        width: centerSection.width + Style.marginM * 2
        height: parent.height
        radius: Style.radiusXS
        // Chroma accent(0). Noctalia's primary is a pale pastel (L~85%):
        // lighten → white, plain darken → gray. Boost saturation + lower L
        // to recreate ryoku's vivid accent from a saturated Material primary.
        color: ColorsConvert.adjustLightnessAndSaturation(NColor.mPrimary.toString(), -22, 45)
        z: -1
      }

      // ---- QS Bar scene chrome (backgroundStyle === "qsbar") ----
      // The band itself lives in BarBackground; the identity here is the
      // ink hairline separators flanking the centre group (paper-and-ink).
      readonly property bool qsbarMode: Settings.data.bar.backgroundStyle === "qsbar"

      Rectangle {
        visible: parent.qsbarMode && centerSection.width > 0 && leftSection.width > 0
        x: centerSection.x - Style.marginM - Style.borderS
        y: Style.pixelAlignCenter(parent.height, Math.round(parent.height * 0.44))
        width: Style.borderS
        height: Math.round(parent.height * 0.44)
        color: Qt.rgba(NColor.mOnSurface.r, NColor.mOnSurface.g, NColor.mOnSurface.b, 0.18)
        z: -1
      }

      Rectangle {
        visible: parent.qsbarMode && centerSection.width > 0 && rightSection.width > 0
        x: centerSection.x + centerSection.width + Style.marginM
        y: Style.pixelAlignCenter(parent.height, Math.round(parent.height * 0.44))
        width: Style.borderS
        height: Math.round(parent.height * 0.44)
        color: Qt.rgba(NColor.mOnSurface.r, NColor.mOnSurface.g, NColor.mOnSurface.b, 0.18)
        z: -1
      }

      // ---- Kairos scene chrome (backgroundStyle === "kairos") ----
      // One morphing island at top-centre: a single tall pill hugging the
      // centre cluster only; left/right groups float bare on the wallpaper.
      // While media plays the island tints to the accent and grows a thin
      // progress bed along its bottom edge — the "morph".
      readonly property bool kairosMode: Settings.data.bar.backgroundStyle === "kairos"
      readonly property color kairosAccent: ColorsConvert.adjustLightnessAndSaturation(NColor.mPrimary.toString(), -22, 45)

      Rectangle {
        id: kairosIsland
        visible: parent.kairosMode && centerSection.width > 0
        x: centerSection.x - Style.marginL
        width: centerSection.width + Style.marginL * 2
        height: parent.height
        radius: Style.radiusM
        color: {
          if (MediaService.isPlaying)
            return Qt.rgba(parent.kairosAccent.r, parent.kairosAccent.g, parent.kairosAccent.b, 0.30);
          return Qt.rgba(NColor.mSurface.r, NColor.mSurface.g, NColor.mSurface.b, 0.92);
        }
        border.width: Style.borderS
        border.color: MediaService.isPlaying ? Qt.rgba(parent.kairosAccent.r, parent.kairosAccent.g, parent.kairosAccent.b, 0.6) : Qt.rgba(NColor.mOutline.r, NColor.mOutline.g, NColor.mOutline.b, 0.5)
        z: -1

        Behavior on color {
          ColorAnimation {
            duration: Style.animationNormal
          }
        }

        // Media progress bed — accent hairline tracking playback position
        Rectangle {
          visible: MediaService.isPlaying && MediaService.trackLength > 0
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.leftMargin: Style.marginM
          anchors.rightMargin: Style.marginM
          height: Style.borderS
          color: Qt.rgba(parent.color.r, parent.color.g, parent.color.b, 0.25)
          radius: Style.borderS

          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.min(1, MediaService.currentPosition / Math.max(1, MediaService.trackLength))
            color: Qt.rgba(kairosIsland.parent.kairosAccent.r, kairosIsland.parent.kairosAccent.g, kairosIsland.parent.kairosAccent.b, 1)
            radius: Style.borderS
          }
        }
      }
    }
  }
}
