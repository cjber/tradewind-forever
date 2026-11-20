-- Shared by the specs: a namespace the runtime files load into, and a loader for them. Not a spec itself.
local Helpers = {}

---@return table ns a namespace with a pass-through locale and a readable that passes every value
function Helpers.namespace()
	return {
		L = setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		}),
		Readable = function(value)
			return value
		end,
	}
end

---@param ns table
---@param ... string files, loaded in order
---@return table ns
function Helpers.load(ns, ...)
	for _, path in ipairs({ ... }) do
		assert(loadfile(path))("TradewindForever", ns)
	end
	return ns
end

---@param condition any
---@param label string
function Helpers.check(condition, label)
	if not condition then
		error(label, 2)
	end
end

return Helpers
