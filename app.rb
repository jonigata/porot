
require 'rubygems'
require 'sinatra'  
require 'erb'
require 'redis'
require 'sinatra/namespace'

#URL_PREFIX='/porot'
URL_PREFIX=''

module Sinatra::Namespace
  module InstanceMethods
    def to(uri, *args)
      super("#{@namespace.pattern}#{uri}", *args)
    end
  end

  module NamespacedMethods
    def pattern
      @pattern
    end
  end
end

require 'domain'
require 'login-signup'

set :sessions, true
set :public_folder, File.dirname(__FILE__) + '/public'

def redis
  $redis ||= Redis.new(:host => '127.0.0.1')
end

namespace URL_PREFIX do 
  before do
    keys = redis.keys("*")
  end

  get '/' do
    @posts = @logged_in_user.timeline
    erb :index
  end

  get '/:path.:ext' do |path, ext|
    send_file '#{path}.#{ext}'
  end

  get '/timeline' do
    @posts = Timeline.page(1)
    erb :timeline
  end

  post '/post' do
    len = params[:content].split(//u).length
    if len == 0
      @posting_error = "You didn't enter anything."
    elsif len > 140
      @posting_error = "Keep it to 140 characters please!"
    end
    if @posting_error
      @posts = @logged_in_user.timeline
      erb :index
    else
      Post.create(@logged_in_user, params[:content])
      redirect to('/')
    end
  end

  get '/:follower/follow/:followee' do |follower_username, followee_username|
    follower = User.find_by_username(follower_username)
    followee = User.find_by_username(followee_username)
    redirect to('/') unless @logged_in_user == follower
    follower.follow(followee)
    redirect to("/") + followee_username
  end

  get '/:follower/stopfollow/:followee' do |follower_username, followee_username|
    follower = User.find_by_username(follower_username)
    followee = User.find_by_username(followee_username)
    redirect to('/') unless @logged_in_user == follower
    follower.stop_following(followee)
    redirect to("/") + followee_username
  end

  get '/:username' do |username|
    @user = User.find_by_username(username)
    
    @posts = @user.posts
    @followers = @user.followers
    @followees = @user.followees
    erb :profile
  end

  get '/:username/mentions' do |username|
    @user = User.find_by_username(username)
    @posts = @user.mentions
    erb :mentions
  end
end

helpers do
  def link_text(action)
    "#{URL_PREFIX}/#{action}"
  end
  def href(action)
    "href=\"#{link_text(action)}\""
  end

  def link_to(text, action)
    "<a #{href(action)}>#{text}</a>"
  end

  def link_to_user(user)
    link_to(user.username, user.username)
  end
  
  def pluralize(singular, plural, count)
    if count == 1
      count.to_s + " " + singular
    else
      count.to_s + " " + plural
    end
  end
  
  def display_post(post)
    post.content.gsub(/@\w+/) do |mention|
      if user = User.find_by_username(mention[1..-1])
        "@" + link_to_user(user)
      else
        mention
      end
    end
  end

  def time_ago_in_words(time)
    distance_in_seconds = (Time.now - time).round
    case distance_in_seconds
    when 0..10
      return "just now"
    when 10..60
      return "less than a minute ago"
    end
    distance_in_minutes = (distance_in_seconds/60).round
    case distance_in_minutes
    when 0..1
      return "a minute ago"
    when 2..45
      return distance_in_minutes.round.to_s + " minutes ago"
    when 46..89
      return "about an hour ago"
    when 90..1439        
      return (distance_in_minutes/60).round.to_s + " hours ago"
    when 1440..2879
      return "about a day ago"
    when 2880..43199
      (distance_in_minutes / 1440).round.to_s + " days ago"
    when 43200..86399
       "about a month ago"
    when 86400..525599   
      (distance_in_minutes / 43200).round.to_s + " months ago"
    when 525600..1051199
      "about a year ago"
    else
      "over " + (distance_in_minutes / 525600).round.to_s + " years ago"
    end
  end
end
        





