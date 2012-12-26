# -*- coding: utf-8 -*-

require 'rubygems'
require 'sinatra'  
require 'erb'
require 'redis'
require 'sinatra/namespace'
require 'sinatra/r18n'
require 'sinatra/jsonp'
require 'cgi'
require 'digest/md5'
require 'sanitize'

require 'config'

URL_PREFIX=config.url_prefix

module Sinatra::Namespace
  module InstanceMethods
    def to(uri, *args)
      p uri
      uri.gsub!(/^\//, '')
      p uri
      super("#{@namespace.pattern}/#{uri}", *args)
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
    # keys = redis.keys("*")
  end

  get %r{/(.*\.(js|css|png|gif))} do |path, ext|
    send_file File.join(settings.public_folder, path)
  end

  get '/' do
    render_home(1)
  end

  get %r{/([0-9]+)} do
    render_home(params[:captures].first.to_i)
  end

  get '/timeline/' do
    render_timeline(1)
  end

  get '/timeline/:page' do |page|
    render_timeline(page.to_i)
  end

  get '/profile/:username/' do |username|
    render_profile(username, 1)
  end

  get '/profile/:username/:page' do |username, page|
    render_profile(username, page.to_i)
  end

  get '/mentions/:username/' do |username|
    render_mentions(username, 1)
  end

  get '/mentions/:username/:page' do |username, page|
    render_mentions(username, page.to_i)
  end

  get '/hashtags/' do
    render_hashtags(1, 1)
  end

  get '/hashtags/:tagpage' do |tagpage|
    render_hashtags(tagpage.to_i, 1)
  end

  get '/hashtag/:hashtag/' do |hashtag|
    render_hashtag(hashtag, 1, 1)
  end

  get '/hashtag/:hashtag/:tagpage/' do |hashtag, tagpage|
    render_hashtag(hashtag, tagpage.to_i, 1)
  end

  get '/hashtag/:hashtag/:tagpage/:postpage' do |hashtag, tagpage, postpage|
    render_hashtag(hashtag, tagpage.to_i, postpage.to_i)
  end

  get '/retweet/:postid/' do |postid|
    retweet('', postid)
  end

  get '/retweet/:postid/*' do |postid, after|
    retweet(after, postid)
  end

  get '/delete_hashtag/:postid/:hashtag/' do |postid, hashtag|
    delete_hashtag('', postid, hashtag)
  end

  get '/delete_hashtag/:postid/:hashtag/*' do |postid, hashtag, after|
    delete_hashtag(after, postid, hashtag)
  end

  get '/add_hashtag/:postid/:hashtag/' do |postid, hashtag|
    add_hashtag('', postid, hashtag)
  end

  get '/add_hashtag/:postid/:hashtag/*' do |postid, hashtag, after|
    add_hashtag(after, postid, hashtag)
  end

  get '/peek/world/:postid' do |postid|
    Timeline.new('timeline').latest.id != postid ? "changed" : ""
  end

  get '/peek/my/:postid' do |postid|
    @logged_in_user.latest.id != postid ? "changed" : ""
  end

  get '/peek/mentions/:postid' do |postid|
    @logged_in_user.latest_mention.id != postid ? "changed" : ""
  end

  get '/peek/target/:username/:postid' do |username, postid|
    User.find_by_username(username).latest.id != postid ? "changed" : ""
  end

  get '/peek/hashtag/:hashtag/:postid' do |hashtag, postid|
    HashTag.new(hashtag).latest.id != postid ? "changed" : ""
  end

  get '/latest' do
    JSONP(Timeline.new('timeline').latest.id.to_i)
  end

  get '/take/:postid' do |postid|
    post = Post.new(postid)
    user = post.user
    JSONP(
      [
        post.id.to_i,
        post.content,
        post.created_at,
        user.username,
        gravator(user),
      ])
  end

  get '/users/' do
    JSONP(
      User.all_users.map do |user|
        user.username
      end)
  end

  get '/archive/:username/:date_begin/:date_end/' do |username, date_begin, date_end|
    date_format = /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/;
    date_format =~ date_begin or return "bad date_begin"
    date_begin_time = Time.local($1.to_i, $2.to_i, $3.to_i)
    date_format =~ date_end or return "bad date_end"
    date_end_time = Time.local($1.to_i, $2.to_i, $3.to_i)
    JSONP User.find_by_username(username).archive(
      date_begin_time, date_end_time)
  end

  get '/first_date/:username/' do |username|
    JSONP User.find_by_username(username).first_date
  end

  get '/last_date/:username/' do |username|
    JSONP User.find_by_username(username).last_date
  end

  post '/post/' do
    post_status('', params[:content])
  end

  post '/post/*' do |after|
    post_status(after, params[:content])
  end

  post '/edit/' do
    edit_status(params[:post_id], '', params[:content])
  end

  post '/edit/*' do |after|
    edit_status(params[:post_id], after, params[:content])
  end

  post '/register_mail_address/*' do |after|
    register_mail_address(after, params[:mail_address])
  end

  get '/follow/:follower/:followee/*' do |follower_username, followee_username, after|
    follower = User.find_by_username(follower_username)
    followee = User.find_by_username(followee_username)
    redirect to('') unless @logged_in_user == follower
    follower.follow(followee)
    redirect to("#{after}")
  end

  get '/stopfollow/:follower/:followee/*' do |follower_username, followee_username, after|
    follower = User.find_by_username(follower_username)
    followee = User.find_by_username(followee_username)
    redirect to('') unless @logged_in_user == follower
    follower.stop_following(followee)
    redirect to("#{after}")
  end

end

helpers Sinatra::Jsonp
helpers do
  def link_text(action)
    action.gsub!(/^\//, '')
    "#{URL_PREFIX}/#{action}"
  end

  def href(action)
    "href=\"#{link_text(action)}\""
  end

  def link_to(text, action)
    "<a #{href(action)}>#{text}</a>"
  end

  def link_to_user(user)
    link_to(user.username, "profile/#{user.username}/")
  end
  
  def link_to_hashtag(hashtag)
    action = "hashtag/#{hashtag}/"
    "<a class='hashtag' #{href(action)}>#{hashtag}</a>"
  end
  
  def older_url(current, page)
    current.gsub(/\/[0-9]*$/, "/#{page}").tap do |c|
      p c
    end
  end

  def pluralize(singular, plural, count)
    if count == 1
      count.to_s + " " + singular
    else
      count.to_s + " " + plural
    end
  end
  
  def display_post_content(content)
    if content == ''
      "<span class='deleted'>#{t.site.deleted}</span>"
    else
      Sanitize.clean(content).gsub(/@\w+/) do |mention|
        if user = User.find_by_username(mention[1..-1])
          "@" + link_to_user(user)
        else
          mention
        end
      end.gsub(/[#＃](\w+)/u) do |hashtag|
        link_to_hashtag($1)
      end.gsub(URI.regexp) do |uri|
        "<a class='external-link' href='#{uri}' target='_blank'>#{uri}</a>"
      end
    end
  end

  def display_tagcloud(tagpage)
    HashTags.page(config.page_size, tagpage).map do |hashtag|
      link_to_hashtag(hashtag)
    end.join(' ')
  end

  def get_embeded_hashtags(content)
    content.scan(/[#＃](\w+)/u)
  end

  def get_trend_hashtags(content)
    a = HashTags.page(config.page_size, 1)[0...5]
    get_embeded_hashtags(content).each do |x|
      a.delete(x[0])
    end
    a
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
    render_body("/#{page}", config.arrangement.home, :page => page)
  end

  def render_timeline(page)
    render_body("timeline/#{page}", config.arrangement.timeline, :target_user => @logged_in_user, :page => page)
  end

  def render_profile(username, page)
    render_body("profile/#{username}/", config.arrangement.profile, :target_user => find_user(username), :page => page)
  end

  def render_mentions(username, page)
    render_body("mentions/#{username}/#{page}", config.arrangement.mentions, :target_user => find_user(username), :page => page)
  end    

  def render_hashtags(tagpage, postpage)
    # タグ未指定
    render_body("hashtags/#{tagpage}/#{postpage}", config.arrangement.hashtags, :page => postpage, :hashtag => nil, :tagpage => tagpage, :other_tags => "hashtags/#{tagpage+1}")
  end    

  def render_hashtag(hashtag, tagpage, postpage)
    # タグ指定
    render_body("hashtag/#{hashtag}/#{tagpage}/#{postpage}", config.arrangement.hashtags, :page => postpage, :hashtag => hashtag, :tagpage => tagpage, :other_tags => "hashtag/#{hashtag}/#{tagpage+1}/#{postpage}", :initial_text => " \##{hashtag}")
  end    

  def render_body(current, set, append_locals = {})
    locals = {
      :current => current,
      :logged_in_user => @logged_in_user, 
      :posting_error => nil,
      :initial_text => "",
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

  def post_status(current, content)
    make_status(current, content, true) do
      Post.create(@logged_in_user, content)
      redirect to("#{current}")
    end
  end

  def edit_status(post_id, current, content)
    post = Post.new(post_id.to_i)
    if post.user_id != @logged_in_user.id
      redirect to("#{current}")
    else
      make_status(current, content, false) do
        post.edit(content)
        redirect to("#{current}")
      end
    end
  end

  def make_status(current, content, deny_blank)
    len = content.split(//u).length
    if deny_blank && len == 0
      posting_error = "You didn't enter anything."
    elsif len > 140
      posting_error = "Keep it to 140 characters please!"
    end
    if posting_error
      render_body(current,
                  config.arrangement.home,
                  :page => 1,
                  :posting_error => posting_error) 
    else
      yield content
    end
  end

  def register_mail_address(current, mail_address)
    @logged_in_user.mail_address = mail_address
    redirect to("#{current}")
  end

  def retweet(current, postid)
    Post.retweet(@logged_in_user, postid)
    redirect to("#{current}")
  end

  def delete_hashtag(current, postid, hashtag)
    Post.new(postid).delete_hashtag(hashtag)
    p current 
    redirect to("#{current}")
  end

  def add_hashtag(current, postid, hashtag)
    Post.new(postid).add_hashtag(hashtag)
    p current 
    redirect to("#{current}")
  end

  def generate_personal_menu_item(item)
    case item.intern
    when :home      then link_to('home', '')
    when :mentions  then link_to('mentions', "mentions/#{@logged_in_user.username}/")
    when :profile   then link_to_user(@logged_in_user)
    when :timeline  then link_to('timeline', 'timeline/')
    when :hashtags  then link_to('hashtags', 'hashtags/')
    when :logout    then link_to('logout', 'logout/')
    end
    #config.arrangement[item]
  end

  #attr_reader :logged_in_user, :target_user, :posting_error, :page

  def username(user = nil)
    user ||= @logged_in_user
    "#{t.site.name_prefix}#{user.username}#{t.site.name_suffix}"
  end

  def mail_address(user = nil)
    user ||= @logged_in_user
    user.mail_address
  end

  def get_world_posts(page)
    Timeline.new('timeline').page(config.page_size, page)
  end

  def get_hashtag_posts(hashtag, page)
    HashTag.new(hashtag).page(config.page_size, page)
  end

  def find_user(username)
    User.find_by_username(username)
  end

  def author(post)
    return post.user if post.original_id == post.id
    return Post.new(post.original_id).user
  end

  def gravator(user)
    Digest::MD5.new.update((user.mail_address || "").downcase.strip)
  end

  def escape(s)
    CGI.escape(s)
  end
end
