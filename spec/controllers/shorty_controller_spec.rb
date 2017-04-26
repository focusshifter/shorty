RSpec.describe ShortyController, type: :request do
  let(:headers) do
    { 'Content-Type' => 'application/json' }
  end

  describe 'POST /shorten' do
    context 'shortens the valid URL' do
      context 'with autogenerated shortcode' do
        let(:params) do
          { url: 'https://example.com' }
        end

        before do
          post '/shorten', params.to_json, headers
        end

        it { expect(last_response.status).to eq 201 }
        it { expect(last_response.header['Content-Type']).to eq 'application/json' }
        it { expect(json_response['shortcode']).to match(/^[0-9a-zA-Z_]{6}$/) }
      end

      context 'with predefined shortcode' do
        let(:params) do
          { url: 'https://example.com', shortcode: 'ExampleLink' }
        end

        before do
          post '/shorten', params.to_json, headers
        end

        it { expect(last_response.status).to eq 201 }
        it { expect(last_response.header['Content-Type']).to eq 'application/json' }
        it { expect(json_response['shortcode']).to eq 'ExampleLink' }
      end
    end

    context 'fails if URL is not set' do
      let(:params) do
        { shortcode: 'ExampleLink' }
      end

      before do
        post '/shorten', params.to_json, headers
      end

      it { expect(last_response.status).to eq 400 }
      it { expect(last_response.body).to eq 'url is not present.' }
    end

    context 'fails if URL is invalid' do
      let(:params) do
        { url: 'some random string' }
      end

      before do
        post '/shorten', params.to_json, headers
      end

      it { expect(last_response.status).to eq 400 }
      it { expect(last_response.body).to eq 'url is malformed.' }
    end

    context 'fails if shortcode has invalid format' do
      let(:params) do
        { url: 'https://example.com', shortcode: 'Ex1' }
      end

      before do
        post '/shorten', params.to_json, headers
      end

      it { expect(last_response.status).to eq 422 }
      it { expect(last_response.body).to eq 'The shortcode fails to meet the following regexp: ^[0-9a-zA-Z_]{4,}$.' }
    end

    context 'fails if shortcode is already taken' do
      let(:params) do
        { url: 'https://example.com', shortcode: 'ExampleLink' }
      end

      before do
        post '/shorten', params.to_json, headers
        post '/shorten', params.to_json, headers
      end

      it { expect(last_response.status).to eq 409 }
      it { expect(last_response.body).to eq 'The desired shortcode is already in use. Shortcodes are case-sensitive.' }
    end
  end

  describe 'GET /:shortcode' do
    context 'redirects if shortcode exists' do
      context 'with autogenerated shortcode' do
        let(:params) do
          { url: 'https://example.com' }
        end

        before do
          post '/shorten', params.to_json
          shortcode = json_response['shortcode']
          get "/#{shortcode}"
        end

        it { expect(last_response.status).to eq 302 }
        it { expect(last_response.header['Location']).to eq params[:url] }
      end

      context 'with predefined shortcode' do
        let(:params) do
          { url: 'https://example.com', shortcode: 'ExampleLink' }
        end

        before do
          post '/shorten', params.to_json
          get "/#{params[:shortcode]}"
        end

        it { expect(last_response.status).to eq 302 }
        it { expect(last_response.header['Location']).to eq params[:url] }
      end
    end

    context 'fails if shortcode not found' do
      before do
        get '/NoCode'
      end

      it { expect(last_response.status).to eq 404 }
      it { expect(last_response.body).to eq 'The shortcode cannot be found in the system.' }
    end
  end

  describe 'GET /:shortcode/stats' do
    let(:params) do
      { url: 'https://example.com', shortcode: 'ExampleLink' }
    end

    context 'returns stats for existing link' do
      before do
        post '/shorten', params.to_json
        get "/#{params[:shortcode]}/stats"
      end

      it { expect(last_response.status).to eq 200 }
      it { expect(last_response.header['Content-Type']).to eq 'application/json' }
      it { expect(json_response).to have_key('redirectCount') }
      it { expect(json_response).to have_key('startDate') }
      it { expect(json_response['redirectCount']).to eq 0 }
    end

    context 'increments counter with each use' do
      before do
        post '/shorten', params.to_json
        3.times { get "/#{params[:shortcode]}" }
        get "/#{params[:shortcode]}/stats"
      end

      it { expect(last_response.status).to eq 200 }
      it { expect(last_response.header['Content-Type']).to eq 'application/json' }
      it { expect(json_response).to have_key('lastSeenDate') }
      it { expect(json_response['redirectCount']).to eq 3 }
    end

    context 'fails if shortcode not found' do
      before do
        get '/NoCode/stats'
      end

      it { expect(last_response.status).to eq 404 }
      it { expect(last_response.body).to eq 'The shortcode cannot be found in the system.' }
    end
  end
end
