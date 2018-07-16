require 'spec_helper'

module Beaker
  describe Vmpooler do

    before :each do
      stub_const( "Net", MockNet )
      allow( JSON ).to receive( :parse ) do |arg|
        arg
      end
      allow( Socket ).to receive( :getaddrinfo ).and_return( true )
      allow_any_instance_of( Beaker::Vmpooler ).to \
        receive(:load_credentials).and_return(fog_file_contents)
    end

    describe '#get_template_url' do

      it 'works returns the valid url when passed valid pooling_api and template name' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        uri = vmpooler.get_template_url("http://pooling.com", "template")
        expect( uri ).to be === "http://pooling.com/vm/template"
      end

      it 'adds a missing scheme to a given URL' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        uri = vmpooler.get_template_url("pooling.com", "template")
        expect( URI.parse(uri).scheme ).to_not be === nil
      end

      it 'raises an error on an invalid pooling api url' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        expect{ vmpooler.get_template_url("pooling###   ", "template")}.to raise_error ArgumentError
      end

      it 'raises an error on an invalide template name' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        expect{ vmpooler.get_template_url("pooling.com", "t!e&m*p(l\\a/t e")}.to raise_error ArgumentError
      end
    end

    describe '#add_tags' do
      let(:vmpooler) { Beaker::Vmpooler.new(make_hosts({:host_tags => {'test_tag' => 'test_value'}}), make_opts) }

      it 'merges tags correctly' do
        vmpooler.instance_eval {
          @options = @options.merge({:project => 'vmpooler-spec'})
        }
        host          = vmpooler.instance_variable_get(:@hosts)[0]
        merged_tags   = vmpooler.add_tags(host)
        expected_hash = {
            test_tag:       'test_value',
            beaker_version: Beaker::Version::STRING,
            project:        'vmpooler-spec'
        }
        expect(merged_tags).to include(expected_hash)
      end
    end

    describe '#disk_added?' do
      let(:vmpooler) { Beaker::Vmpooler.new(make_hosts, make_opts) }
      let(:response_hash_no_disk) {
        {
            "ok" => "true",
            "hostname" => {
                "template"=>"redhat-7-x86_64",
                "domain"=>"delivery.puppetlabs.net"
            }
        }
      }
      let(:response_hash_disk) {
        {
            "ok" => "true",
            "hostname" => {
                "disk" => [
                    '+16gb',
                    '+8gb'
                ],
                "template"=>"redhat-7-x86_64",
                "domain"=>"delivery.puppetlabs.net"
            }
        }
      }
      it 'returns false when there is no disk' do
        host = response_hash_no_disk['hostname']
        expect(vmpooler.disk_added?(host, "8", 0)).to be(false)
      end

      it 'returns true when there is a disk' do
        host = response_hash_disk["hostname"]
        expect(vmpooler.disk_added?(host, "16", 0)).to be(true)
        expect(vmpooler.disk_added?(host, "8", 1)).to be(true)
      end
    end

    describe "#provision" do

      it 'provisions hosts from the pool' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        allow( vmpooler ).to receive( :require ).and_return( true )
        allow( vmpooler ).to receive( :sleep ).and_return( true )
        vmpooler.provision

        hosts = vmpooler.instance_variable_get( :@hosts )
        hosts.each do | host |
          expect( host['vmhostname'] ).to be === 'pool'
        end
      end

      it 'raises an error when a host template is not found in returned json' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )

        allow( vmpooler ).to receive( :require ).and_return( true )
        allow( vmpooler ).to receive( :sleep ).and_return( true )
        allow( vmpooler ).to receive( :get_host_info ).and_return( nil )

        expect {
          vmpooler.provision
        }.to raise_error( RuntimeError,
                          /Vmpooler\.provision - requested VM templates \[.*\,.*\,.*\] not available/
             )
      end

      it 'repeats asking only for failed hosts' do
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )

        allow( vmpooler ).to receive( :require ).and_return( true )
        allow( vmpooler ).to receive( :sleep ).and_return( true )
        allow( vmpooler ).to receive( :get_host_info ).with(
            anything, "vm1_has_a_template" ).and_return( nil )
        allow( vmpooler ).to receive( :get_host_info ).with(
            anything, "vm2_has_a_template" ).and_return( 'y' )
        allow( vmpooler ).to receive( :get_host_info ).with(
            anything, "vm3_has_a_template" ).and_return( 'y' )

        expect {
          vmpooler.provision
        }.to raise_error( RuntimeError,
                          /Vmpooler\.provision - requested VM templates \[[^\,]*\] not available/
             ) # should be only one item in the list, no commas
      end
    end

    describe "#cleanup" do

      it "cleans up hosts in the pool" do
        mock_http = MockNet::HTTP.new( "host", "port" )
        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        vmpooler.provision
        vm_count = vmpooler.instance_variable_get( :@hosts ).count

        expect( Net::HTTP ).to receive( :new ).exactly( vm_count ).times.and_return( mock_http )
        expect( mock_http ).to receive( :request ).exactly( vm_count ).times
        expect( Net::HTTP::Delete ).to receive( :new ).exactly( vm_count ).times
        expect{ vmpooler.cleanup }.to_not raise_error
      end
    end
  end

  describe Vmpooler do

    before :each do
      stub_const( "Net", MockNet )
      allow( JSON ).to receive( :parse ) do |arg|
        arg
      end
      allow( Socket ).to receive( :getaddrinfo ).and_return( true )
    end

    describe "#load_credentials" do

      it 'loads credentials from a fog file' do
        credentials = { :vmpooler_token => "example_token" }
        make_opts = { :dot_fog => '.fog' }

        expect_any_instance_of( Beaker::Vmpooler ).to receive( :get_fog_credentials ).and_return(credentials)

        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )
        expect( vmpooler.credentials ).to be == credentials
      end

      it 'continues without credentials when there are problems loading the fog file' do
        logger = double( 'logger' )
        make_opts = { :logger => logger, :dot_fog => '.fog' }

        expect_any_instance_of( Beaker::Vmpooler ).to receive( :get_fog_credentials ).and_raise( ArgumentError, 'something went wrong' )
        expect( logger ).to receive( :warn ).with( /Invalid credentials file.*something went wrong.*Proceeding without authentication/m )

        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )

        expect( vmpooler.credentials ).to be == {}
      end

      it 'continues without credentials when fog file has no vmpooler_token' do
        logger = double( 'logger' )
        make_opts = { :logger => logger, :dot_fog => '.fog' }

        expect_any_instance_of( Beaker::Vmpooler ).to receive( :get_fog_credentials ).and_return( {} )
        expect( logger ).to receive( :warn ).with( /vmpooler_token not found in credentials file.*Proceeding without authentication/m )

        vmpooler = Beaker::Vmpooler.new( make_hosts, make_opts )

        expect( vmpooler.credentials ).to be == {}
      end
    end
  end
end
