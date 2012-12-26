# -*- coding: utf-8 -*-

class ZeroId
  def id
    "0"
  end
end

def zeroid
  $zeroid ||= ZeroId.new
end

class Timeline
  def initialize(key)
    @key = key
  end

  def page(page_size, page)
    from      = (page-1) * page_size
    to        = (page) * page_size - 1
    redis.lrange(@key, from, to).map do |post_id|
      Post.new(post_id)
    end
  end

  def latest
    p = redis.lrange(@key, 0, 0)[0]
    (p && Post.new(p)) || zeroid
  end
end

class HashTag
  def initialize(key)
    @key = key
  end

  def page(page_size, page)
    from      = (page-1) * page_size
    to        = (page) * page_size - 1
    redis.zrevrange("hashtag:#{@key}", from, to).map do |post_id|
      Post.new(post_id)
    end
  end

  def latest
    p = redis.zrevrange("hashtag:#{@key}", 0, 0)[0]
    (p && Post.new(p)) || zeroid
  end
end

class HashTags
  def self.page(page_size, page)
    from      = (page-1) * page_size
    to        = (page) * page_size - 1
    redis.zrevrange('hashtags', from, to)
  end
end    
    
class Model
  def initialize(id)
    @id = id
  end
  
  def ==(other)
    @id.to_s == other.id.to_s
  end
  
  attr_reader :id
  
  def self.property(name)
    klass = self.name.downcase
    self.class_eval <<-RUBY
      def #{name}
        _#{name}
      end
      
      def _#{name}
        redis.get("#{klass}:id:" + id.to_s + ":#{name}")
      end
      
      def #{name}=(val)
        redis.set("#{klass}:id:" + id.to_s + ":#{name}", val)
      end
    RUBY
  end
end  

class AllUser
  def archive(b, e)
    # 効率悪い
    redis.lrange('timeline', 0, -1).map do |post_id|
      post = Post.new(post_id)
      t = post.created_at
      b <= t && t < e ? [User.new(post.user_id).username, post.created_at, post.content] : nil
    end.compact
  end

  def first_date
    r = redis.lrange("timeline", -1, -1)
    r.empty? ? nil : Post.new(r[0]).created_at
  end

  def last_date
    r = redis.lrange("timeline", 0, 0)
    r.empty? ? nil : Post.new(r[0]).created_at
  end
  
end

class User < Model
  def self.find_by_username(username)
    return AllUser.new if username == 'all'
    if id = redis.get("user:username:#{username}")
      User.new(id)
    end
  end
  
  def self.find_by_id(id)
    if redis.exists("user:id:#{id}:username")
      User.new(id)
    end
  end
  
  def self.create(username, password)
    user_id = redis.incr("user:uid")
    salt = User.new_salt
    redis.set("user:id:#{user_id}:username", username)
    redis.set("user:username:#{username}", user_id)
    redis.set("user:id:#{user_id}:salt", salt)
    redis.set("user:id:#{user_id}:hashed_password", hash_pw(salt, password))
    redis.lpush("users", user_id)
    User.new(user_id)
  end
  
  def self.all_users
    redis.lrange("users", 0, -1).map do |user_id|
      User.new(user_id)
    end
  end

  def self.new_users
    redis.lrange("users", 0, 10).map do |user_id|
      User.new(user_id)
    end
  end
  
  def self.new_salt
    arr = %w(a b c d e f)
    (0..6).to_a.map{ arr[rand(6)] }.join
  end
  
  def self.hash_pw(salt, password)
    Digest::MD5.hexdigest(salt + password)
  end
  
  property :username
  property :salt
  property :hashed_password
  property :mail_address
  
  def posts(page=1)
    from, to = (page-1)*10, page*10-1
    redis.lrange("user:id:#{id}:posts", from, to).map do |post_id|
      Post.new(post_id)
    end
  end
  
  def timeline(page=1)
    from, to = (page-1)*10, page*10-1
    redis.lrange("user:id:#{id}:timeline", from, to).map do |post_id|
      Post.new(post_id)
    end
  end

  def archive(b, e)
    username = self.username

    # 効率悪い
    redis.lrange("user:id:#{id}:posts", 0, -1).map do |post_id|
      post = Post.new(post_id)
      t = post.created_at
      b <= t && t < e ? [username, post.created_at, post.content] : nil
    end.compact
  end

  def first_date
    r = redis.lrange("user:id:#{id}:posts", -1, -1)
    r.empty? ? nil : Post.new(r[0]).created_at
  end

  def last_date
    r = redis.lrange("user:id:#{id}:posts", 0, 0)
    r.empty? ? nil : Post.new(r[0]).created_at
  end
  
  def latest
    p = redis.lrange("user:id:#{id}:timeline", 0, 0)[0]
    (p && Post.new(p)) || zeroid
  end

  def mentions(page=1)
    from, to = (page-1)*10, page*10-1
    redis.lrange("user:id:#{id}:mentions", from, to).map do |post_id|
      Post.new(post_id)
    end
  end
  
  def latest_mention
    p = redis.lrange("user:id:#{id}:mentions", 0, 0)[0]
    (p && Post.new(p)) || zeroid
  end

  def add_post(post)
    redis.lpush("user:id:#{id}:posts", post.id)
    redis.lpush("user:id:#{id}:timeline", post.id)
  end
  
  def add_timeline_post(post)
    redis.lpush("user:id:#{id}:timeline", post.id)
  end
  
  def add_mention(post)
    redis.lpush("user:id:#{id}:mentions", post.id)
  end
  
  def follow(user)
    return if user == self
    redis.sadd("user:id:#{id}:followees", user.id)
    user.add_follower(self)
  end
  
  def stop_following(user)
    redis.srem("user:id:#{id}:followees", user.id)
    user.remove_follower(self)
  end
  
  def following?(user)
    redis.sismember("user:id:#{id}:followees", user.id)
  end
  
  def followers
    redis.smembers("user:id:#{id}:followers").map do |user_id|
      User.new(user_id)
    end
  end
  
  def followees
    redis.smembers("user:id:#{id}:followees").map do |user_id|
      User.new(user_id)
    end
  end
  
  protected
  
  def add_follower(user)
    redis.sadd("user:id:#{id}:followers", user.id)
  end
  
  def remove_follower(user)
    redis.srem("user:id:#{id}:followers", user.id)
  end
