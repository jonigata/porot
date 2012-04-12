require 'yaml'

class Configuration
  def initialize(obj)
    @obj = obj
  end

  def [](index)
    index = index.to_s if index.kind_of?(Symbol) 
    envelope(@obj[index])
  end

  def method_missing(action, *args)
    p = @obj[action.to_s] || super
    envelope(p)
  end

  private
  def envelope(p)
    p.kind_of?(Hash) ? Configuration.new(p) : p
  end
end

def config
  $config ||= Configuration.new(YAML.load_file("config/config.yml"))
end
