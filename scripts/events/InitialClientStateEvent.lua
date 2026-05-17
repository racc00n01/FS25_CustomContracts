--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

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
  local contractManager = g_currentMission.CustomContracts.ContractManager
  local farmAccessManager = g_currentMission.CustomContracts.FarmAccessManager
  local invoiceManager = g_currentMission.CustomContracts.InvoiceManager
  local notificationManager = g_currentMission.CustomContracts.NotificationManager

  contractManager:writeInitialClientState(streamId, connection)
  farmAccessManager:writeInitialClientState(streamId, connection)
  invoiceManager:writeInitialClientState(streamId, connection)
  notificationManager:writeInitialClientState(streamId, connection)
end

function InitialClientStateEvent:readStream(streamId, connection)
  local contractManager = g_currentMission.CustomContracts.ContractManager
  local farmAccessManager = g_currentMission.CustomContracts.FarmAccessManager
  local invoiceManager = g_currentMission.CustomContracts.InvoiceManager
  local notificationManager = g_currentMission.CustomContracts.NotificationManager

  contractManager:readInitialClientState(streamId, connection)
  farmAccessManager:readInitialClientState(streamId, connection)
  invoiceManager:readInitialClientState(streamId, connection)
  notificationManager:readInitialClientState(streamId, connection)

  self:run(connection)
end

function InitialClientStateEvent:run(connection)
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
  g_messageCenter:publish(MessageType.FARM_ACCESS_UPDATED)
  g_messageCenter:publish(MessageType.INVOICES_UPDATED)
  g_messageCenter:publish(MessageType.NOTIFICATIONS_UPDATED)
end
