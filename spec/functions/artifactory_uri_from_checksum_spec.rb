require 'spec_helper'
require 'webmock/rspec'

describe 'archive::artifactory_uri_from_checksum' do
  it { is_expected.not_to eq(nil) }
  it { is_expected.to run.with_params.and_raise_error(ArgumentError) }
  it { is_expected.to run.with_params('not_a_url').and_raise_error(ArgumentError) }

  example_json = File.read(fixtures('aql_response_uri_from_checksum.json'))
  url = 'https://repo.jfrog.org/'
  sha256sum = '33c5796cc9b14b0f4ab8684f928b7b35256ecd42b4f4477dc961548288b13a83'
  bearer_token = '14c63e134b92ccafd8b8aeec07f9083842ba400bcad4d71354bebdaeff7b434a' * 9


  it 'runs like a fox' do
    stub_request(:post, "#{url.sub(%r(/$),'')}/artifactory/api/search/aql").
       with(
         body: "        items.find(\n{\n  \"sha256\": \"#{sha256sum}\"\n}\n        )\n",
         headers: {
        'Accept'=>'*/*',
        'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization'=>"Bearer #{bearer_token}",
        'Content-Type'=>'text/plain',
        'Host'=>'repo.jfrog.org',
        'User-Agent'=>'Ruby'
         }).to_return(status: 200, body: example_json, headers: {})


    is_expected.to run.with_params(
      url,
      bearer_token,
      sha256sum,
    ).and_return('https://repo.jfrog.org/libs-release-local/org/jfrog/artifactory/artifactory.war')
  end

#  it 'parses md5' do
#    #PuppetX::Bodeco::Util.stubs(:content).with(uri).returns(example_json)
#    is_expected.to run.with_params(url, 'md5').and_return('00f32568be85929fe95be38f9f5f3519')
#  end
end

