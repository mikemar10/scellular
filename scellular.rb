#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike@unsupported.me>

require 'bundler/setup'
require 'fog'
require 'socket'

# TODO - make config file location configurable
# TODO - Switch to INI file format
settings = YAML.load_file(File.expand_path('~/.scellular.conf'))

# STATES
# Start - check current status against "min" and "max" settings every "poll" seconds  <-|
# | sleep 0 - "jitter" seconds                                                          |
# |-> Incubate - check monitor scripts every "poll" seconds                             | sleep "cooldown" 
# |   | sleep 0 - "jitter" seconds                                                      | seconds + 0 - "jitter"
# |-> |-> Split - execute split script and wait for completion up to "retry" times -----|
# |       
# |-> Die - destroy self

# TODO - daemonize
# TODO - Add CLI options
# TODO - Pick license
# TODO - Define monitor return values
# TODO - Define split script return values
# TODO - Create providers
# TODO - Generate unique identifier of each server.
# TODO - Figure out how to have server identify itself

service = Fog::Compute.new({
  :provider           => 'rackspace',
  :rackspace_username => settings["username"],
  :rackspace_api_key  => settings["api_key"],
  :version            => :v2,
  :rackspace_region   => settings["region"].to_sym
})
  
all_servers = service.servers.select {|s| s.state == "ACTIVE"}
local_ipv4_addresses = Socket.ip_address_list.select {|ip| ip.ipv4? and !ip.ipv4_loopback?}.map(&:ip_address)
local_server = {}
all_servers.each do |s|
  server_addresses = s.addresses.values.flatten.collect {|ip| ip["addr"] if ip["version"] == 4}.reject(&:nil?)
  local_server[s.id] = (server_addresses - local_ipv4_addresses).length
end

# TODO - Should this only return if the score was 0?
local_server = all_servers.select {|s| s.id == local_server.sort_by {|id, score| score}.first[0] }.first
  
current_state = :start

loop do
  case current_state

    when :start
      # TODO - Check current cell count
      if cell_count < settings["max"]
        if cell_count < settings["min"]
          current_state = :split
        else
          sleep(rand(settings["jitter"]))
          current_state = :incubate
        end
      else
          current_state = :die
      end
      sleep(settings["poll"])

    when :incubate
      # TODO - Check monitors
      results = [0,0,1,1]
      if results.select{|r| r == 0}.length() >= settings["threshold"]
        sleep(rand(settings["jitter"]))
        current_state = :split
      end
      sleep(settings["poll"]) 

    when :split
      settings["retry"].times do
        # TODO - Run split script
        break if success
      end
      sleep(settings["cooldown"] + rand(settings["jitter"]))
      current_state = :start

    when :die
      local_server.destroy
      sleep(settings["cooldown"])

  end
end
