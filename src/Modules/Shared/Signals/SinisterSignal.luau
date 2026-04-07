--!strict
--!native

type callback = (...any) -> ()

export type connection = {
	Disconnect: (self: connection) -> ();
}

export type signal = {
	Connect: (self: signal, cb: callback) -> connection;
	ConnectAsync: (self: signal, cb: callback) -> connection;
	Once: (self: signal, cb: callback) -> connection;
	Fire: (self: signal, ...any) -> ();
	Wait: (self: signal) -> ...any;
	DisconnectAll: (self: signal) -> ();
}

type state = {
	callbacks: {callback};
	number: number;
	signal: signal;
	dirty: boolean;
}

local free_thread: thread? = nil

local function run_callback(cb: callback, ...: any)
	local thread = free_thread
	free_thread = nil
	cb(...)
	free_thread = thread
end

local function runner_loop()
	while true do
		run_callback(coroutine.yield())
	end
end

local function dispatch_async(cb: callback, ...: any)
	if free_thread == nil then
		local t = coroutine.create(runner_loop)
		free_thread = t
		coroutine.resume(t)
	end
	coroutine.resume(free_thread :: thread, cb, ...)
end

local function noop(_self: signal, ...: any) end

local function rebuild(s: state)
	local sig = s.signal
	if s.number == 0 then
		sig.Fire = noop
	else
		sig.Fire = function(_self: signal, ...: any)
			for i = 1, s.number do
				(s.callbacks[i] :: callback)(...)
			end
		end
	end
end

local function ep_disconnect(s: state, index: number)
	local cbs = s.callbacks

	if cbs[index] == nil then return end
	local last = s.number

	if index ~= last then
		cbs[index] = cbs[last]
	end

	cbs[last] = nil
	s.number = last - 1

	rebuild(s)
end

local function ep_connect(s: state, cb: callback): connection
	local index = s.number + 1
	s.number = index
	s.callbacks[index] = cb
	s.dirty = true

	return {
		Disconnect = function(_self: connection)
			ep_disconnect(s, index)
		end,
	}
end

local sinister_signal = {}

function sinister_signal.new(): signal
	local s: state = {
		callbacks = {};
		number = 0;
		signal = nil :: any;
		dirty = false;
	}

	s.signal = {
		Fire = function(_self: signal, ...: any)
			if s.dirty then
				rebuild(s)
				s.dirty = false
			end

			s.signal.Fire(_self, ...)
		end;
		Connect = function(_self: signal, cb: callback): connection
			return ep_connect(s, cb)
		end;
		ConnectAsync = function(_self: signal, cb: callback): connection
			return ep_connect(s, function(...) dispatch_async(cb, ...) end)
		end;
		Once = function(_self: signal, cb: callback): connection
			local conn: connection
			local idx: number
			conn = ep_connect(s, function(...)
				ep_disconnect(s, idx)
				cb(...)
			end)
			idx = s.number
			return conn
		end;
		Wait = function(_self: signal): ...any
			local thread = coroutine.running()
			if thread == nil then error("Wait must be called from a coroutine") end
			local idx: number
			ep_connect(s, function(...)
				ep_disconnect(s, idx)
				coroutine.resume(thread, ...)
			end)
			idx = s.number
			return coroutine.yield()
		end;
		DisconnectAll = function(_self: signal)
			table.clear(s.callbacks)
			s.number = 0
			s.signal.Fire = noop
		end;
	}:: any

	return s.signal
end

return sinister_signal
