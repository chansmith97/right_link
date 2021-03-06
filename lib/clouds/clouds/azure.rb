#
# Copyright (c) 2012 RightScale Inc
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
require 'right_agent'

module RightScale::Clouds
  class Azure < RightScale::Cloud
    # RightApi API version for use in X-API-Version header
    API_VERSION = "1.5"

    # Default time to wait for HTTP connection to open
    DEFAULT_OPEN_TIMEOUT = 30

    # Default time to wait for response from request, which is chosen to be 300 seconds
    # The same as Timeout in RightAPI
    DEFAULT_REQUEST_TIMEOUT = 300

    # Maximum wait interval 5 min
    MAX_WAIT_INTERVAL = 300

    # Retrieve new user-data from RightApi
    #
    # @param [String] RigthtApi url
    # @param [String] Client ID
    # @param [String] Client Secret
    # @param [Block] Yield on block with retieved data
    #
    # @return [TrueClass] always true
    def retrieve_updated_data(api_url, client_id, client_secret)

      options = {
        :api_version => API_VERSION,
        :open_timeout => DEFAULT_OPEN_TIMEOUT,
        :request_timeout => DEFAULT_REQUEST_TIMEOUT,
        :filter_params => [:client_secret] }
      url = URI.parse(api_url)

      success = false
      wait = 5

      while !success do

        begin
          data = nil
          http_client = RightScale::BalancedHttpClient.new([url.to_s], options)
          response = http_client.post("/oauth2", {
            :client_id => client_id.to_s,
            :client_secret => client_secret,
            :grant_type => "client_credentials" } )
          response = RightScale::SerializationHelper.symbolize_keys(response)
          access_token = response[:access_token]
          raise "Could not authorized on #{api_url} using oauth2" if access_token.nil?

          response = http_client.get("/user_data", {
            :client_id => client_id.to_s,
            :client_secret => client_secret },
             { :headers => {"Authorization" => "Bearer #{access_token}" } })
          data = response.to_s
          close_message = "Got updated user metadata. Continue."
          success = true
        rescue RightScale::HttpExceptions::ResourceNotFound => e
          if e.to_s =~ /No route matches "\/api\/user_data"/
            data = ''
            close_message = "Rightscale does not support user metadata update. Skipping."
            success = true
          else
            logger.error "Error: #{e.message}"
            close_message = e
          end
        rescue Exception => e
          if e.to_s =~ /Couldn't find ExtraUserData with key = #{client_id}/
            data = ''
            close_message = "No Updated userdata exists"
            success = true
          else
            logger.error "Error: #{e.message}"
            close_message = e.message
          end
        ensure
          http_client.close(close_message) if http_client
        end

        unless success
          logger.error "Sleeping #{wait} seconds before retry"
          sleep(wait) unless success
          wait = [wait * 2, MAX_WAIT_INTERVAL].min
        end
      end

      return data
    end

    # Parses azure user metadata into a hash.
    #
    # === Parameters
    # data(String):: raw data
    #
    # === Return
    # result(Hash):: Hash-like leaf value
    def get_updated_userdata(data)
      result = RightScale::CloudUtilities.parse_rightscale_userdata(data)
      api_url       = "https://#{result['RS_server']}/api"
      client_id     = result['RS_rn_id']
      client_secret = result['RS_rn_auth']
      new_userdata = retrieve_updated_data(api_url, client_id , client_secret)
      if (new_userdata.to_s.empty?)
        return data
      else
        return new_userdata
      end
    end

    # def parse_metadata(tree_climber, data)
    #   result = tree_climber.create_branch
    #   data.each do |k, v|
    #     # Make sure we coerce into strings. The json blob returned here auto-casts
    #     # types which will mess up later steps
    #     result[k.to_s.strip] = v.to_s.strip
    #   end
    #   result
    # end

    def wait_for_instance_ready
      # On a rebundle, the cert file may exist but be from a previous launch. No way of fixing this, as the
      # modified time of the cert_file will be older than the booted time on start/stop (its not refreshed)
      # and newer than the booted time on a normal boot. Customers have to know to clean /var/lib/waagent.
      #
      # If we want to support wrap on linux we need an alternate check, such as checking
      # some sort of status on waagent and a time
      if platform.linux?
        STDOUT.puts "Waiting for instance to appear ready."
        until File.exists?(fetcher.user_metadata_cert_store)
          sleep(1)
        end
        STDOUT.puts "Instance appears ready."
      end
    end

    def abbreviation
      "azure"
    end

    def self.cloud_name
      "azure"
    end

    def fetcher
      @fetcher ||= RightScale::MetadataSources::AzureMetadataSource.new(@options)
    end

    def userdata_raw
      userdata = fetcher.userdata
      get_updated_userdata(userdata)
    end

    def metadata
      fetcher.metadata
    end
  end
end


