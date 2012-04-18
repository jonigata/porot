require 'rubygems'
require 'redis'
require 'time'

redis = Redis.new(:host => '127.0.0.1')

redis.keys('hashtag:*').each do |x|
  a = redis.lrange(x, 0, -1)
  redis.del(x)
  a.each do |y|
    date = redis.get("post:id:#{y}:created_at")
    redis.zadd("#{x}", Time.parse(date).to_i, y)
  end
end
