module Hookable
  def self.extended(base)
    base.instance_variable_set(:@included_hooks, [])
    base.instance_variable_set(:@setup_hooks, []) # unless base.instance_variable_defined?(:@setup_hooks)
  end

  def on_included(&block)
    included_hooks << block
  end

  def on_setup(&block)
    setup_hooks << block
  end

  def included(base)
    super if defined?(super)

    base.extend ClassMethods

    host_hooks = base.instance_variable_defined?(:@setup_hooks) ?
                      base.instance_variable_get(:@setup_hooks) :
                      []
    merged = host_hooks + setup_hooks
    base.instance_variable_set(:@setup_hooks, merged)

    included_hooks.each { |blk| blk.call(base) }
  end

  def included_hooks
    @included_hooks
  end

  def setup_hooks
    @setup_hooks
  end

  module ClassMethods
    def unique_option(name, opts = {})
      option(name, opts) unless options.find { |existing_option| existing_option.name == name }
    end

    def setup(**args)
      setup_hooks.each { |blk| blk.call(**args) }
    end

    def on_setup(&block)
      setup_hooks << block
    end

    def setup_hooks
      @setup_hooks
    end
  end
end
