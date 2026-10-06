// MacBarModel.js - Mac-style menu bar logic

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons

function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value)
}

function normalizePosition(value) {
  var next = String(value || "").trim()
  return /^(top|bottom|left|right)$/.test(next) ? next : "top"
}

function entrySettings(entry) {
  if (!isPlainObject(entry)) return {}
  var copy = {}
  for (var key in entry) {
    if (key === "id") continue
    copy[key] = entry[key]
  }
  return copy
}

function entryId(entry) {
  if (typeof entry === "string") return entry
  if (isPlainObject(entry)) {
    var id = entry["id"]
    if (id !== undefined && id !== null && String(id) !== "") return String(id)
  }
  return ""
}

// Mac-style bar sections
function buildMacBarLayout(config) {
  var layout = config && config.layout ? config.layout : {}
  var left = Array.isArray(layout.left) ? layout.left : []
  var center = Array.isArray(layout.center) ? layout.center : []
  var right = Array.isArray(layout.right) ? layout.right : []

  // Ensure tray is on the inner edge of right section
  right = pinTrayToInner(right, "right")

  return { left: left, center: center, right: right }
}

function pinTrayToInner(entries, section) {
  var trayEntry = null
  var result = []
  var values = Array.isArray(entries) ? entries : []
  for (var i = 0; i < values.length; i++) {
    if (entryId(values[i]) === "omarchy.tray") trayEntry = values[i]
    else result.push(values[i])
  }
  if (trayEntry) {
    if (section === "right") result.unshift(trayEntry)
    else result.push(trayEntry)
  }
  return result
}

function customModuleType(entry) {
  var id = entryId(entry)
  return id.startsWith("omarchy.") === false && id !== ""
}

var MacBarModel = {
  isPlainObject: isPlainObject,
  normalizePosition: normalizePosition,
  entrySettings: entrySettings,
  entryId: entryId,
  buildMacBarLayout: buildMacBarLayout,
  pinTrayToInner: pinTrayToInner,
  customModuleType: customModuleType,
}

export default MacBarModel