end
  
class Post < Model
  def self.create(user, content)
    create_post(user, content, nil, nil)
  end

  def self.retweet(user, source_id)
    source = Post.new(source_id)
    create_post(user, source.content, source.original_id, source.created_at)
  end

  property :content
  property :user_id
  property :created_at
  property :original_id
  
  def created_at
    Time.parse(_created_at)
  end
  
  def user
    User.new(user_id)
  end

  def edit(content)
    Post.normalize(content)

    self.content = content
    now = Time.new.to_i
    content.scan(/[#＃](\w+)/u).each do |hashtag|
      redis.zadd("hashtag:#{$1}", now, post_id)
      redis.zadd("hashtags", now, hashtag)
    end
  end

  def delete_hashtag(hashtag)
    return if /^\w+$/ !~ hashtag
    puts "delete_hashtag: #{hashtag}"

    content_key = "post:id:#{self.id}:content"
    hashtag_key = "hashtag:#{hashtag}"

    while true
      redis.watch content_key, hashtag_key
      s = self.content
      redis.multi
      redis.zrem(hashtag_key, self.id)
      s.gsub!(/\s*[#＃]#{hashtag}\s*/u, ' ')
      self.content = s
      if redis.exec then break; end
    end
  end

  def add_hashtag(hashtag)
    return if /^\w+$/ !~ hashtag
    puts "add_hashtag: #{hashtag}"

    content_key = "post:id:#{self.id}:content"
    hashtag_key = "hashtag:#{hashtag}"

    while true
      redis.watch content_key, hashtag_key
      s = self.content
      if /[#＃]#{hashtag}/ =~ s then
        redis.unwatch
        break
      end
      redis.multi
      redis.zadd(hashtag_key, self.created_at.to_i, self.id)
      redis.zadd("hashtags", Time.now.to_i, hashtag)
      s += " \##{hashtag}"
      self.content = s
      if redis.exec then break; end
    end
  end

  private
  def self.create_post(user, content, original_id, created_at)
    normalize(content)

    post_id = redis.incr("post:uid")
    post = Post.new(post_id)
    post.content = content
    post.original_id = original_id || post_id
    post.user_id = user.id
    post.created_at = created_at || Time.now.to_s
    post.user.add_post(post)
    redis.lpush("timeline", post_id)
    post.user.followers.each do |follower|
      follower.add_timeline_post(post)
    end
    content.scan(/@\w+/).each do |mention|
      if user = User.find_by_username(mention[1..-1])
        user.add_mention(post)
      end
    end
    now = Time.new.to_i
    content.scan(/[#＃](\w+)/u).each do |hashtag|
      redis.zadd("hashtag:#{$1}", now, post_id)
      redis.zadd("hashtags", now, hashtag)
    end
  end

  def self.normalize(content)
    content.gsub!(/[　\s\t]/u, ' ')
  end
  
end
