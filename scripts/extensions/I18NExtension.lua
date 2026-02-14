RTI18NExtension = {}
local modName = g_currentModName

function RTI18NExtension:getText(superFunc, text, modEnv)
  if (text == "cc_money_type_invoices" or text == "finance_invoices") and modEnv == nil then
    return superFunc(self, text, modName)
  end

  return superFunc(self, text, modEnv)
end

I18N.getText = Utils.overwrittenFunction(I18N.getText, RTI18NExtension.getText)
