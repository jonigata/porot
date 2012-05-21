# -*- coding: utf-8 -*-

require 'rubygems'
require 'open-uri'
require 'json'
require 'date'

URL = "http://pokecial-dev/porot"

def make_date(s)
  t = Time.parse(s)
  Date.new(t.year, t.month, t.mday)
end

def write_archive_to_dokuwiki(pagename, archive)
  require "xmlrpc/client"

  client = XMLRPC::Client.new( "pokecial-dev","/dokuwiki/lib/exe/xmlrpc.php")
  client.user = 'hirayama'
  client.password = 'autodesk'

  begin
    attrs = {
      :sum => "porot_archiver",
      :minor => false
    }

    client.call("wiki.putPage", pagename, archive, attrs)
  rescue XMLRPC::FaultException => e
    puts "Error:"
    puts e.faultCode
    puts e.faultString
  end
end

def archive_user(username)
  first_date = nil
  last_date = nil

  open("#{URL}/first_date/#{username}/") do |f|
    first_date = make_date(f.read)
  end

  open("#{URL}/last_date/#{username}/") do |f|
    last_date = make_date(f.read)
  end

  first_date = Date.new(first_date.year, first_date.month, 1)
  last_date = Date.new(last_date.year, last_date.month, 1)
  last_date >>= 1

  archive_url = "#{URL}/archive/#{username}/#{first_date.strftime("%Y-%m-%d")}/#{last_date.strftime("%Y-%m-%d")}/"
  #puts archive_url

  tweets = nil
  open(archive_url) do |f|
    tweets = JSON.parse(f.read)
  end

  toc = "====== #{username}の発言 ======\n"

  archives = []
  current = Date.new(1, 1, 1)
  archive = nil
  tweets.reverse.each do |created_at, content|
    t = Time.parse(created_at)
    this_month = Date.new(t.year, t.month, 1)
    if Date.new(current.year, current.month, 1) < this_month
      # 月更新
      if archive
        archives.push [current, archive]
      end
      current = this_month
      archive = "====== #{username} #{current.strftime('%Y年%m月')} ======\n"
      if t.day == 1
        archive << "===== #{t.day}日 =====\n"
      end        
    end
    this_day = Date.new(t.year, t.month, t.day)
    if current < this_day
      # 日更新
      archive << "===== #{t.day}日 =====\n"
      current = this_day
    end
    archive << "  * #{content} (#{t.day}日 #{t.hour}時#{t.min}分)\n"
  end
  archives.push [current, archive]

  # toc

  toc = "====== #{username} の発言アーカイブ ======\n"
  archives.each do |d,c |
    toc << "  * [[.:#{username}:#{d.strftime("%Y-%m")}|#{d.strftime("%Y年%m月")}]]\n"
  end

  write_archive_to_dokuwiki(":porot_logs:#{username}", toc)

  # each month
  archives.each do |d, c|
    write_archive_to_dokuwiki(
      ":porot_logs:#{username}:#{d.strftime("%Y-%m")}", c)
  end
end

def archive_all
  # users

  users_url = "#{URL}/users/"
  users = nil
  open(users_url) do |f|
    users =  JSON.parse(f.read)
  end

  puts "make users..."

  text = "====== porot 発言アーカイブ ======\n"
  users.each do |user|
    text << "  * [[.:porot_logs:#{user}|#{user}の発言]]\n"
  end
  write_archive_to_dokuwiki(":porot_logs", text)

  # each user
  users.each do |user|
    puts "archiving #{user}..."
    archive_user(user)
  end
end

archive_all
