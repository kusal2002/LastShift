--!strict
-- Minimal event object for client-side state changes.
local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal = typeof(setmetatable(
	{} :: { _handlers: { [number]: (...any) -> () }, _nextId: number },
	Signal
))

function Signal.new(): Signal
	return setmetatable({ _handlers = {}, _nextId = 0 }, Signal)
end

function Signal.Connect(self: Signal, handler: (...any) -> ()): Connection
	self._nextId += 1
	local id = self._nextId
	local handlers = self._handlers
	handlers[id] = handler
	local connection = {}
	function connection.Disconnect(_: any)
		handlers[id] = nil
	end
	return connection :: any
end

function Signal.Fire(self: Signal, ...: any)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
