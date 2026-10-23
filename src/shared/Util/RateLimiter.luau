--!strict
-- Token-bucket rate limiter keyed by any value (usually a Player).
-- Pure Luau with an injectable clock, so it can be unit-tested outside Roblox.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, last: number }

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_capacity: number,
		_refill: number,
		_clock: () -> number,
		_buckets: { [any]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSecond: number, clock: (() -> number)?): RateLimiter
	return setmetatable({
		_capacity = capacity,
		_refill = refillPerSecond,
		_clock = clock or os.clock,
		_buckets = {},
	}, RateLimiter)
end

-- Returns true and spends a token if the key is allowed to act now.
function RateLimiter.check(self: RateLimiter, key: any): boolean
	local now = self._clock()
	local bucket = self._buckets[key]
	if bucket == nil then
		bucket = { tokens = self._capacity, last = now }
		self._buckets[key] = bucket
	end
	bucket.tokens = math.min(self._capacity, bucket.tokens + (now - bucket.last) * self._refill)
	bucket.last = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.remove(self: RateLimiter, key: any)
	self._buckets[key] = nil
end

return RateLimiter
