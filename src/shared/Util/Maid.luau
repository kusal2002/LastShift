--!strict
-- Collects connections, instances, functions and threads, and cleans them all up at once.
export type Task = RBXScriptConnection | Instance | () -> () | thread

local Maid = {}
Maid.__index = Maid

export type Maid = typeof(setmetatable({} :: { _tasks: { Task } }, Maid))

function Maid.new(): Maid
	return setmetatable({ _tasks = {} :: { Task } }, Maid)
end

function Maid.give<T>(self: Maid, item: T): T
	table.insert(self._tasks, item :: any)
	return item
end

function Maid.clean(self: Maid)
	local tasks = self._tasks
	self._tasks = {}
	-- Clean in reverse order so later items (often children) go first.
	for index = #tasks, 1, -1 do
		local item: any = tasks[index]
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "function" then
			item()
		elseif kind == "thread" then
			pcall(task.cancel, item)
		end
	end
end

return Maid
