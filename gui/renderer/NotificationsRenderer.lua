NotificationsRenderer = {}
NotificationsRenderer_mt = Class(NotificationsRenderer)

function NotificationsRenderer.new()
  local self = {}
  setmetatable(self, NotificationsRenderer_mt)
  self.data = nil
  self.selectedRow = 0;
  self.indexChangedCallback = nil

  return self
end

function NotificationsRenderer:setData(data)
  self.data = data
end

function NotificationsRenderer:getNumberOfSections()
  return 1
end

function NotificationsRenderer:getNumberOfItemsInSection(list, section)
  return #self.data
end

function NotificationsRenderer:getTitleForSectionHeader(list, section)
  return ""
end

function NotificationsRenderer:populateCellForItemInSection(list, section, index, cell)
  local notification = self.data[index]

  local currentTime = notification.date / 3600000
  local timeHours = math.floor(currentTime)
  local timeMinutes = math.floor((currentTime - timeHours) * 60)
  local timeText = string.format("%02d:%02d", timeHours, timeMinutes)

  cell:getAttribute("id"):setText(notification.id)
  cell:getAttribute("message"):setText(notification:getMessage())
  cell:getAttribute("date"):setText(timeText)
end

function NotificationsRenderer:onListSelectionChanged(list, section, index)
  self.selectedRow = index
end
