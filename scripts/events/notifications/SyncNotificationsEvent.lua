SyncNotificationsEvent = {}
local SyncNotificationsEvent_mt = Class(SyncNotificationsEvent, Event)

InitEventClass(SyncNotificationsEvent, "SyncNotificationsEvent")

function SyncNotificationsEvent.emptyNew()
  local self = Event.new(SyncNotificationsEvent_mt)
  return self
end

function SyncNotificationsEvent.new(notifications, nextId)
  local self = SyncNotificationsEvent.emptyNew()
  self.notifications = notifications
  self.nextId = nextId

  return self
end

function SyncNotificationsEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.nextId or 1)

  local count = table.size(self.notifications)
  streamWriteInt32(streamId, count)

  for _, notification in pairs(self.notifications) do
    notification:writeStream(streamId)
  end
end

function SyncNotificationsEvent:readStream(streamId, connection)
  self.nextId = streamReadInt32(streamId)
  local count = streamReadInt32(streamId)

  self.notifications = {}

  for i = 1, count do
    local notification = Notification.newFromStream(streamId)
    self.notifications[notification.id] = notification
  end

  self:run(connection)
end

function SyncNotificationsEvent:run(connection)
  local notificationManager = g_currentMission.CustomContracts.NotificationManager
  if notificationManager == nil then
    return
  end

  notificationManager.notifications = self.notifications
  notificationManager.nextId = self.nextId

  g_messageCenter:publish(MessageType.NOTIFICATIONS_UPDATED)
end
