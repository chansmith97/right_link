#
# Copyright (c) 2009-2011 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

begin
  require 'chef/exceptions'
rescue LoadError => e
  # Make sure we're dealing with a legitimate missing-file LoadError
  raise e unless e.message =~ /^no such file to load/

  # Do not require the chef gem to be installed just to load this code
  module Chef
    class Exceptions
      class Exec < RuntimeError; end
    end
  end
end

module RightScale
  # Extend the set of RightScale extensions
  class Exceptions
    class WrongState < RuntimeError; end
    class Exec < Chef::Exceptions::Exec
      def initialize(msg, cwd=nil)
        super(msg)
        @path = cwd
      end
      attr_reader :path    # Path where command was run
    end
    class RightScriptExec < RightScale::Exceptions::Exec; end
  end
end
