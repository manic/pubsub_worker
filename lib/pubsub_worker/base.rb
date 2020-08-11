# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'
require 'google/cloud/pubsub'
require 'json'
require 'logger'

class PubsubWorker::Base
  class << self
    attr_reader :message_handler

    def register_message_handler(&handler)
      @message_handler = handler
    end

    def topic_for(pubsub, topic_name)
      pubsub.topic(topic_name) || pubsub.create_topic(topic_name)
    end

    def subscription_for(pubsub, topic_name, subscription_name = nil)
      subscription_name ||= "#{topic_name}-worker"
      pubsub.subscription(subscription_name) || topic_for(pubsub, topic_name).subscribe(subscription_name)
    end
  end

  def initialize(queue: 'default', pubsub: Google::Cloud::Pubsub.new(timeout: 60), logger: Logger.new($stdout), worker: nil)
    @queue_name  = queue
    @worker_name = worker || "#{queue}-worker"
    @pubsub      = pubsub
    @logger      = logger
  end

  def run
    subscriber = self.class.subscription_for(@pubsub, @queue_name, @worker_name).listen(streams: 1, threads: { callback: 1 }) do |message|
      @logger&.info "Message(#{message.message_id}) was received."
      process message
    end

    subscriber.on_error do |error|
      @logger&.error(error)
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

    @ack_deadline = subscriber.deadline

    subscriber.start

    sleep 1 until @quit
    @logger&.info 'Shutting down...'
    subscriber.stop.wait!
    @logger&.info 'Shut down.'
  end

  def ensure_subscription
    self.class.subscription_for(@pubusb, @queue_name, @worker_name)
    nil
  end

  private

  def process(message)
    timer_opts = {
      # Extend ack deadline when only 10% of allowed time or 5 seconds are left, whichever comes first
      execution_interval: [(@ack_deadline * 0.9).round, @ack_deadline - 5].min.seconds,
      timeout_interval: 5.seconds,
      run_now: true
    }

    delay_timer = Concurrent::TimerTask.execute(timer_opts) do
      message.modify_ack_deadline! @ack_deadline
    end

    begin
      succeeded = false
      failed    = false

      handler = self.class.message_handler
      handler&.call(message) if handler.respond_to?(:call)

      succeeded = true
    rescue StandardError
      failed = true
      raise
    ensure
      delay_timer.shutdown

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
