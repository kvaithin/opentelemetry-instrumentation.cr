require "../instrument"

# # OpenTelemetry::Instrumentation::CrystalLog
#
# ### Instruments
#
#   * Log
#
# ### Reference: [https://crystal-lang.org/api/1.4.0/Log.html](https://crystal-lang.org/api/1.4.0/Log.html)
#
# This instrument will record logs generated with `Log` as events in the current span. If there
# is no current span, the instrument is a NOP. In either case, configured logging then procedes
# as expected.
#
# ## Configuration
#
# - `OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_LOG`
#
#   If set, this will **disable** the `Log` instrumentation.
#
# ## Version Restrictions
#
# * Crystal >= 1.0.0
#
# ## Methods Affected
#
# - `Log#trace`
#
#   Attach the trace log event to the current span.
#
# - `Log#debug`
#
#   Attach the debug log event to the current span.
#
# - `Log#info`
#
#   Attach the info log event to the current span.
#
# - `Log#notice`
#
#   Attach the notice log event to the current span.
#
# - `Log#warn`
#
#   Attach the warn log event to the current span.
#
# - `Log#error`
#
#   Attach the error log event to the current span.
#
# - `Log#fatal`
#
#   Attach the fatal log event to the current span.
#
struct OpenTelemetry::InstrumentationDocumentation::CrystalLog
end

unless_enabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_LOG") do
  if_defined?(::Log) do
    require "../../../opentelemetry-instrumentation/log_backend"

    # :nodoc:
    module OpenTelemetry::Instrumentation
      class CrystalLog < OpenTelemetry::Instrumentation::Instrument
      end
    end

    if_version?(Crystal, :>=, "1.0.0") do
      class Log
        {% for method, severity in {
                                     trace:  Severity::Trace,
                                     debug:  Severity::Debug,
                                     info:   Severity::Info,
                                     notice: Severity::Notice,
                                     warn:   Severity::Warn,
                                     error:  Severity::Error,
                                     fatal:  Severity::Fatal,
                                   } %}
        def {{method.id}}(*, exception : Exception? = nil)
          severity = Severity.new({{severity}})
          if (span = OpenTelemetry::Trace.current_span) && level <= severity
            # There is an active span, so attach this log
            dsl = Emitter.new(@source, severity, exception)
            result = yield dsl
            entry =
              case result
              when Entry
                result
              else
                dsl.emit(result.to_s)
              end
            backend = @backend
            span.add_event("Log.#{entry.severity.label}#{" - #{entry.source}" unless entry.source.empty?}") do |event|
              OpenTelemetry::Instrumentation::LogBackend.apply_log_entry(entry, event)
            end

            return unless backend

            backend.dispatch entry
          else
            previous_def { |e| yield e }
          end
        end
        {% end %}
      end
    end
  end
end
