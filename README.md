porot
=====

An example Twitter application fork from retwis-rb.
See https://github.com/danlucraft/retwis-rb.

 * Probably fast (because of Redis backend)
 * Mention support
 * Hashtag support
 * Retweet support
 * You can custom top-level menu (By default, home menu shows not one's followees but all members, because this project is focused on local network)
 * You can make own language file (ja/en files are already exist)
 * Almost all designs are by css (no image files used now)

Starting Application
--------------------

Follow instruction of retwis-rb after install some gems.

 * sudo gem install redis
 * sudo gem install sinatra-r18n

Major modification from retwis-rb
---------------------------------

 * Use public redis binding instead of rubyredis.rb.

Requirements
------------

 * Ruby
 * Sinatra: sudo gem install sinatra
 * Redis: http://code.google.com/p/redis/
 * Redis binding: sudo gem install redis

Notice
------

If you are already using an older version (< 2012/04/18), do
  * ruby migrate-20120418.rb

License
-------

MIT
