# frozen_string_literal: true

require 'spec_helper'

require 'json'
require 'timeout'

describe PubsubWorker::Base, :use_pubsub_emulator do
  it 'test callback register' do
    PubsubWorker::Base.register_message_handler do |msg|
      "Hello, #{msg}"
    end
    expect(PubsubWorker::Base.message_handler.call('World')).to eql('Hello, World')
  end
end
