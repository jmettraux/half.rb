
#
# specifiying mycourt_client.rb
#
# Wed Oct  9 12:54:50 JST 2013
#

require 'spec_helper'


class FakeHttpResponse

  attr_reader :body

  def initialize(body)

    @body =
      body.is_a?(String) ? body : Rufus::Json.encode(body)
  end
end

class FakeClient

  attr_reader :last_request

  def request(method, uri, body)

    @last_request = { :method => method, :uri => uri, :body => body }

    nil
  end
end


describe HalfClient::Response do

  describe '#link' do

    before :all do

      @response =
        HalfClient::Response.new(
          nil,
          FakeHttpResponse.new(
            '_links' => {
              'https://half.example.com/rels#auth_confirmation' => {
                'href' => 'https://half.example.com/api/auth/1180',
                'method' => 'POST'
              }
            }))
    end

    it 'returns the first matching link' do

      @response.link('#auth_confirmation').should ==
        { 'href' => 'https://half.example.com/api/auth/1180',
          'method' => 'POST' }
    end
  end

  context 'http methods' do

    before :each do

      @client = FakeClient.new

      @response =
        HalfClient::Response.new(
          @client,
          FakeHttpResponse.new(
            {
              '_links' => {
                'self' => {
                  'href' => 'https://half.example.com/api'
                },
                'https://half.example.com/rels#my-clubs' => {
                  'href' => 'https://half.example.com/api/clubs'
                },
                'https://half.example.com/rels#reservations' => {
                  'href' =>
                    'https://half.example.com/api/reservations/{clubId}/{day}',
                  'templated' => true
                },
                'https://half.example.com/rels#members' => {
                  'href' =>
                    'https://half.example.com/api/members/{clubId}{?query,count}',
                  'templated' => true
                },
                'https://half.example.com/rels#reserve' => {
                  'href' => 'https://half.example.com/api/reservation',
                  'method' => 'POST',
                  'fields' => [
                    { 'name' => 'clubId', 'required' => true },
                    { 'name' => 'courtId', 'required' => true },
                    { 'name' => 'day', 'required' => true },
                    { 'name' => 'start', 'required' => true },
                    { 'name' => 'end', 'required' => true },
                    { 'name' => 'player1Id', 'default' => nil },
                    { 'name' => 'player2Id' },
                    { 'name' => '_aft', 'value' => 'e7C2vM3...' }
                  ]
                },
                'https://half.example.com/rels#bookmark-add' => {
                  'href' => 'https://half.example.com/api/bookmark/{clubId}',
                  'method' => 'POST',
                  'templated' => true
                },
                'https://half.example.com/rels#bookmark-remove' => {
                  'href' =>
                    'https://half.example.com/api/bookmark/{clubId}',
                  'method' => 'DELETE',
                  'templated' => true
                },
                'https://half.example.com/rels#whatever-update' => {
                  'href' =>
                    'https://half.example.com/api/whatever-update',
                  'method' => 'PUT'
                }
              },
              'version' => '1.0'
            }
          ))
    end

    describe '#get' do

      it 'gets self' do

        @response.get('self')

        @client.last_request[:method].should == :get
        @client.last_request[:uri].should == 'https://half.example.com/api'
        @client.last_request[:body].should == nil
      end

      it 'gets #my-clubs' do

        @response.get('#my-clubs')

        @client.last_request[:uri].should ==
          'https://half.example.com/api/clubs'
      end

      it 'gets https://half.example.com/rels#my-clubs' do

        @response.get('https://half.example.com/rels#my-clubs')

        @client.last_request[:uri].should ==
          'https://half.example.com/api/clubs'
      end

      it "raises an ArgumentError if the rel doesn't exist" do

        lambda {
          @response.get('#flip-burger')
        }.should raise_error(
          ArgumentError, "no link found for '#flip-burger'"
        )
      end

      it "raises an ArgumentError if the rel doesn't point to a GET link" do

        lambda {
          @response.get('#reserve')
        }.should raise_error(
          ArgumentError, 'link method is POST, not GET'
        )
      end

      context '"templated": true' do

        it 'completes the path' do

          @response.get(
            'https://half.example.com/rels#reservations',
            :clubId => 19, :day => 20131019)

          @client.last_request[:uri].should ==
            'https://half.example.com/api/reservations/19/20131019'
        end

        it 'completes the query string (1)' do

          @response.get(
            'https://half.example.com/rels#members',
            :clubId => 19)

          @client.last_request[:uri].should ==
            'https://half.example.com/api/members/19'
        end

        it 'completes the query string (2)' do

          @response.get(
            'https://half.example.com/rels#members',
            :clubId => 19, :count => 21)

          @client.last_request[:uri].should ==
            'https://half.example.com/api/members/19?count=21'
        end

        it 'completes the query string (3)' do

          @response.get(
            'https://half.example.com/rels#members',
            :clubId => 19, :query => 'toto', :count => 21)

          @client.last_request[:uri].should ==
            'https://half.example.com/api/members/19?query=toto&count=21'
        end

        it 'escapes the query string values' do

          @response.get(
            'https://half.example.com/rels#members',
            :clubId => 7, :query => 'to to')

          @client.last_request[:uri].should ==
            'https://half.example.com/api/members/7?query=to%20to'
        end
      end
    end

    describe '#post' do

      it 'posts reservations' do

        data = {}
        data['clubId'] = 19
        data['courtId'] = 7
        data['day'] = 20131212
        data['start'] = 1200
        data['end'] = 1300
        data['player1Id'] = 49
        data['player2Id'] = 50

        @response.post('#reserve', data)

        @client.last_request[:method].should ==
          :post
        @client.last_request[:uri].should ==
          'https://half.example.com/api/reservation'
        @client.last_request[:body].should ==
          data
      end

      it 'posts to links without fields' do

        @response.post('#bookmark-add', { :clubId => 21 }, {})

        @client.last_request[:method] ==
          :post
        @client.last_request[:uri] ==
          'https://half.example.com/api/bookmark/21'
        @client.last_request[:body] ==
          {}
      end

      it 'raises on missing "required": true fields' do

        lambda {
          @response.post('#reserve', {}, {})
        }.should raise_error(
          ArgumentError,
          "required field 'clubId' is missing"
        )
      end

      it 'completes fields with "value" or "default"' do

        data = {}
        data['clubId'] = 19
        data['courtId'] = 7
        data['day'] = 20131212
        data['start'] = 1200
        data['end'] = 1300

        dd = data.dup
        dd['_aft'] = 'e7C2vM3...'
        dd['player1Id'] = nil

        @response.post('#reserve', data)

        @client.last_request[:body].should == dd
      end
    end

    describe '#delete' do

      it 'removes bookmarks' do

        @response.delete('#bookmark-remove', :clubId => 19)

        @client.last_request[:method].should ==
          :delete
        @client.last_request[:uri].should ==
          'https://half.example.com/api/bookmark/19'
        @client.last_request[:body].should ==
          nil
      end
    end

    describe '#put' do

      it 'puts' do

        @response.put('#whatever-update', {})

        @client.last_request[:method].should ==
          :put
        @client.last_request[:uri].should ==
          'https://half.example.com/api/whatever-update'
        @client.last_request[:body].should ==
          {}
      end
    end

    context 'ad-hoc methods' do

      describe '#my_clubs' do

        it 'gets my clubs' do

          r = @response.my_clubs

          @client.last_request[:method].should ==
            :get
          @client.last_request[:uri].should ==
            'https://half.example.com/api/clubs'
          @client.last_request[:body].should ==
            nil
        end
      end

      describe '#reserve' do

        it 'posts a reservation' do

          data = {}
          data['clubId'] = 19
          data['courtId'] = 7
          data['day'] = 20131212
          data['start'] = 1200
          data['end'] = 1300
          data['player1Id'] = 49
          data['player2Id'] = 50

          @response.reserve(data)

          @client.last_request[:method].should ==
            :post
          @client.last_request[:uri].should ==
            'https://half.example.com/api/reservation'
          @client.last_request[:body].should ==
            data
        end
      end

      describe '#bookmark_remove' do

        it 'deletes a bookmark' do

          @response.bookmark_remove(:clubId => 19)

          @client.last_request[:method].should ==
            :delete
          @client.last_request[:uri].should ==
            'https://half.example.com/api/bookmark/19'
          @client.last_request[:body].should ==
            nil
        end
      end
    end
  end
end

