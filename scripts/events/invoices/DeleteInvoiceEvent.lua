--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

DeleteInvoiceEvent = {}
local DeleteInvoiceEvent_mt = Class(DeleteInvoiceEvent, Event)

InitEventClass(DeleteInvoiceEvent, "DeleteInvoiceEvent")

function DeleteInvoiceEvent.emptyNew()
  local self = Event.new(DeleteInvoiceEvent_mt)
  return self
end

function DeleteInvoiceEvent.new(invoiceId, farmId)
  local self = DeleteInvoiceEvent.emptyNew()
  self.farmId = farmId
  self.invoiceId = invoiceId
  return self
end

function DeleteInvoiceEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.farmId)
  streamWriteInt32(streamId, self.invoiceId)
end

function DeleteInvoiceEvent:readStream(streamId, connection)
  self.farmId = streamReadInt32(streamId)
  self.invoiceId = streamReadInt32(streamId)
  self:run(connection)
end

function DeleteInvoiceEvent:run(connection)
  if not connection:getIsServer() then
    g_server:broadcastEvent(DeleteInvoiceEvent.new(self.farmId))
  end

  local invoiceManager = g_currentMission.CustomContracts.InvoiceManager
  invoiceManager:handleDeleteRequest(self.invoiceId)
end
