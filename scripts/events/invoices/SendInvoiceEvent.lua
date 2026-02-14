--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

SendInvoiceEvent = {}
local SendInvoiceEvent_mt = Class(SendInvoiceEvent, Event)

InitEventClass(SendInvoiceEvent, "SendInvoiceEvent")

function SendInvoiceEvent.emptyNew()
  local self = Event.new(SendInvoiceEvent_mt)
  return self
end

function SendInvoiceEvent.new(invoiceId, farmId)
  local self = SendInvoiceEvent.emptyNew()
  self.farmId = farmId
  self.invoiceId = invoiceId
  return self
end

function SendInvoiceEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.farmId)
  streamWriteInt32(streamId, self.invoiceId)
end

function SendInvoiceEvent:readStream(streamId, connection)
  self.farmId = streamReadInt32(streamId)
  self.invoiceId = streamReadInt32(streamId)
  self:run(connection)
end

function SendInvoiceEvent:run(connection)
  if not connection:getIsServer() then
    g_server:broadcastEvent(SendInvoiceEvent.new(self.invoiceId, self.farmId))
  end

  local invoiceManager = g_currentMission.CustomContracts.InvoiceManager
  invoiceManager:handleSendRequest(self.invoiceId)
end
