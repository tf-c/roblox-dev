--!strict
-- Per-player token bucket for remote events.

local RateLimit = {}
RateLimit.__index = RateLimit

type Bucket = { tokens: number, last: number }

export type Limiter = typeof(setmetatable(
	{} :: { rate: number, burst: number, buckets: { [Player]: Bucket } },
	RateLimit
))

function RateLimit.new(ratePerSecond: number, burst: number): Limiter
	return setmetatable({ rate = ratePerSecond, burst = burst, buckets = {} }, RateLimit)
end

function RateLimit.allow(self: Limiter, player: Player): boolean
	local now = os.clock()
	local bucket = self.buckets[player]
	if not bucket then
		bucket = { tokens = self.burst, last = now }
		self.buckets[player] = bucket
	end
	bucket.tokens = math.min(self.burst, bucket.tokens + (now - bucket.last) * self.rate)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimit.forget(self: Limiter, player: Player)
	self.buckets[player] = nil
end

return RateLimit
