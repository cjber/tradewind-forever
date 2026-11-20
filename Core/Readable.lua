---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

-- A value the client hands over as secret (Forever's restricted reads, as in combat) errors on a truth test, a
-- comparison or arithmetic, and stays secret wherever it is kept. Nil for one, so the caller treats it as unknown; any
-- other value unchanged (WFA-30).
---@generic T
---@param value T
---@return T?
function ns.Readable(value)
	if issecretvalue and issecretvalue(value) then
		return nil
	end
	return value
end
