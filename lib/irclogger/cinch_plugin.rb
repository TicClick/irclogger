require 'cinch'

module IrcLogger
  class CinchPlugin
    include Cinch::Plugin

    class << self
      attr_accessor :redis
    end

    def redis
      self.class.redis
    end
    protected :redis

    def post_message(*args)
      message = Message.create(*args)
      redis.publish("message.#{Config['server']}", "#{message.channel} #{message.id}")
    end

    def options(message, other_options={})
      {
        channel:   message.channel,
        timestamp: message.time
      }.merge(other_options)
    end

    listen_to :channel, method: :on_channel
    def on_channel(m)
      unless m.action?
        post_message(options(m,
            nick: m.user.nick,
            line: m.message))
      end
    end

    listen_to :action, method: :on_action
    def on_action(m)
      post_message(options(m,
          nick: "* " + m.user.nick,
          line: m.action_message))
    end
  end
end
