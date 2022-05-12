require "spec"
require "db"
require "../src/opentelemetry-instrumentation"

def datapath(*components)
  File.join("spec", "data", *components)
end

class FindJson
  @buffer : String = ""

  def self.from_io(io : IO::Memory)
    io.rewind

    json_finder = FindJson.new(io.gets_to_end)
    io.clear

    traces = [] of JSON::Any
    while json = json_finder.pull_json
      traces << JSON.parse(json)
    end

    client_traces = traces.select { |t| t["spans"][0]["kind"] == 3 }
    server_traces = traces.reject { |t| t["spans"][0]["kind"] == 3 }

    {client_traces, server_traces}
  end

  def initialize(@buffer)
  end

  def pull_json(buf)
    @buffer = @buffer + buf

    pull_json
  end

  def pull_json
    return nil if @buffer.empty?

    pos = 0
    start_pos = -1
    lefts = 0
    rights = 0
    while pos < @buffer.size
      if @buffer[pos] == '{'
        lefts = lefts + 1
        start_pos = pos if start_pos == -1
      end
      if @buffer[pos] == '}'
        rights = rights + 1
      end
      break if lefts > 0 && lefts == rights

      pos += 1
    end

    json = @buffer[start_pos..pos]
    @buffer = @buffer[pos + 1..-1]

    json
  end
end

# This helper macro can be used to selectively run only specific specs by turning on their
# focus in response to an environment variable.
macro it_may_focus_and_it(description, tags = "", &block)
{% if env("SPEC_ENABLE_FOCUS") %}
it {{ description.stringify }}, tags: {{ tags }}, focus: true do
  {{ block.body }}
end
{% else %}
it {{ description.stringify }}, tags: {{ tags }} do
  {{ block.body }}
end
{% end %}
end
