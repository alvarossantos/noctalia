import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NText {
    text: I18n.tr("panels.bar.styles-description")
    color: NColor.mOnSurfaceVariant
    pointSize: Style.fontSizeS
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  Flow {
    Layout.fillWidth: true
    spacing: Style.marginM

    Repeater {
      model: BarStyleService.allStyles

      delegate: Item {
        id: card
        required property var modelData
        width: 210
        height: 130

        readonly property bool isActive: BarStyleService.activeStyle === modelData.id
        readonly property bool isCustom: BarStyleService.isCustom(modelData.id)

        Rectangle {
          anchors.fill: parent
          radius: Style.iRadiusM
          color: NColor.mSurfaceVariant
          border.width: card.isActive ? 2 : 1
          border.color: card.isActive ? NColor.mPrimary : NColor.smartAlpha(NColor.mOnSurface, 0.15)

          Behavior on border.color {
            ColorAnimation {
              duration: Style.animationFast
            }
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginXS

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NIcon {
                icon: card.modelData.icon || "layout-2"
                pointSize: Style.fontSizeL
                color: card.isActive ? NColor.mPrimary : NColor.mOnSurface
              }

              NText {
                text: card.modelData.name
                color: NColor.mOnSurface
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
                Layout.fillWidth: true
                elide: Text.ElideRight
              }

              Rectangle {
                visible: card.isCustom
                radius: height / 2
                color: NColor.smartAlpha(NColor.mPrimary, 0.2)
                implicitWidth: customLabel.implicitWidth + Style.marginS * 2
                implicitHeight: customLabel.implicitHeight + 2

                NText {
                  id: customLabel
                  anchors.centerIn: parent
                  text: I18n.tr("common.custom")
                  color: NColor.mPrimary
                  pointSize: Style.fontSizeXS
                }
              }
            }

            NText {
              text: card.modelData.description || ""
              color: NColor.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
              Layout.fillHeight: true
              verticalAlignment: Text.AlignTop
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NButton {
                Layout.fillWidth: true
                text: card.isActive ? I18n.tr("common.applied") : I18n.tr("common.apply")
                icon: card.isActive ? "check" : "palette"
                outlined: !card.isActive
                enabled: !card.isActive
                onClicked: BarStyleService.applyStyle(card.modelData.id)
              }

              NIconButton {
                visible: card.isCustom
                icon: "trash"
                tooltipText: I18n.tr("common.delete")
                onClicked: BarStyleService.deleteStyle(card.modelData.id)
              }
            }
          }
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NTextInput {
      id: newNameInput
      Layout.fillWidth: true
      label: I18n.tr("panels.bar.styles-save-label")
      description: I18n.tr("panels.bar.styles-save-description")
      placeholderText: I18n.tr("panels.bar.styles-save-placeholder")
      onAccepted: root.saveCurrent()
    }

    NButton {
      text: I18n.tr("common.save")
      icon: "device-floppy"
      enabled: newNameInput.text.length > 0
      onClicked: root.saveCurrent()
    }
  }

  function saveCurrent() {
    if (newNameInput.text.length === 0) {
      return;
    }
    BarStyleService.saveCurrentAsStyle(newNameInput.text);
    newNameInput.text = "";
  }
}
