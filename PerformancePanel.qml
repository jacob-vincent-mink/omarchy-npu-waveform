import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  required property var hostWidget
  required property Item anchorItem
  moduleName: "jacob.npu"
  manageIpc: false
  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget
    bar: root.bar
    open: root.opened
    focusTarget: content
    contentWidth: fittedContentWidth(Style.space(440))
    contentHeight: fittedContentHeight(content.implicitHeight)
    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: content.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      PerformanceContent {
        id: content
        width: parent.width
        hostWidget: root.hostWidget
        onCloseRequested: root.close()
      }
    }
  }
}
