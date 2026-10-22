require "rbconfig"

[:CONFIG, :MAKEFILE_CONFIG].each do |name|
  config = RbConfig.const_get(name)
  config["rubyarchhdrdir"] = config.fetch("rubyarchhdrdir").sub("universal-darwin22", "universal-darwin23")
end
