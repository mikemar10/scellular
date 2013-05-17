#!/usr/bin/env ruby

# Copyright 2013 Mike Martin <mike@unsupported.me>

require 'bundler/setup'
require 'fog'

settings = YAML.load_file('config.yaml')

# STATES
# Start - check current status against "min" and "max" settings every "poll" seconds  <-|
# | sleep 0 - "jitter" seconds                                                          |
# |-> Incubate - check monitor scripts every "poll" seconds                             | sleep "cooldown" 
# |   | sleep 0 - "jitter" seconds                                                      | seconds + 0 - "jitter"
# |-> |-> Split - execute split script and wait for completion up to "retry" times -----|
# |       
# |-> Die - destroy self

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
      # TODO - attempt to destroy self
      sleep(settings["cooldown"])

  end
end
