#!/usr/bin/env ruby

$: << File.join(File.dirname(__FILE__), 'lib')

require 'active_support'
require 'active_support/core_ext/hash'

require 'irclogger'
require 'redis'
require 'daemons'
require 'rubygems'
require 'summer'
require 'yaml'

ACTION_PREFIX = "\01ACTION "
DUMMY_STDOUT = StringIO.new

def silenced
  $stdout = DUMMY_STDOUT
  yield
ensure
  $stdout = STDOUT
end

PIDFILE = File.join(File.expand_path(File.dirname(__FILE__)), 'tmp', 'logger.pid')
LOGFILE = File.join(File.expand_path(File.dirname(__FILE__)), 'log', 'logger.log')
CONFIG_FILE = File.join(File.expand_path(File.dirname(__FILE__)), 'config', 'application.yml')

class Bot < Summer::Connection
    def initialize(server=nil, port=6667, dry=false)  
      trap(:TERM) do
        puts "Shutting down on SIGTERM..."
        FileUtils.rm_rf(pid_file)
        exit
      end
      super
    end

    def redis
      self.class.redis
    end
    protected :redis

    class << self
      attr_accessor :redis
    end

    def load_config
        @config = HashWithIndifferentAccess.new(YAML::load_file(CONFIG_FILE))

        # backwards compatibility with whitequark's cinch plugin
        @config['server_password'] = @config['password']
        @config['nick'] = @config['username']
        @config['use_ssl'] = @config['ssl'] || false

        # required by summer
        @config['log_file'] = LOGFILE
        @config['pid_file'] = PIDFILE

      end

    def pid_file
        config[:pid_file]
    end

    # summer's `parse` prints EVERYTHING the bot has received, which is... a lot. 
    def parse(message)
      silenced do
        super
      end
    end

    # silence outgoing messages as well
    def response(message)
      silenced do
        super
      end
    end

    def channel_message(sender, channel, message, options={})
        utcnow = Time.now.utc
        nick = sender[:nick]
        if message.start_with?(ACTION_PREFIX)
            message.delete_prefix(ACTION_PREFIX)
            nick = "* " + nick
        end

        post_message(
          channel: channel,
          timestamp: utcnow,
          nick: nick,
          line: message,
        )
    end

    def post_message(*args)
      message = Message.create(*args)
      redis.publish("message.#{Config['server']}", "#{message.channel} #{message.id}")
    end
end

Bot.redis = Redis.new(url: Config['redis'])
DB.disconnect
Daemonize.daemonize(LOGFILE)
Bot.new()
