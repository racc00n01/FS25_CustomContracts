--
-- Dialog that shows the ingame map in a window. User clicks on the map to pick
-- a destination (world X, Z). Uses InGameMapPreview and the same ingame map as the HUD.
--

PickDestinationMapDialog = {}
local PickDestinationMapDialog_mt = Class(PickDestinationMapDialog, MessageDialog)
local modDirectory = g_currentModDirectory

function PickDestinationMapDialog.register()
  local dialog = PickDestinationMapDialog.new()
  g_gui:loadGui(modDirectory .. "gui/dialog/contracts/PickDestinationMapDialog.xml", "pickDestinationMapDialog", dialog)
  PickDestinationMapDialog.INSTANCE = dialog
end

--- @param callback function(success, worldX, worldZ) called when user picks or cancels
function PickDestinationMapDialog.show(callback)
  if PickDestinationMapDialog.INSTANCE == nil then
    PickDestinationMapDialog.register()
  end
  local dialog = PickDestinationMapDialog.INSTANCE
  dialog.pendingCallback = callback
  -- Set map on preview BEFORE showDialog so the first draw/mouseEvent (which can run before onOpen) have valid ingameMap

  if dialog.mapPreview then
    dialog.mapPreview.drawHotspots = true
    dialog.mapPreview:setIngameMap(g_currentMission.hud:getIngameMap())
  end
  g_gui:showDialog("pickDestinationMapDialog")
end

function PickDestinationMapDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or PickDestinationMapDialog_mt)
  self.pendingCallback = nil
  self.aiTargetMapHotspot = AITargetHotspot.new()
  self.hotspotLocked = false
  self.mapCenterWorldX = 0
  self.mapCenterWorldZ = 0
  self.panInputDown = false
  self.panStartScreenX = 0
  self.panStartScreenY = 0
  self.lastMousePosX = 0
  self.lastMousePosY = 0
  self.hasDragged = false
  self.minDragDistanceX = 5
  self.minDragDistanceY = 5
  return self
end

function PickDestinationMapDialog:onCreate()
  PickDestinationMapDialog:superClass().onCreate(self)
end

function PickDestinationMapDialog:onOpen()
  self.mapPreview:setIngameMap(g_currentMission.hud:getIngameMap())

  self.mapPreview.drawHotspots = true

  self.aiTargetMapHotspot = AITargetHotspot.new()

  if g_currentMission.controlledVehicle then
    local x, _, z = getWorldTranslation(g_currentMission.controlledVehicle.rootNode)
    self.mapPreview:setCenterToWorldPosition(x, z)
    self.mapCenterWorldX, self.mapCenterWorldZ = x, z
  elseif g_currentMission.player then
    local x, _, z = getWorldTranslation(g_currentMission.player.rootNode)
    self.mapPreview:setCenterToWorldPosition(x, z)
    self.mapCenterWorldX, self.mapCenterWorldZ = x, z
  else
    self.mapPreview:setCenterToWorldPosition(0, 0)
    self.mapCenterWorldX, self.mapCenterWorldZ = 0, 0
  end

  local posStartX = self.mapPreview.absPosition[1]
  local posStartY = self.mapPreview.absPosition[2]
  local posEndX = posStartX + self.mapPreview.absSize[1]
  local posEndY = posStartY + self.mapPreview.absSize[2]
  self.mapPreview.ingameMap:setMapClipArea(posStartX, posStartY, posEndX, posEndY)
  self.mapPreview.ingameMap.clipHotspots = true

  g_currentMission:addMapHotspot(self.aiTargetMapHotspot)
end

function PickDestinationMapDialog:onClose()
  PickDestinationMapDialog:superClass().onClose(self)
  g_currentMission.hud:getIngameMap():setCustomLayout(nil)
  g_currentMission.hud:getIngameMap().clipHotspots = false
  g_currentMission.hud:getIngameMap():setMapClipArea(nil, nil, nil, nil)
  g_currentMission:removeMapHotspot(self.aiTargetMapHotspot)
  self.aiTargetMapHotspot = nil
  self.hotspotLocked = false
  -- self.aiTargetMapHotspot:delete()
  g_inputBinding:setShowMouseCursor(true)
end

function PickDestinationMapDialog:closeWithResult(success, worldX, worldZ)
  if self.pendingCallback then
    self.pendingCallback(success, worldX, worldZ)
  end
  g_inputBinding:setShowMouseCursor(true)
  self:close()
end

-- function PickDestinationMapDialog:update(dt)
--   print("update", self.mapPreview.ingameMap:getLocalPointerTarget())
--   -- self.aiTargetMapHotspot:setWorldPosition(self.mapPreview:getLocalPointerTarget())
-- end

