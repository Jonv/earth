module Mocha
  
  module ParameterMatchers

    # :call-seq: regexp_matches(regexp) -> parameter_matcher
    #
    # Matches any object that matches the regular expression, +regexp+.
    #   object = mock()
    #   object.expects(:method_1).with(regexp_matches(/e/))
    #   object.method_1('hello')
    #   # no error raised
    #
    #   object = mock()
    #   object.expects(:method_1).with(regexp_matches(/a/))
    #   object.method_1('hello')
    #   # error raised, because method_1 was not called with a parameter that matched the 
    #   # regular expression
    def regexp_matches(regexp)
      RegexpMatches.new(regexp)
    end

    class RegexpMatches # :nodoc:
  
      def initialize(regexp)
        @regexp = regexp
      end
  
      def ==(parameter)
        parameter =~ @regexp
      end
  
      def mocha_inspect
        "regexp_matches(#{@regexp.mocha_inspect})"
      end
  
    end
    
  end
  
end
