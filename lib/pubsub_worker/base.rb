# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'
require 'google/cloud/pubsub'
require 'json'
require 'logger'

class PubsubWorker::Base
  class << self
    attr_reader :message_handlers

    def register_message_handler(topic, &handler)
      @message_handlers ||= {}
      @message_handlers[topic] = handler

    end

    def topic_for(pubsub, topic_name)
      pubsub.topic(topic_name) || pubsub.create_topic(topic_name)
    end

    def subscription_for(pubsub, topic_name, subscription_name = nil)
      subscription_name ||= "#{topic_name}-worker"
      pubsub.subscription(subscription_name) || topic_for(pubsub, topic_name).subscribe(subscription_name)
    end
  end

  def initialize(pubsub: Google::Cloud::Pubsub.new(timeout: 60), logger: Logger.new($stdout), topics: ['default'], subscription_suffix: 'worker')
    @topics = topics
    @subscription_suffix = subscription_suffix
    @pubsub      = pubsub
    @logger      = logger
  end

  def run
    @subscriptions = []
    @topics.each do |topic|
      subscription_name = "#{topic}-#{@subscription_suffix}"
      sub = self.class.subscription_for(@pubsub, topic, subscription_name).listen(streams: 1, threads: { callback: 1 }) do |message|
        process topic, message
      end

      sub.on_error do |error|
        @logger&.error(error)
      end

      sub.start
      @subscriptions << sub
    end

    @quit = false
    Signal.trap(:QUIT) do
      @quit = true
    end
    Signal.trap(:TERM) do
      @quit = true
    end
    Signal.trap(:INT) do
      @quit = true
    end

    sleep 1 until @quit
    @logger&.info 'Shutting down...'
    @subscriptions.each { |sub| sub.stop.wait! }
    @logger&.info 'Shut down.'
  end

  def process(topic, message)
    begin
      succeeded = false
      failed    = false

      handler = self.class.message_handlers[topic]
      handler&.call(message) if handler.respond_to?(:call)

      succeeded = true
    rescue StandardError
      failed = true
      raise
    ensure
      if succeeded || failed
        message.acknowledge!
        @logger&.info "Message(#{message.message_id}) was acknowledged."
      else
        # terminated from outside
        message.reject!
      end
    end
  end
end
