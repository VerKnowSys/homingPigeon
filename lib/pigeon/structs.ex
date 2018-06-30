defmodule Pigeon.Check do
  @type t :: Check
  @default_expectations ["body", "title"]
  @default_timeout 35_000 # 35s
  @derive [Poison.Encoder]

  defstruct [
    client: "",
    domains: [],
    pages: [],
    alert_webhook: "",
    alert_channel: "",

    cookies: [],
    headers: [],
    expected: @default_expectations,
    timeout: @default_timeout
  ]

end


defmodule Pigeon.CheckResult do
  @type t :: CheckResult
  @enforce_keys [:check, :result]

  defstruct [
    :check,
    :result,
    :body,
    :errors,
  ]

end


defmodule Pigeon.Globals do
  @type t :: Globals
  @derive [Poison.Encoder]

  defstruct [
    alert_webhook: "",
    alert_channel: "",
  ]

end


defmodule Pigeon.CheckNothingToReport do
  @type t :: CheckNothingToReport

  defstruct []

end
