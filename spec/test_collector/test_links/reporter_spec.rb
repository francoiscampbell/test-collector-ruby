# frozen_string_literal: true

require 'buildkite/test_collector/test_links_plugin/reporter'

RSpec.describe Buildkite::TestCollector::TestLinksPlugin::Reporter do
  let(:example_group) { OpenStruct.new(metadata: { full_description: 'i love to eat pies' }) }
  let(:execution_result) { OpenStruct.new(status: :failed) }
  let(:failed_example) do
    OpenStruct.new(
      example_group: example_group,
      description: 'mince and cheese',
      execution_result: execution_result
    )
  end

  let(:suite_url) { 'https://example.com/suite/12345' }
  let(:response) { OpenStruct.new(body: { suite_url: suite_url }.to_json) }

  it 'does not render summary if all tests passed' do
    Buildkite::TestCollector.configure(
      hook: :rspec,
      token: 'fake',
      url: 'http://fake.buildkite.localhost/v1/uploads'
    )
    io = StringIO.new
    reporter = Buildkite::TestCollector::TestLinksPlugin::Reporter.new(io)
    passed_example = fake_example(status: :passed)
    notification = RSpec::Core::Notifications::ExampleNotification.for(passed_example)

    reporter.dump_summary(notification)

    expect(io.string.strip).to be_empty

    reset_io(io)
  end

  it 'does not render summary if there is no suite_url' do
    Buildkite::TestCollector.configure(
      hook: :rspec,
      token: 'fake',
      url: 'http://fake.buildkite.localhost/v1/uploads'
    )
    io = StringIO.new
    reporter = Buildkite::TestCollector::TestLinksPlugin::Reporter.new(io)
    allow(Buildkite::TestCollector.uploader).to receive(:response).and_return(OpenStruct.new(body: { suite_url: nil }.to_json))
    notification = RSpec::Core::Notifications::ExampleNotification.for(failed_example)

    reporter.example_failed(notification)
    reporter.dump_summary(notification)

    expect(io.string.strip).to be_empty

    reset_io(io)
  end

  it 'rdoes not render summary if there is no token' do
    Buildkite::TestCollector.configure(
      hook: :rspec,
      token: nil,
      url: 'http://fake.buildkite.localhost/v1/uploads'
    )
    io = StringIO.new
    reporter = Buildkite::TestCollector::TestLinksPlugin::Reporter.new(io)
    allow(Buildkite::TestCollector.uploader).to receive(:response).and_return(response)
    notification = RSpec::Core::Notifications::ExampleNotification.for(failed_example)

    reporter.example_failed(notification)
    reporter.dump_summary(notification)

    expect(io.string.strip).to be_empty

    reset_io(io)
  end

  it 'renders a summary when tests have failed' do
    Buildkite::TestCollector.configure(
      hook: :rspec,
      token: 'fake',
      url: 'http://fake.buildkite.localhost/v1/uploads'
    )
    io = StringIO.new
    reporter = Buildkite::TestCollector::TestLinksPlugin::Reporter.new(io)
    scope = failed_example.example_group.metadata[:full_description].to_s
    name = failed_example.description.to_s

    scope_name_digest = Digest::SHA256.hexdigest(scope + name)

    allow(Buildkite::TestCollector.uploader).to receive(:response).and_return(response)
    allow(reporter).to receive(:generate_scope_name_digest).and_return(scope_name_digest)
    notification = RSpec::Core::Notifications::ExampleNotification.for(failed_example)

    reporter.example_failed(notification)
    reporter.dump_summary(notification)

    # Displays the summary title
    expect(io.string.strip).to include('Test Analytics failures:')

    # Displays a test link
    expect(io.string.strip).to include("#{suite_url}/tests/#{scope_name_digest}")

    # Displays a test name
    expect(io.string.strip).to include("#{scope} #{name}")

    reset_io(io)
  end
end
