# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Logger
config :logger, :console, format: "$time $message\n"

# Porcelain
config :porcelain, driver: Porcelain.Driver.Basic


# Pigeon defaults:
config :pigeon, agency_name: "young-skilled"
config :pigeon, agency_channel_postfix: "-centra"
config :pigeon, agency_channel_critical: "critical-issues"


# Globals and Checks:
config :pigeon, checks_file: "config/checks.json"
config :pigeon, globals_file: "config/globals.json"
config :pigeon, default_http_ok_codes: [200, 201, 202, 203, 204, 205, 206, 207, 208, 226]

# Checks intervals:
config :pigeon, http_checks_interval_ms: 1000 * 60 * 2 # ms => 2m
config :pigeon, domain_checks_interval_ms: 1000 * 60 * 60 * 12 # ms => 12h
config :pigeon, domain_validity_interval_s: 14 * 60 * 60 * 24 # s => 14 days

# Domain resolve:
config :pigeon, default_nameserver: "9.9.9.9"

# External IP check URL:
config :pigeon, default_ext_ip_check_url: "https://ifconfig.co/ip"

# Export to CSV:
config :pigeon, default_servers_list_csv: "agencies-servers-list.csv"

# Geolix mmdb:
config :geolix, databases: [
  %{
    id: :mmdb2,
    adapter: Geolix.Adapter.MMDB2,
    source: "data-mmdb/GeoLite2-Country.mmdb"
  }
]
