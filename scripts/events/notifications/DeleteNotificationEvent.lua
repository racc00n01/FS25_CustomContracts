--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

DeleteNotificationEvent = {}
local DeleteNotificationEvent_mt = Class(DeleteNotificationEvent, Event)

InitEventClass(DeleteNotificationEvent, "DeleteNotificationEvent")

function DeleteNotificationEvent.emptyNew()
  local self = Event.new(DeleteNotificationEvent_mt)
  return self
end

function DeleteNotificationEvent.new(notificationId)
  local self = DeleteNotificationEvent.emptyNew()
  self.notificationId = notificationId
  return self
end

function DeleteNotificationEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.notificationId)
end

function DeleteNotificationEvent:readStream(streamId, connection)
  self.notificationId = streamReadInt32(streamId)
  self:run(connection)
end

function DeleteNotificationEvent:run(connection)
  if not connection:getIsServer() then
    g_server:broadcastEvent(DeleteNotificationEvent.new(self.notificationId))
  end

  local notificationManager = g_currentMission.CustomContracts.NotificationManager
  notificationManager:removeNotification(self.notificationId)
end
