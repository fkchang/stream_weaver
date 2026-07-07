# frozen_string_literal: true

require 'spec_helper'
require 'socket'

RSpec.describe "StreamWeaver::Service.find_available_port" do
  it 'returns the start port when it is free' do
    server = TCPServer.new('127.0.0.1', 0)
    free_port = server.addr[1]
    server.close
    expect(StreamWeaver::Service.find_available_port(free_port)).to eq(free_port)
  end

  it 'skips past a busy port to the next free one' do
    server = TCPServer.new('127.0.0.1', 0)
    busy_port = server.addr[1]
    expect(StreamWeaver::Service.find_available_port(busy_port)).to be > busy_port
  ensure
    server.close
  end
end
