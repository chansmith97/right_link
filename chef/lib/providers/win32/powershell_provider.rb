#
# Copyright (c) 2010 RightScale Inc
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

require 'fileutils'
require 'chef/provider/execute'

class Chef

  class Provider

    # Powershell chef provider.
    class Powershell < Chef::Provider::Execute

      # use a unique dir name instead of cluttering temp directory with leftover
      # scripts like the original script provider.
      SCRIPT_TEMP_DIR_PATH = ::File.join(::Dir.tmpdir, "chef-powershell-06D9AC00-8D64-4213-A46A-611FBAFB4426")

      # No concept of a 'current' resource for Powershell execution, this is a no-op
      #
      # === Return
      # true:: Always return true
      def load_current_resource
        true
      end

      # Actually run Powershell
      # Rely on RightScale::popen3 to spawn process and receive both standard and error outputs.
      # Synchronize with EM thread so that execution is synchronous even though RightScale::popen3 is asynchronous.
      #
      # === Return
      # true:: Always return true
      #
      # === Raise
      # RightScale::Exceptions::Exec:: Invalid process exit status
      def action_run
        nickname         = @new_resource.name
        source           = @new_resource.source
        script_file_path = @new_resource.source_path
        parameters       = @new_resource.parameters
        current_state    = instance_state

        # 1. Write script source into file, if necessary.
        if script_file_path
          (raise RightScale::Exceptions::Exec, "Missing script file \"#{script_file_path}\"") unless ::File.file?(script_file_path)
        else
          FileUtils.mkdir_p(SCRIPT_TEMP_DIR_PATH)
          script_file_path = ::File.join(SCRIPT_TEMP_DIR_PATH, "powershell_provider_source.ps1")
          ::File.open(script_file_path, "w") { |f| f.write(source) }
        end

        begin
          # 2. Setup environment.
          parameters.each { |key, val| ENV[key] = val }
          ENV['RS_REBOOT'] = current_state.past_scripts.include?(nickname) ? '1' : nil

          # 3. execute and wait
          command = format_command(script_file_path)
          @new_resource.command(command)
          ::Chef::Log.info("Running \"#{nickname}\"")
          super

          # super provider raises an exception on failure, so record success at
          # this point.
          current_state.record_script_execution(nickname)
          @new_resource.updated = true
        ensure
          (FileUtils.rm_rf(SCRIPT_TEMP_DIR_PATH) rescue nil) if ::File.directory?(SCRIPT_TEMP_DIR_PATH)
        end

        true
      end

      protected

      def instance_state
        RightScale::InstanceState
      end

      # Formats a command to run the given powershell script.
      #
      # === Parameters
      # script_file_path(String):: powershell script file path
      #
      # == Returns
      # command(String):: command to execute
      def format_command(script_file_path)
        platform = RightScale::RightLinkConfig[:platform]
        shell    = platform.shell

        return shell.format_powershell_command4(@new_resource.interpreter, nil, nil, script_file_path)
      end

    end
  end
end

# self-register
Chef::Platform.platforms[:windows][:default].merge!(:powershell => Chef::Provider::Powershell)