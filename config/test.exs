import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :jqs_web, Jqs.Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "/63BN2rU/Dc61H99cOwC5x/iNvdJ7y5M1w0wm9evt36ytKwBslsRaN/9Gyhf52Yb",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :jqs_queues,
  queues: []
