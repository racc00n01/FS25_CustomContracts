SyncFarmAccessEvent = {}
local SyncFarmAccessEvent_mt = Class(SyncFarmAccessEvent, Event)

InitEventClass(SyncFarmAccessEvent, "SyncFarmAccessEvent")

function SyncFarmAccessEvent.emptyNew()
  local self = Event.new(SyncFarmAccessEvent_mt)
  return self
end

function SyncFarmAccessEvent.new(access, nextId)
  local self = SyncFarmAccessEvent.emptyNew()
  self.access = access
  self.nextId = nextId

  return self
end

function SyncFarmAccessEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.nextId)

  local count = table.size(self.access)
  streamWriteInt32(streamId, count)

  for _, access in pairs(self.access) do
    access:writeStream(streamId)
  end
end

function SyncFarmAccessEvent:readStream(streamId, connection)
  self.nextId = streamReadInt32(streamId)
  local count = streamReadInt32(streamId)

  self.access = {}

  for i = 1, count do
    local access = FarmAccess.newFromStream(streamId)
    self.access[access.id] = access
  end

  self:run(connection)
end

function SyncFarmAccessEvent:run(connection)
  local farmAccessManager = g_currentMission.CustomContracts.FarmAccessManager
  if farmAccessManager == nil then
    return
  end

  farmAccessManager.access = self.access
  farmAccessManager.nextId = self.nextId

  g_messageCenter:publish(MessageType.FARM_ACCESS_UPDATED)
end
