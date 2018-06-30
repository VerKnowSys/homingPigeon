# Pigeon checker. Pingdom replacement for Agencies.


## Installation

`bin/build` to fetch and install all dependencies.
`bin/console` to launch console, then type in console:

```elixir
Pigeon.Http.check_all_hosts
```

## What checks are done by default?

* DNS "A record" resolve for each defined domain.
* SSL certificate validity for each defined domain.
* Expectations (content checks) for each defined page.
* Availability checks for each defined page.


## Project requirements

* Elixir 1.5+
* OTP 19+
* Libressl 2.7+ (`openssl` available in PATH)
* Curl 7+ (`curl` available in PATH) for [Slack](https://slack.com/) notifications


## Configuration files

1. `config/config.exs`

2. `config/globals.json`. Example:

```json
{
    "alert_channel":"#critical-channel",
    "alert_webhook":"https://hooks.slack.com/services/MyShinyWebURL"
}
```

3. `config/checks.json`. Example:

```json
[
  {
    "client": "myfavplace",
    "domains": ["myfavplace.com", "www.myfavplace.com"],
    "pages": ["https://www.myfavplace.com/"],
    "expected": ["title", "content", "footer"],
    "alert_channel": "#my-private-alert-channel",
    "alert_webhook": "https://hooks.slack.com/services/MyOwnShinyWebhookURL"
  },
  {
    "client": "youtfavplace",
    "domains": ["youtfavplace.se", "www.youtfavplace.se"],
    "pages": ["https://www.youtfavplace.se/"],
    "expected": ["title", "content", "footer"],
    "alert_channel": "#some-channel",
    "alert_webhook": "https://hooks.slack.com/services/MyOwnShinyWebhookURL"
  },
  // ...
]
```


## Additional stuff

Pigeon has ability to generate csv document file from current Agencies list:

```
bin/console
Pigeon.ExportServers.export_csv()
```

will generate `agencies-servers-list.csv` in project directory.


## License

MIT/BSD
