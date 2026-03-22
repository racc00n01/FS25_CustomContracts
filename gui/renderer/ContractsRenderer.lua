--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

-- #region agent log
local function _dbg(loc, msg, v1, v2, v3, hyp)
  local ts = math.floor((os and os.clock and os.clock() or 0) * 1000)
  local function q(v)
    if v == nil then return "null" end
    if type(v) == "string" then return '"' .. (v:gsub('"', '\\"')) .. '"' end
    return tostring(v)
  end
  local ds = string.format('{"v1":%s,"v2":%s,"v3":%s}', q(v1), q(v2), q(v3))
  local j = string.format(
    '{"sessionId":"b268ea","timestamp":%d,"location":"%s","message":"%s","data":%s,"hypothesisId":"%s"}\n',
    ts, loc or "?", msg or "", ds, hyp or "?")
  local logPath = (g_currentModDirectory or "") .. "debug-b268ea.log"
  local f = io.open(logPath, "a")
  if f then
    f:write(j); f:close()
  end
end
-- #endregion

ContractsRenderer = {}
ContractsRenderer_mt = Class(ContractsRenderer)

function ContractsRenderer.new()
  local self = {}
  setmetatable(self, ContractsRenderer_mt)
  self.data = nil
  self.sectionContracts = nil
  self.selectedRow = -1;
  self.indexChangedCallback = nil

  return self
end

function ContractsRenderer:setData(data)
  self.data = data
  self.sectionContracts = {}
  local keys = {}
  for listType, flatList in pairs(data) do
    keys[#keys + 1] = tostring(listType) .. ":" .. tostring(#(flatList or {}))
    self.sectionContracts[listType] = self:buildSectionContracts(flatList)
  end
end

function ContractsRenderer:buildSectionContracts(flatContracts)
  local sections = {}
  local lastTitle = nil

  -- Sort by work type first so same-type contracts are adjacent
  table.sort(flatContracts, function(a, b)
    return (a:getWorkTypeAreaName() or "") < (b:getWorkTypeAreaName() or "")
  end)

  for _, contract in ipairs(flatContracts) do
    local title = contract:getWorkTypeAreaName() -- "Baling", "Cultivating", "Transport", etc.
    if lastTitle ~= title then
      table.insert(sections, { title = title, contracts = {} })
      lastTitle = title
    end
    table.insert(sections[#sections].contracts, contract)
  end

  return sections
end

function ContractsRenderer:getNumberOfSections()
  local selection = g_currentMission.CustomContracts.CustomContractsMenu.contractDisplaySwitcher:getState()
  local sections = self.sectionContracts[selection]
  local n = sections and #sections or 0
  return n
end

function ContractsRenderer:getNumberOfItemsInSection(list, section)
  local selection = g_currentMission.CustomContracts.CustomContractsMenu.contractDisplaySwitcher:getState()
  local sections = self.sectionContracts[selection]
  if sections and sections[section] then
    return #sections[section].contracts
  end
  return 0
end

function ContractsRenderer:getTitleForSectionHeader(list, section)
  local selection = g_currentMission.CustomContracts.CustomContractsMenu.contractDisplaySwitcher:getState()
  local sections = self.sectionContracts[selection]
  return (sections and sections[section] and sections[section].title or "")
end

function ContractsRenderer:populateCellForItemInSection(list, section, index, cell)
  local selection = g_currentMission.CustomContracts.CustomContractsMenu.contractDisplaySwitcher:getState()
  local contract = self.sectionContracts[selection][section].contracts[index]

  local farm = g_farmManager:getFarmById(contract.creatorFarmId)

  cell:getAttribute("farmIcon"):setImageSlice(nil, farm:getIconSliceId())
  cell:getAttribute("farmland"):setText(contract:getListLabel())

  if contract.status == CustomContract.STATUS.COMPLETED or contract.status == CustomContract.STATUS.COMPLETED_AWAITING_INVOICE or contract.status == CustomContract.STATUS.CANCELLED or contract.status == CustomContract.STATUS.EXPIRED or contract.status == CustomContract.STATUS.INVOICED then
    cell:getAttribute("reward"):setText(g_i18n:getText("cc_status_" .. string.lower(contract.status)))
  else
    cell:getAttribute("reward"):setText(g_i18n:formatMoney(contract.reward, 0, true, true))
  end
end

--- Returns contract at flat list index (for lists that use flat selectedIndex).
function ContractsRenderer:getContractAtFlatIndex(selection, flatIndex)
  local sections = self.sectionContracts and self.sectionContracts[selection]
  if not sections or flatIndex < 1 then return nil end
  local count = 0
  for s, sec in ipairs(sections) do
    for i, c in ipairs(sec.contracts) do
      count = count + 1
      if count == flatIndex then return c, s, i end
    end
  end
  return nil
end

function ContractsRenderer:onListSelectionChanged(list, section, index)
  self.selectedRow = index
  self.selectedSection = section
  if self.indexChangedCallback ~= nil then
    self.indexChangedCallback(section, index)
  end
end
