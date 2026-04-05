NotificationManager = {}
NotificationManager_mt = Class(NotificationManager)
NotificationManager.dir = g_currentModDirectory
NotificationManager.modName = g_currentModName

function NotificationManager.new()
  local self = setmetatable({}, NotificationManager_mt)

  print("NotificationManager.new")

  self.notifications = {}
  self.nextId = 1

  if g_currentMission:getIsServer() then
    g_messageCenter:subscribe(
      MessageType.PLAYER_CONNECTED,
      self.onPlayerConnected,
      self
    )
  end

  return self
end

function NotificationManager:saveToXmlFile(xmlFile)
  if not g_currentMission:getIsServer() then return end

  local key = CustomContracts.SaveKey
  local count = 0

  for _, notification in pairs(self.notifications) do
    local notKey = string.format("%s.notification(%d)", key, count)

    setXMLInt(xmlFile, notKey .. "#id", notification.id)
    setXMLString(xmlFile, notKey .. "#message", notification.message)
    setXMLString(xmlFile, notKey .. "#type", notification.type)
    setXMLInt(xmlFile, notKey .. "#date", notification.date)
    setXMLInt(xmlFile, notKey .. "#farmId", notification.farmId)

    count = count + 1
  end
end

function NotificationManager:loadFromXmlFile(xmlFile)
  if not g_currentMission:getIsServer() then return end

  self.notifications = {}
  self.nextId = 1

  local key = CustomContracts.SaveKey
  local i = 0

  while true do
    local notKey = string.format("%s.notification(%d)", key, i)
    if not hasXMLProperty(xmlFile, notKey) then
      break
    end

    local id = getXMLInt(xmlFile, notKey .. "#id")
    local message = getXMLString(xmlFile, notKey .. "#message")
    local type = getXMLString(xmlFile, notKey .. "#type")
    local date = getXMLInt(xmlFile, notKey .. "#date")
    local farmId = getXMLInt(xmlFile, notKey .. "#farmId")

    local notification = Notification.new(id, message, type, date, farmId)

    self.notifications[id] = notification
    self.nextId = math.max(self.nextId or 1, id + 1)

    i = i + 1
  end

  self:syncNotifications()
end

function NotificationManager:writeInitialClientState(streamId, connection)
  streamWriteInt32(streamId, self.nextId)

  local count = table.size(self.notifications)
  streamWriteInt32(streamId, count)

  for _, notification in pairs(self.notifications) do
    notification:writeStream(streamId)
  end
end

function NotificationManager:readInitialClientState(streamId, connection)
  self.notifications = {}

  self.nextId = streamReadInt32(streamId)
  local count = streamReadInt32(streamId)

  for i = 1, count do
    local notification = Notification.newFromStream(streamId)
    self.notifications[notification.id] = notification
  end

  g_messageCenter:publish(MessageType.NOTIFICATIONS_UPDATED)
end

function NotificationManager:syncNotifications(connection)
  if not g_currentMission:getIsServer() then return end

  local event = SyncNotificationsEvent.new(self.notifications, self.nextId)

  if connection ~= nil then
    connection:sendEvent(event)
  else
    g_server:broadcastEvent(event, true)
  end
end

function NotificationManager:onPlayerConnected(connection)
  if not g_currentMission:getIsServer() then return end
  if connection == nil then return end

  self:syncNotifications(connection)
end

function NotificationManager:getNotificationsByCurrentFarm()
  local notifications = {}

  local farmId = g_currentMission:getFarmId()

  for _, notification in pairs(self.notifications) do
    if notification.farmId == farmId then
      table.insert(notifications, notification)
    end
  end

  table.sort(notifications, function(a, b)
    return a.date > b.date
  end)

  return notifications
end

function NotificationManager:addNotification(message, type, farmId)
  if not g_currentMission:getIsServer() then return end

  local notification = Notification.new(self.nextId, message, type, g_currentMission.environment.dayTime, farmId)
  self.notifications[notification.id] = notification
  self.nextId = self.nextId + 1

  self:syncNotifications()
end

function NotificationManager:removeNotification(id)
  if not g_currentMission:getIsServer() then return end

  self.notifications[id] = nil
  self:syncNotifications()
end
