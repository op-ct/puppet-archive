require 'json'
require 'puppet_x/bodeco/util'

Puppet::Functions.create_function(:'archive::artifactory_uri_from_checksum') do
  # @summary A function that returns the checksum value of an artifact stored in Artifactory
  # @param url The URL to the Artifactory server
  # @param bearer_token The Artifactory access token
  #   This is used in the HTTP header as `Authorization: Bearer <TOKEN>`
  # @param checksum The checksum to lookup
  # @param checksum_type The checksum type.
  #        Note the function will raise an error if you ask for sha256 but your artifactory instance doesn't have the sha256 value calculated.
  # @return [String] Returns the checksum.
  dispatch :artifactory_uri_from_checksum do
    param 'Stdlib::HTTPUrl', :url
    param 'String', :bearer_token
    param 'Pattern[/^[0-9a-f]+$/]', :checksum
    optional_param "Enum['sha1','sha256','md5']", :checksum_type
    optional_param 'Stdlib::Absolutepath', :ssl_ca_file
    optional_param "Enum['verify','none']", :ssl_verify
    return_type 'String'
  end

  def artifactory_uri_from_checksum(
    url,
    bearer_token,
    checksum,
    checksum_type = 'sha256',
    ssl_ca_file = nil,
    ssl_verify = nil
  )
    # TODO
    # - [x] HTTP handler
    #   - [x] SSL
    # - [x] token in header
    # - [x] special post body in AQL
    # - [ ] parse JSON
    # - [ ] return just URI

    opts = {
      headers: { 'Authorization' => "Bearer #{bearer_token}" },
      content_type: 'text/plain',
      body: <<-AQL.gsub(/^ {10}/,'')
        items.find(
          {
            "#{checksum_type}": "#{checksum}"
          }
        )
      AQL
    }
    opts[:ca_file] = ssl_ca_file if ssl_ca_file
    opts[:verify_mode] = ssl_verify if ssl_verify

    uri= URI.parse("#{url.sub(%r(/$),'')}/artifactory/api/search/aql")
    response = http(
      uri,
      Net::HTTP::Post,
      opts
    )


    content  = JSON.parse(response.body)
    artifact = content['results'].first
    artifact_url   = "#{uri.scheme}://#{uri.hostname}/#{artifact['repo']}/#{artifact['path']}/#{artifact['name']}"
#    raise("Could not parse #{checksum_type} from url: #{url}\nresponse: #{response.body}") unless checksum =~ %r{\b[0-9a-f]{5,64}\b}
    artifact_url
  end

  # All-purpose MRI-only HTTP swiss army knife
  def http(uri, http_type = Net::HTTP::Get, opts = {})
    uri.query = URI.encode_www_form(opts[:params]) if opts[:params]

    request = http_type.new(uri)

    opts.fetch(:headers,{}).each do |header, content|
      request[header] = content
    end
    request.content_type = opts.fetch(:content_type, 'application/json')
    request.body = opts[:body] if opts[:body]

    http = Net::HTTP.new(uri.hostname, uri.port, opts)
    if opts[:use_ssl] || uri.scheme == 'https'
      http.use_ssl = true
      http.ca_file = opts[:ca_file] if opts.key?(:ca_file)
      http.verify_mode = opts[:verify_mode] || OpenSSL::SSL::VERIFY_PEER
    end
    response = http.request(request)

    # TODO: test failures
    unless response.code =~ /^2\d\d/
      fail "\n\nERROR: Unexpected HTTP response from:" + \
           "\n       #{response.uri}\n" + \
           "\n       Response code_type: #{response.code_type} " + \
           "\n       Response code:      #{response.code} " +
           opts.fetch(:show_debug_response,false) ? (
             "\n       Response body: " + \
             "\n         #{JSON.parse(response.body)} \n\n" + \
             "\n       Request body: " + \
             "\n#{JSON.parse(request.body).to_yaml.split("\n").map{|x| ' '*8+x}.join("\n")} \n\n"
           ) : ''
    end

    response
  end
end
