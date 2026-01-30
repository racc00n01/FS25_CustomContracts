DateUtil = {}

DateUtil.MONTH_NAMES = {
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
}

-- Your confirmed mapping:
-- FS period 1 = March, so "calendar month" = period + 2 (wrapped)
function DateUtil.periodToMonth(period)
  -- returns 1..12
  if period == nil then return 1 end
  return ((period + 1) % 12) + 1
end

function DateUtil.wrapPeriod(period)
  -- returns 1..12 (works for any integer)
  if period == nil then return 1 end
  return ((period - 1) % 12) + 1
end

function DateUtil.toOrdinal(period, day, daysPerPeriod)
  -- 0..(12*dpp-1)
  period = period or 1
  day = day or 1
  daysPerPeriod = daysPerPeriod or 1
  return (period - 1) * daysPerPeriod + (day - 1)
end

function DateUtil.getCurrentPeriodDay()
  local env = g_currentMission and g_currentMission.environment
  local period = (env and env.currentPeriod) or 1
  local dpp = (env and env.daysPerPeriod) or 1

  -- Defensive: FS builds/mods differ
  local day = (env and (env.currentDayInPeriod or env.currentPeriodDay)) or 1
  day = math.max(1, math.min(day, dpp))

  return period, day, dpp
end

-- contract: expects duePeriod/dueDay, optional dueYearOffset
function DateUtil.isPastDue(contract, curPeriod, curDay, dpp)
  if contract == nil then return false end
  if contract.duePeriod == nil or contract.duePeriod == -1 then return false end
  if contract.dueDay == nil or contract.dueDay == -1 then return false end

  dpp = dpp or 1
  curPeriod = curPeriod or 1
  curDay = curDay or 1

  local curOrd = DateUtil.toOrdinal(curPeriod, curDay, dpp)
  local dueOrd = DateUtil.toOrdinal(contract.duePeriod, contract.dueDay, dpp)

  local yearLen = 12 * dpp
  if (contract.dueYearOffset or 0) > 0 then
    dueOrd = dueOrd + yearLen
    -- If we're early in the year and due is also early, treat current as next cycle too
    if curPeriod <= contract.duePeriod then
      curOrd = curOrd + yearLen
    end
  end

  return curOrd > dueOrd
end

function DateUtil.getMonthName(month)
  return DateUtil.MONTH_NAMES[month] or tostring(month)
end
