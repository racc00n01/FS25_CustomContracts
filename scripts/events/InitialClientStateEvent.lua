InitialClientStateEvent = {}
local InitialClientStateEvent_mt = Class(InitialClientStateEvent, Event)

InitEventClass(InitialClientStateEvent, "InitialClientStateEvent")

function InitialClientStateEvent.emptyNew()
  return Event.new(InitialClientStateEvent_mt)
end

function InitialClientStateEvent.new()
  return InitialClientStateEvent.emptyNew()
end

function InitialClientStateEvent:writeStream(streamId, connection)
  local contractManager = g_currentMission.customContracts.ContractManager

  contractManager:writeInitialClientState(streamId, connection)
end

function InitialClientStateEvent:readStream(streamId, connection)
  local contractManager = g_currentMission.customContracts.ContractManager

  contractManager:readInitialClientState(streamId, connection)

  self:run(connection)
end

function InitialClientStateEvent:run(connection)
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
end
