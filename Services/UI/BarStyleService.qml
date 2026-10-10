pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// Sistema de estilos (presets) de barra.
// Um estilo é um snapshot parcial de Settings.data.bar (knobs de aparência +
// layout de widgets). Aplicar um estilo grava os knobs e dá bump em
// BarService.widgetsRevision para a bar re-renderizar.
Singleton {
  id: root

  // Id do estilo ativo (persistido em Settings.data.bar.activeStyle)
  readonly property string activeStyle: Settings.data.bar.activeStyle || "default"

  // --- Estilos built-in ------------------------------------------------------
  // settings: apenas os knobs que o estilo controla. Chaves ausentes mantêm o
  // valor atual. "widgets" (left/center/right) é aplicado como um bloco.
  readonly property var builtInStyles: [
    {
      "id": "default",
      "name": "Padrão",
      "icon": "layout-2",
      "description": "Layout clássico do Noctalia: barra no topo, cápsula nos widgets.",
      "settings": {
        "barType": "simple",
        "backgroundStyle": "strip",
        "position": "top",
        "density": "default",
        "showCapsule": true,
        "showOutline": false,
        "showBarOutline": true,
        "useGradient": true,
        "backgroundOpacity": 0.93,
        "widgetSpacing": 6,
        "contentPadding": 2
      }
    },
    {
      "id": "floating",
      "name": "Flutuante",
      "icon": "stack-2",
      "description": "Barra flutuante com margens e cantos arredondados.",
      "settings": {
        "barType": "floating",
        "backgroundStyle": "strip",
        "position": "top",
        "density": "compact",
        "showCapsule": true,
        "showOutline": false,
        "showBarOutline": true,
        "useGradient": true,
        "backgroundOpacity": 0.85,
        "marginVertical": 8,
        "marginHorizontal": 12,
        "widgetSpacing": 6
      }
    },
    {
      "id": "minimal",
      "name": "Mínimo",
      "icon": "minus",
      "description": "Barra enxuta, sem cápsula, widgets essenciais.",
      "settings": {
        "barType": "simple",
        "backgroundStyle": "strip",
        "position": "top",
        "density": "mini",
        "showCapsule": false,
        "showOutline": false,
        "showBarOutline": false,
        "useGradient": false,
        "backgroundOpacity": 0.98,
        "widgetSpacing": 10,
        "contentPadding": 4,
        "widgets": {
          "left": [{ "id": "Launcher" }, { "id": "ActiveWindow" }],
          "center": [{ "id": "Clock" }],
          "right": [{ "id": "Tray" }, { "id": "Volume" }, { "id": "Battery" }]
        }
      }
    },
    {
      "id": "framed",
      "name": "Emoldurado",
      "icon": "crop-landscape",
      "description": "Barra com moldura (frame) emoldurada nas bordas.",
      "settings": {
        "barType": "framed",
        "backgroundStyle": "strip",
        "position": "top",
        "density": "default",
        "showCapsule": true,
        "showOutline": true,
        "showBarOutline": true,
        "useGradient": true,
        "backgroundOpacity": 0.93,
        "frameThickness": 8,
        "frameRadius": 12,
        "outerCorners": true
      }
    },
    {
      "id": "vertical",
      "name": "Vertical",
      "icon": "arrow-bar-left",
      "description": "Barra vertical na borda esquerda.",
      "settings": {
        "barType": "floating",
        "backgroundStyle": "strip",
        "position": "left",
        "density": "compact",
        "showCapsule": true,
        "showOutline": false,
        "showBarOutline": true,
        "useGradient": false,
        "backgroundOpacity": 0.88,
        "marginVertical": 12,
        "marginHorizontal": 8
      }
    },
    {
      "id": "ryoku",
      "name": "Ryoku",
      "icon": "layout-board",
      "description": "Inspirado na barra do Ryoku: minimalista, workspaces ao centro.",
      "settings": {
        "barType": "floating",
        "backgroundStyle": "strip",
        "position": "top",
        "density": "compact",
        "showCapsule": false,
        "showOutline": false,
        "showBarOutline": true,
        "useGradient": false,
        "backgroundOpacity": 0.82,
        "widgetSpacing": 4,
        "contentPadding": 4,
        "marginVertical": 6,
        "marginHorizontal": 10,
        "widgets": {
          "left": [{ "id": "Launcher" }, { "id": "ActiveWindow" }],
          "center": [{ "id": "Workspace" }],
          "right": [{ "id": "Tray" }, { "id": "NotificationHistory" }, { "id": "MediaMini" }, { "id": "Volume" }, { "id": "Battery" }, { "id": "ControlCenter" }]
        }
      }
    },
    {
      "id": "orbit",
      "name": "Orbit",
      "icon": "circle",
      "description": "Ryoku Orbit: linha-trajetória com pontos, pílula central do relógio, widgets nus.",
      "settings": {
        "barType": "floating",
        "position": "top",
        "density": "default",
        "backgroundStyle": "orbit",
        "showCapsule": false,
        "showOutline": false,
        "showBarOutline": false,
        "useGradient": false,
        "backgroundOpacity": 0.55,
        "widgetSpacing": 22,
        "contentPadding": 10,
        "marginVertical": 10,
        "marginHorizontal": 26,
        "widgets": {
          "left": [{ "id": "Workspace" }],
          "center": [{ "id": "Clock" }],
          "right": [{ "id": "Volume" }, { "id": "Battery" }]
        }
      }
    },
    {
      "id": "chroma",
      "name": "Chroma",
      "icon": "grid-3x3",
      "description": "Ryoku Chroma: módulos discretos flutuando, um cartão de acento no relógio.",
      "settings": {
        "barType": "floating",
        "position": "top",
        "density": "comfortable",
        "backgroundStyle": "chroma",
        "showCapsule": false,
        "showOutline": false,
        "showBarOutline": false,
        "useGradient": false,
        "backgroundOpacity": 0.88,
        "widgetSpacing": 6,
        "contentPadding": 8,
        "marginVertical": 8,
        "marginHorizontal": 14,
        "widgets": {
          "left": [{ "id": "Launcher" }, { "id": "Workspace" }],
          "center": [{ "id": "Clock" }],
          "right": [{ "id": "MediaMini" }, { "id": "Volume" }, { "id": "Battery" }, { "id": "ControlCenter" }]
        }
      }
    },
    {
      "id": "islands",
      "name": "Ilhas",
      "icon": "columns-2",
      "description": "Três pílulas de seção separadas (esquerda, centro, direita), estilo Material.",
      "settings": {
        "barType": "floating",
        "position": "top",
        "density": "default",
        "backgroundStyle": "islands",
        "showCapsule": false,
        "showOutline": false,
        "showBarOutline": false,
        "useGradient": false,
        "backgroundOpacity": 0.92,
        "widgetSpacing": 6,
        "contentPadding": 4,
        "marginVertical": 6,
        "marginHorizontal": 8,
        "widgets": {
          "left": [{ "id": "Launcher" }, { "id": "ActiveWindow" }],
          "center": [{ "id": "Clock" }],
          "right": [{ "id": "Tray" }, { "id": "Volume" }, { "id": "Battery" }]
        }
      }
    }
  ]

  // Estilos salvos pelo usuário (em Settings.data.bar.customStyles)
  readonly property var customStyles: Settings.data.bar.customStyles || []

  // Todos os estilos visíveis na UI (built-in + custom)
  readonly property var allStyles: builtInStyles.concat(customStyles)

  function styleById(id) {
    var list = allStyles;
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return list[i];
      }
    }
    return null;
  }

  function isCustom(id) {
    var list = customStyles;
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return true;
      }
    }
    return false;
  }

  // Aplica um estilo pelos knobs declarados. Chaves fora de "widgets" são
  // atribuídas direto; "widgets" é gravado por seção.
  function applyStyle(id) {
    var style = styleById(id);
    if (!style) {
      return;
    }
    var s = style.settings || {};

    for (var key in s) {
      if (key === "widgets") {
        continue;
      }
      // Só grava knobs que existem no adapter (evita criar chaves órfãs)
      if (Settings.data.bar[key] !== undefined) {
        Settings.data.bar[key] = s[key];
      }
    }

    if (s.widgets) {
      if (s.widgets.left) {
        Settings.data.bar.widgets.left = s.widgets.left;
      }
      if (s.widgets.center) {
        Settings.data.bar.widgets.center = s.widgets.center;
      }
      if (s.widgets.right) {
        Settings.data.bar.widgets.right = s.widgets.right;
      }
    }

    Settings.data.bar.activeStyle = id;
    BarService.widgetsRevision++;
  }

  // Salva os knobs + layout ATUAIS como um novo estilo customizado.
  function saveCurrentAsStyle(name) {
    var id = "custom-" + Date.now();
    var snapshot = {
      "barType": Settings.data.bar.barType,
      "position": Settings.data.bar.position,
      "density": Settings.data.bar.density,
      "showCapsule": Settings.data.bar.showCapsule,
      "showOutline": Settings.data.bar.showOutline,
      "showBarOutline": Settings.data.bar.showBarOutline,
      "useGradient": Settings.data.bar.useGradient,
      "backgroundStyle": Settings.data.bar.backgroundStyle,
      "backgroundOpacity": Settings.data.bar.backgroundOpacity,
      "widgetSpacing": Settings.data.bar.widgetSpacing,
      "contentPadding": Settings.data.bar.contentPadding,
      "marginVertical": Settings.data.bar.marginVertical,
      "marginHorizontal": Settings.data.bar.marginHorizontal,
      "frameThickness": Settings.data.bar.frameThickness,
      "frameRadius": Settings.data.bar.frameRadius,
      "outerCorners": Settings.data.bar.outerCorners,
      "widgets": {
        "left": Settings.data.bar.widgets.left,
        "center": Settings.data.bar.widgets.center,
        "right": Settings.data.bar.widgets.right
      }
    };
    var newStyle = {
      "id": id,
      "name": name || ("Estilo " + (customStyles.length + 1)),
      "icon": "bookmark",
      "description": "Estilo salvo por você.",
      "settings": snapshot
    };

    var list = customStyles.slice();
    list.push(newStyle);
    Settings.data.bar.customStyles = list;
    Settings.data.bar.activeStyle = id;
    BarService.widgetsRevision++;
  }

  // Remove um estilo customizado. Não remove built-ins.
  function deleteStyle(id) {
    if (!isCustom(id)) {
      return;
    }
    var list = customStyles.filter(function (s) {
      return s.id !== id;
    });
    Settings.data.bar.customStyles = list;
    if (activeStyle === id) {
      Settings.data.bar.activeStyle = "default";
    }
  }
}
