=begin

BETTERCAP

Author : Simone 'evilsocket' Margaritelli
Email  : evilsocket@gmail.com
Blog   : http://www.evilsocket.net/

This project is released under the GPL 3 license.

=end

module BetterCap
module Proxy

class Response
  attr_reader :content_type, :charset, :content_length, :chunked, :headers, :code, :headers_done
  attr_accessor :body

  def initialize
    @content_type = nil
    @charset = 'UTF-8'
    @content_length = nil
    @body = ''
    @code = nil
    @headers = []
    @headers_done = false
    @chunked = false
  end

  def self.from_socket(sock)
    response = Response.new

    # read all response headers
    loop do
      line = sock.readline

      response << line

      break unless not response.headers_done
    end

    response
  end

  def <<(line)
    # we already parsed the heders, collect response body
    if @headers_done
      @body << line.force_encoding( @charset )
    else
      Logger.debug "  RESPONSE LINE: '#{line.chomp}'"

      # parse the response status
      if @code.nil? and line =~ /^HTTP\/[\d\.]+\s+(.+)/
        @code = $1.chomp

      # parse the content type
      elsif line =~ /^Content-Type:\s*([^;]+).*/i
        @content_type = $1.chomp
        if line =~ /^.+;\s*charset=(.+)/i
          @charset = $1.chomp
        end

      # parse content length
      elsif line =~ /^Content-Length:\s+(\d+)\s*$/i
        @content_length = $1.to_i

      # check if we have a chunked encoding
      elsif line =~ /^Transfer-Encoding:\s*chunked.*$/i
        @chunked = true
        line = nil

      # last line, we're done with the headers
      elsif line.chomp.empty?
        @headers_done = true

      end

      @headers << line.chomp unless line.nil?
    end
  end

  def textual?
    @content_type and ( @content_type =~ /^text\/.+/ or @content_type =~ /^application\/.+/ )
  end

  def to_s
    if textual?
      @headers.map! do |header|
        # update content length in case the body was
        # modified
        if header =~ /Content-Length:\s*(\d+)/i
          Logger.debug "Updating response content length from #{$1} to #{@body.bytesize}"

          "Content-Length: #{@body.bytesize}"
        else
          header
        end
      end
    end

    @headers.join("\n") + "\n" + @body
  end
end

end
end
