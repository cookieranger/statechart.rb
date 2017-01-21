$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'statechart'

RSpec.configure do |config|
  config.expect_with(:rspec) do |c|
    c.syntax = :should
  end

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end
