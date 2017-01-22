# power_assert.rb
#
# Copyright (C) 2014-2017 Kazuki Tsujimoto, All rights reserved.

begin
  unless defined?(Byebug)
    captured = false
    TracePoint.new(:return, :c_return) do |tp|
      captured = true
      unless tp.binding and tp.return_value
        raise ''
      end
    end.enable { __id__ }
    raise '' unless captured
  end
rescue
  raise LoadError, 'Fully compatible TracePoint API required'
end

require 'power_assert/version'
require 'power_assert/configuration'
require 'power_assert/context'

module PowerAssert
  POWER_ASSERT_LIB_DIR = __dir__
  IGNORED_LIBS = {PowerAssert => POWER_ASSERT_LIB_DIR}
  private_constant :POWER_ASSERT_LIB_DIR, :IGNORED_LIBS

  class << self
    def start(assertion_proc_or_source, assertion_method: nil, source_binding: TOPLEVEL_BINDING)
      if respond_to?(:clear_global_method_cache, true)
        clear_global_method_cache
      end
      yield BlockContext.new(assertion_proc_or_source, assertion_method, source_binding)
    end

    def trace(frame)
      begin
        raise 'Byebug is not started yet' unless Byebug.started?
      rescue NameError
        raise "PowerAssert.#{__method__} requires Byebug"
      end
      ctx = TraceContext.new(frame._binding)
      ctx.enable
      ctx
    end

    def app_caller_locations
      filter_locations(caller_locations)
    end

    def app_context?
      top_frame = caller_locations.drop_while {|i| i.path.start_with?(POWER_ASSERT_LIB_DIR) }.first
      top_frame && ! ignored_file?(top_frame.path)
    end

    private

    def filter_locations(locs)
      locs.drop_while {|i| ignored_file?(i.path) }.take_while {|i| ! ignored_file?(i.path) }
    end

    def ignored_file?(file)
      IGNORED_LIBS[Byebug]    = lib_dir(Byebug, :load_settings, 2)      if defined?(Byebug) and ! IGNORED_LIBS[Byebug]
      IGNORED_LIBS[PryByebug] = lib_dir(Pry, :start_with_pry_byebug, 2) if defined?(PryByebug) and ! IGNORED_LIBS[PryByebug]
      IGNORED_LIBS.find do |_, dir|
        file.start_with?(dir)
      end
    end

    def lib_dir(obj, mid, depth)
      File.expand_path('../' * depth, obj.method(mid).source_location[0])
    end

    if defined?(RubyVM)
      def clear_global_method_cache
        eval('using PowerAssert.const_get(:Empty)', TOPLEVEL_BINDING)
      end
    end
  end

  module Empty
  end
  private_constant :Empty
end
