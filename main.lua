return function(mod)
  local kris = require("mods.rocket_edition.kris")
  local girlMode = require("mods.rocket_edition.girlMode")
  local nbMode = require("mods.rocket_edition.nbMode")
  local credits = require("mods.rocket_edition.credits")

  local cfg = kris.init(mod)

  if cfg.genderMode == "girl" then
    girlMode.init(mod)
  elseif cfg.genderMode == "enby" then
    nbMode.init(mod)
  end
  -- "boy": neither runs, vanilla male text stands untouched

  credits.init(mod)
end