--- Convert screen position to world X,Z. Uses the layout's actual map rect (getMapPosition/getMapSize)
-- so the conversion matches how hotspots are drawn; avoids offset when the map is letterboxed.
function PickDestinationMapDialog:screenToWorld(screenX, screenY)
  local el = self.mapPreview
  if el == nil or el.layout == nil or el.ingameMap == nil then
    return nil, nil
  end
  local layout = el.layout
  local ingameMap = el.ingameMap

  local mapX, mapY = layout:getMapPosition()
  local mapWidth, mapHeight = layout:getMapSize()
  if mapWidth <= 0 or mapHeight <= 0 then
    return nil, nil
  end
  local scaleFactor = ingameMap.mapExtensionScaleFactor
  if scaleFactor == nil or scaleFactor == 0 then
    return nil, nil
  end

  -- Mouse position -> texture coords (same convention as IngameMap.drawHotspot + getMapObjectPosition)
  local objectU = (screenX - mapX) / mapWidth
  local objectV = 1 - (screenY - mapY) / mapHeight

  -- Texture coords -> world (inverse of drawHotspot's world -> objectX/objectZ)
  local worldX = (objectU - ingameMap.mapExtensionOffsetX) / scaleFactor * ingameMap.worldSizeX -
      ingameMap.worldCenterOffsetX
  local worldZ = (objectV - ingameMap.mapExtensionOffsetZ) / scaleFactor * ingameMap.worldSizeZ -
      ingameMap.worldCenterOffsetZ

  return worldX, worldZ
end

function PickDestinationMapDialog:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
  if eventUsed then
    return PickDestinationMapDialog:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
  end

  local mapPreview = self.mapPreview
  local onMap = mapPreview and mapPreview:getIsVisible() and
      posX >= mapPreview.absPosition[1] and posX <= mapPreview.absPosition[1] + mapPreview.absSize[1] and
      posY >= mapPreview.absPosition[2] and posY <= mapPreview.absPosition[2] + mapPreview.absSize[2]

  -- Left button down on map: start tracking (possible pan or click)
  if isDown and button == Input.MOUSE_BUTTON_LEFT and onMap then
    self.panInputDown = true
    self.panStartScreenX = posX
    self.panStartScreenY = posY
    self.lastMousePosX = posX
    self.lastMousePosY = posY
    self.hasDragged = false
  end

  -- Mouse move while left button down: maybe pan
  if self.panInputDown and mapPreview and mapPreview.ingameMap then
    local distX = posX - self.panStartScreenX
    local distY = posY - self.panStartScreenY
    local minPxX = self.minDragDistanceX * g_pixelSizeX
    local minPxY = self.minDragDistanceY * g_pixelSizeY

    if math.abs(distX) > minPxX or math.abs(distY) > minPxY then
      self.hasDragged = true
    end

    if self.hasDragged then
      local layout = mapPreview.layout
      local ingameMap = mapPreview.ingameMap
      local mapWidth, mapHeight = layout:getMapSize()
      local scale = ingameMap.mapExtensionScaleFactor
      if mapWidth > 0 and mapHeight > 0 and scale and scale ~= 0 then
        local dx = posX - self.lastMousePosX
        local dy = posY - self.lastMousePosY
        -- +dx: drag left -> center decreases -> map content moves right (correct)
        local centerDeltaX = -dx * ingameMap.worldSizeX / (mapWidth * scale)
        local centerDeltaZ = dy * ingameMap.worldSizeZ / (mapHeight * scale)
        self.mapCenterWorldX = self.mapCenterWorldX + centerDeltaX
        self.mapCenterWorldZ = self.mapCenterWorldZ + centerDeltaZ
        self.mapPreview:setCenterToWorldPosition(self.mapCenterWorldX, self.mapCenterWorldZ)
      end
      self.lastMousePosX = posX
      self.lastMousePosY = posY
    end
  end

  -- Left button up: end pan/click, maybe lock hotspot
  if isUp and button == Input.MOUSE_BUTTON_LEFT then
    if self.panInputDown and onMap and not self.hasDragged then
      local worldX, worldZ = self:screenToWorld(posX, posY)
      if worldX ~= nil and worldZ ~= nil then
        self.pickedWorldX = worldX
        self.pickedWorldZ = worldZ
        self.hotspotLocked = true
        if self.aiTargetMapHotspot then
          self.aiTargetMapHotspot:setWorldPosition(worldX, worldZ)
        end
        self.panInputDown = false
        self.hasDragged = false
        return true
      end
    end
    self.panInputDown = false
    self.hasDragged = false
  end

  -- Update hotspot to follow mouse only when not locked and not dragging
  local skipHotspotUpdate = self.panInputDown and self.hasDragged
  if not self.hotspotLocked and not skipHotspotUpdate and mapPreview and mapPreview.ingameMap and self.aiTargetMapHotspot then
    local worldX, worldZ = self:screenToWorld(posX, posY)
    if worldX ~= nil and worldZ ~= nil then
      self.aiTargetMapHotspot:setWorldPosition(worldX, worldZ)
    end
  end

  return PickDestinationMapDialog:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function PickDestinationMapDialog:onSubmit()
  print("onSubmit", self.pickedWorldX, self.pickedWorldZ)
  self:closeWithResult(true, self.pickedWorldX, self.pickedWorldZ)
end

function PickDestinationMapDialog:onCancel()
  self:closeWithResult(false, nil, nil)
end
