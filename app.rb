
require 'rubygems'
require 'sinatra'  
require 'erb'
require 'redis'
require 'sinatra/namespace'
require 'sinatra/r18n'

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
require 'config'

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
    render_home(1)
  end

  get %r{/([0-9]+)} do
    render_home(params[:captures].first.to_i)
  end

  get '/:path.:ext' do |path, ext|
    send_file '#{path}.#{ext}'
  end

  get '/timeline' do |page|
    render_timeline(1)
  end

  get '/timeline/:page' do |page|
    render_timeline(page.to_i)
  end

  get '/profile/:username' do |username|
    render_profile(username, 1)
  end

  get '/profile/:username/:page' do |username, page|
    render_profile(username, page.to_i)
  end

  get '/mentions/:username' do |username|
    render_mentions(username, 1)
  end

  get '/mentions/:username/:page' do |username, page|
    render_mentions(username, page.to_i)
  end

  post '/post' do 
    len = params[:content].split(//u).length
    if len == 0
      posting_error = "You didn't enter anything."
    elsif len > 140
      posting_error = "Keep it to 140 characters please!"
    end
    if posting_error
      render_body("/post",
                  config.arrangement.home,
                  :page => 1,
                  :posting_error => posting_error) 
    else
      Post.create(@logged_in_user, params[:content])
      redirect to('/')
    end
  end

  get '/follow/:follower/:followee' do |follower_username, followee_username|
    follower = User.find_by_username(follower_username)
    followee = User.find_by_username(followee_username)
    redirect to('/') unless @logged_in_user == follower
    follower.follow(followee)
    redirect to("/") + followee_username
  end

  get '/stopfollow/:follower/:followee' do |follower_username, followee_username|
    follower = User.find_by_username(follower_username)
    followee = User.find_by_username(followee_username)
    redirect to('/') unless @logged_in_user == follower
    follower.stop_following(followee)
    redirect to("/") + followee_username
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
    link_to(user.username, "profile/#{user.username}")
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
      return t.time.just_now
    when 10..60
      return t.time.less_than_a_minute_ago
    end
    distance_in_minutes = (distance_in_seconds/60).round
    case distance_in_minutes
    when 0..1
      return t.time.a_minute_ago
    when 2..45
      return distance_in_minutes.round.to_s + t.time.minutes_ago
    when 46..89
      return t.time.about_an_hour_ago
    when 90..1439        
      return (distance_in_minutes/60).round.to_s + t.time.hours_ago
    when 1440..2879
      return t.time.about_a_day_ago
    when 2880..43199
      (distance_in_minutes / 1440).round.to_s + t.time.days_ago
    when 43200..86399
      t.time.about_a_month_ago
    when 86400..525599   
      (distance_in_minutes / 43200).round.to_s + t.time.months_ago
    when 525600..1051199
      t.time.about_a_year_ago
    else
      t.time.over + (distance_in_minutes / 525600).round.to_s + t.time.years_ago
    end
  end

  def render_home(page)
    render_body('', config.arrangement.home, :page => page)
  end


  def render_timeline(page)
    render_body('timeline/', config.arrangement.timeline, :target_user => @logged_in_user, :page => page)
  end

  def render_profile(username, page)
    render_body("profile/#{username}/", config.arrangement.profile, :target_user => find_user(username), :page => page)
  end

  def render_mentions(username, page)
    render_body("mentions/#{username}/", config.arrangement.mentions, :target_user => find_user(username), :page => page)
  end    

  def render_body(current, set, append_locals = {})
=begin
    @posts = @logged_in_user.timeline
    @followers = @logged_in_user.followers
    @followees = @logged_in_user.followees
=end
    locals = {
      :current => current,
      :logged_in_user => @logged_in_user, 
      :posting_error => nil,
    }.merge!(append_locals)
    
    callbacks = {
      :callback => lambda do |section|
        (set[section] || []).collect do |elem|
          erb elem.intern, :locals => locals
        end.join('')
      end
    }

    erb :base, :locals => locals.merge(callbacks)
  end

  def generate_personal_menu_item(item)
    case item.intern
    when :home      then link_to('home', '')
    when :mentions  then link_to('mentions', "mentions/#{@logged_in_user.username}")
    when :profile   then link_to_user(@logged_in_user)
    when :timeline  then link_to('timeline', 'timeline')
    when :logout    then link_to('logout', 'logout')
    end
    #config.arrangement[item]
  end

  #attr_reader :logged_in_user, :target_user, :posting_error, :page

  def username
    "#{t.site.name_prefix}#{@logged_in_user.username}#{t.site.name_suffix}"
  end

  def get_world_posts(page)
    Timeline.page(page)
  end

  def find_user(username)
    User.find_by_username(username)
  end
end
