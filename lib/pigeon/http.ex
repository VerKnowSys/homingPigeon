defmodule Pigeon.Http do
  use HTTPotion.Base
  require Logger
  alias :timer, as: Timer
  alias Pigeon.Check
  alias Pigeon.Globals
  alias Pigeon.CheckResult
  alias Pigeon.CheckNothingToReport
  alias Pigeon.Domain
  alias Pigeon.Http
  alias Pigeon.Checks
  alias Porcelain.Result


  # Remote site to determine external IP from any physical location.
  def remote_ipv4_check_site, do: Application.get_env(:pigeon, :default_ext_ip_check_url)
  def remote_country_check_site, do: Application.get_env(:pigeon, :default_country_check_url)

  def process_url(url), do: url

  def binary_to_string(body), do: inspect(body, binaries: :as_strings)

  def process_response_body(body_content), do: body_content


  @spec valid_http_codes :: [Integer.t]
  def valid_http_codes, do: Application.get_env(:pigeon, :default_http_ok_codes)


  @spec get_ip_location(ipv4 :: String.t) :: String.t
  def get_ip_location(nil), do: get_ip_location("")
  def get_ip_location ipv4 do
    trimmed = String.trim(ipv4)
    case HTTPotion.get Http.remote_country_check_site() do
      %HTTPotion.Response{body: "429 Too Many Requests\n", status_code: 429, headers: _} ->
        Logger.warn "Too many requests to: #{Http.remote_country_check_site()} for current location. Ignoring.."
        "!?"

      %HTTPotion.Response{body: country, status_code: 200, headers: _} ->
        String.trim country

      %HTTPotion.Response{status_code: 404} ->
        Logger.error "Page not found: #{Http.remote_country_check_site()}!"
        "??"

      %HTTPotion.ErrorResponse{message: reason} ->
        Logger.error "Error response from #{Http.remote_country_check_site()}: #{inspect reason}"
        "??"
    end
  end


  @spec get_current_location :: String.t
  def get_current_location do
    case HTTPotion.get Http.remote_ipv4_check_site() do
      %HTTPotion.Response{body: "429 Too Many Requests\n", status_code: 429, headers: _} ->
        Logger.warn "Too many requests to: #{Http.remote_ipv4_check_site()} for current location. Ignoring.."
        "!?"

      %HTTPotion.Response{body: ipv4, status_code: 200, headers: _} ->
        get_ip_location ipv4

      %HTTPotion.Response{status_code: 404} ->
        Logger.error "Page not found: #{Http.remote_ipv4_check_site()}!"
        "??"

      %HTTPotion.ErrorResponse{message: reason} ->
        Logger.error "Error response from #{Http.remote_ipv4_check_site()}: #{inspect reason}"
        "??"
    end
  end


  @spec alert(results :: [CheckResult.t] | [CheckNothingToReport.t]) :: :ok | :skipped
  def alert([]), do: :skipped
  def alert results, current_location do
    for result <- results do
      # Fallback - take ip of first defined domain:
      current_destination =
        case Domain.resolve_and_get_record List.first result.check.domains do
          {:true, an_ip} -> Http.get_ip_location an_ip
          {_, _} -> "?"
        end

      if result.check.alert_webhook != "" and result.check.alert_channel != "" do
        Logger.warn "Alert client: #{result.check.client}. Check origin: #{current_location} ⇒ #{current_destination}. Result: #{inspect result}"
        notification_cmd = "bin/slack_notification.sh \"#{result.check.alert_webhook}\" \"#{result.check.alert_channel}\" \":warning: Alert\" \"\\n:blank: *Client:* *#{result.check.client}*.\\n:blank: *Errors:* #{Enum.join(result.errors, " ")}\\n:blank: *Origin:* :flag-#{current_location}: (src) ⇒ :flag-#{current_destination}: (dest)\\n:blank:\""
        case Porcelain.shell(notification_cmd) do
          %Result{out: _, status: 0} ->
            Logger.debug "Notification command invoked successfully: #{inspect notification_cmd}"

          %Result{out: output, status: 1} ->
            Logger.debug "Notification command failed with output: #{inspect output}"
        end
      end

      # send global notification additionally
      %Globals{alert_webhook: global_webhook, alert_channel: global_channel} = Checks.global()
      if global_webhook != "" and global_channel != "" do
        # remove "-centra" and "#" from std channel name to extract agency name:
        agency_name = Application.get_env(:pigeon, :agency_name)
        channel_postfix = Application.get_env(:pigeon, :agency_channel_postfix)
        channel_critical = Application.get_env(:pigeon, :agency_channel_critical)
        notified_agency =
          case result.check.alert_channel
            |> String.trim_leading("#")
            |> String.replace("#{channel_postfix}", "")
            |> String.replace(channel_critical, "#{agency_name}")
            |> String.trim() do
              "" -> agency_name
              val -> val
            end
        Logger.debug "Sending global notification of agency: #{notified_agency}, to channel: #{global_channel}"
        notification_cmd = "bin/slack_notification.sh \"#{global_webhook}\" \"#{global_channel}\" \":warning: Alert\" \"\\n:blank: *Client:* *#{result.check.client}* of agency: *#{notified_agency}*.\\n:blank: *Errors:* #{Enum.join(result.errors, " ")}\\n:blank: *Origin:* :flag-#{current_location}: (src) ⇒ :flag-#{current_destination}: (dest)\\n:blank:\""
        case Porcelain.shell(notification_cmd) do
          %Result{out: _, status: 0} ->
            Logger.debug "Notification command invoked successfully: #{inspect notification_cmd}"

          %Result{out: output, status: 1} ->
            Logger.debug "Notification command failed with output: #{inspect output}"
        end
      end

    end
    :ok
  end


  @spec process_pages(check :: Check.t, options :: Keyword.t) :: [CheckResult.t | CheckNothingToReport.t]
  def process_pages check, options do
    Logger.info "Page content checks for: #{inspect check.pages}, expected: #{inspect check.expected}"
    for page <- check.pages do
      case HTTPotion.get page, options do # stream_to: self,
        %HTTPotion.Response{status_code: 404} ->
          %CheckResult{
            check: check,
            result: :failure,
            errors: ["Http not-found on page: #{page}!"]
          }

        %HTTPotion.ErrorResponse{message: reason} ->
          if reason == "req_timedout" do
            %CheckResult{
              check: check,
              result: :error,
              errors: ["Http request timed out on page: #{page}! Timeout trigger: #{check.timeout}ms"]
            }
          else
            %CheckResult{
              check: check,
              result: :error,
              errors: ["Http error: #{reason} on page: #{page}!"]
            }
          end

        %HTTPotion.Response{body: body, status_code: code, headers: _headers} ->
          # Logger.debug "Response headers: #{inspect headers}, code: #{code}"
          expects = check.expected
            |> Enum.reject(fn expectation -> code in valid_http_codes() and Regex.match? ~r/#{expectation}/, body end)
            |> Enum.map(fn expectation -> "*#{expectation}*" end)
            |> Enum.join(", ")

          if expects == "" do
            %CheckNothingToReport{}
          else
            %CheckResult{
              check: check,
              body: body,
              result: :failure,
              errors: ["Failed to find expected phrases: #{expects} on page: #{page}. Http error code: *#{code}*!"]
            }
          end
      end
    end
  end


  @doc """
      process_http_checks function will invoke all defined Http checks
  """
  @spec process_http_checks(check :: Check.t, check_country_origin :: String.t) :: :ok | :error
  def process_http_checks(check, check_country_origin) do
    Logger.info "Http checks started for client: #{check.client}."
    {time, _} = Timer.tc fn ->

      check
        |> Http.process_pages([
          follow_redirects: true,
          timeout: check.timeout,
          cookies: check.cookies,
          headers: check.headers,
        ])
        |> Enum.reject(fn result -> result == %CheckNothingToReport{} end)
        |> Http.alert(check_country_origin)

    end
    Logger.info "Http checks took: #{time/1000}ms to process for client: #{check.client}"
    :ok
  end


  @spec check_all_hosts :: none
  def check_all_hosts do
    {total_time, _} = Timer.tc fn ->
      current_location = Http.get_current_location()
      Logger.debug "Checking all hosts from location: #{current_location}"

      for check <- Pigeon.Checks.hosts do
        process_http_checks check, current_location
      end
    end
    Logger.info "All page checks took: #{total_time/1000}ms"
  end


end
