import QtQuick
import qs.Commons
import qs.Services.UI

/**
* BarNotch - QS Bar scene notch
*
* Paper bump protruding below the band at screen centre, where the clock
* sits — the qsbar silhouette. Drawn in the same render layer as the strip,
* behind it, only for backgroundStyle === "qsbar" on horizontal bars.
*/
Rectangle {
  id: root

  required property var bar
  required property var windowRoot
  required property color backgroundColor

  readonly property bool _enabled: Settings.data.bar.backgroundStyle === "qsbar" && Settings.data.bar.barType !== "framed"
  readonly property string _position: Settings.getBarPositionForScreen(windowRoot?.screen?.name)
  readonly property bool _atTop: _position === "top"
  readonly property bool _atBottom: _position === "bottom"
  readonly property real _screenW: windowRoot?.screen?.width || 0
  readonly property real _barH: bar ? bar.height : 0
  readonly property bool _show: _enabled && (_atTop || _atBottom) && bar && BarService.effectivelyVisible && _barH > 0

  visible: _show
  x: Math.round(_screenW / 2 - width / 2)
  y: _atTop ? (bar.y + _barH - 1) : (bar.y - height + 1)
  width: Math.round(_barH * 2.4)
  height: Math.round(_barH * 0.5)
  radius: Style.radiusS
  color: Qt.rgba(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a)
  opacity: (bar && bar.isHidden) ? 0 : 1
  z: -1 // behind the strip's ShapePath fill

  Behavior on opacity {
    enabled: bar && bar.autoHide
    NumberAnimation {
      duration: Style.animationFast
      easing.type: Easing.OutQuad
    }
  }
}
