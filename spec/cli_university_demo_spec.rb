# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'stream_weaver/cli'
require 'stream_weaver/university/demos'

# Covers `streamweaver university-demo` (lib/stream_weaver/cli.rb): the one
# command every Getting Started prompt uses to reach a canned demo inside
# the installed gem. It exists so no course prompt ever names a path and no
# worker session ever needs a checkout of this repo (round-5 UAT,
# 2026-09-03 -- one real session went looking for the source directory).
RSpec.describe StreamWeaver::CLI do
  DemoProvider = Struct.new(:courses)

  def capture_io
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    [$stdout.string, $stderr.string]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end

  def capture_exit
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    status = nil
    begin
      yield
    rescue SystemExit => error
      status = error.status
    end
    [$stdout.string, $stderr.string, status]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end

  describe '.university_demo' do
    around do |example|
      StreamWeaver::Extensions.reset!
      example.run
    ensure
      StreamWeaver::Extensions.reset!
    end

    it 'prints the absolute path of a demo inside the gem' do
      out, = capture_io { described_class.university_demo(['dashboard']) }
      path = out.strip
      expect(path).to start_with('/')
      expect(File.exist?(path)).to be(true)
      expect(path).to end_with('lib/stream_weaver/university/demos/dashboard.rb')
    end

    it 'prints exactly one line, so it can be used inside a shell substitution' do
      out, = capture_io { described_class.university_demo(['counter']) }
      expect(out.lines.length).to eq(1)
    end

    it 'accepts the underscored spelling of a hyphenated demo name' do
      hyphen, = capture_io { described_class.university_demo(['decision-form']) }
      underscore, = capture_io { described_class.university_demo(['decision_form']) }
      expect(underscore).to eq(hyphen)
    end

    it 'resolves the step-4 doc demo to the growing-doc script already in the gem' do
      out, = capture_io { described_class.university_demo(['doc']) }
      expect(out.strip).to end_with('lib/stream_weaver/university/scripts/growing_doc.rb')
    end

    it 'lists the demo names when called with no arguments' do
      out, = capture_io { described_class.university_demo([]) }
      StreamWeaver::University::Demos::NAMES.each { |name| expect(out).to include(name) }
    end

    it 'names the known demos on stderr and exits non-zero for an unknown one' do
      expect do
        capture_io { described_class.university_demo(['nope']) }
      end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end

    it 'reports every registered demo as present in the gem' do
      StreamWeaver::University::Demos::NAMES.each do |name|
        out, = capture_io { described_class.university_demo([name]) }
        expect(File.exist?(out.strip)).to be(true), "#{name} is registered but missing"
      end
    end

    it 'resolves a demo through the explicitly selected course definition' do
      demo = File.expand_path(__FILE__)
      resolver = ->(_name) { demo }
      StreamWeaver.register_extension(
        :fixture_provider,
        course_provider: DemoProvider.new([
          { id: 'fixture-diagram-intent', title: 'Diagram Intent', blurb: 'Choose by intent.',
            steps: [{ number: 1, title: 'Choose' }], demo_resolver: resolver }
        ])
      )
      out, = capture_io do
        described_class.run(['university-demo', 'dashboard', '--course', 'fixture-diagram-intent'])
      end

      expect(out.strip).to eq(demo)
    end

    it 'accepts the equals form of explicit course selection' do
      demo = File.expand_path(__FILE__)
      StreamWeaver.register_extension(
        :fixture_provider,
        course_provider: DemoProvider.new([
          { id: 'fixture-diagram-intent', title: 'Diagram Intent', blurb: 'Choose by intent.',
            steps: [{ number: 1, title: 'Choose' }], demo_resolver: ->(_name) { demo } }
        ])
      )
      out, = capture_io do
        described_class.run(['university-demo', 'dashboard', '--course=fixture-diagram-intent'])
      end

      expect(out.strip).to eq(demo)
    end

    it 'reports an unknown course ID and the available IDs' do
      _out, err, status = capture_exit do
        described_class.run(['university-demo', 'dashboard', '--course', 'missing'])
      end
      expect(status).to eq(1)
      expect(err).to match(/Unknown University course: ["']?missing/)
      expect(err).to include('getting-started')
    end

    it 'reports the selected provider and demo when its resolver fails' do
      StreamWeaver.register_extension(
        :fixture_provider,
        course_provider: DemoProvider.new([
          { id: 'fixture-diagram-intent', title: 'Diagram Intent', blurb: 'Choose by intent.',
            steps: [{ number: 1, title: 'Choose' }],
            demo_resolver: ->(_name) { raise LoadError, 'packaged data unavailable' } }
        ])
      )

      out, err, status = capture_exit do
        described_class.run(['university-demo', 'dashboard', '--course', 'fixture-diagram-intent'])
      end
      expect(status).to eq(1)
      expect(out).to eq('')
      expect(err).to include('fixture_provider', 'fixture-diagram-intent', 'diagram', 'packaged data unavailable')
    end
  end
end
