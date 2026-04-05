Notification = {}
Notification.dir = g_currentModDirectory
Notification.modName = g_currentModName
Notification.__index = Notification
Notification_mt = Class(Notification)

Notification.TYPE = {
  INFO = "info",
  WARNING = "warning",
  ERROR = "error",
}

function Notification.new(id, message, type, date, farmId)
  local self = setmetatable({}, Notification_mt)

  self.id = id
  self.message = message
  self.type = type
  self.date = date
  self.farmId = farmId

  return self
end

function Notification:writeStream(streamId)
  streamWriteInt32(streamId, self.id)
  streamWriteString(streamId, self.message)
  streamWriteString(streamId, self.type)
  streamWriteInt32(streamId, self.date)
  streamWriteInt32(streamId, self.farmId)
end

function Notification.newFromStream(streamId)
  local id = streamReadInt32(streamId)
  local message = streamReadString(streamId)
  local type = streamReadString(streamId)
  local date = streamReadInt32(streamId)
  local farmId = streamReadInt32(streamId)

  return Notification.new(id, message, type, date, farmId)
end

function Notification:getMessage()
  return self.message
end
