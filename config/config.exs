import Config

# Configure JQS Queues
config :jqs_queues,
  queues: [
    {"sleep", Jqs.Web.Workers.Sleep, [concurrency: 5]}
  ]

config :jqs_web,
  generators: [context_app: :jqs_web]

# Configures the endpoint
config :jqs_web, Jqs.Web.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: Jqs.Web.ErrorJSON],
    layout: false
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
