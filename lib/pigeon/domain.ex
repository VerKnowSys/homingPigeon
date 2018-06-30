require Logger
alias :inet_res, as: DNS
alias :timer, as: Timer
alias Porcelain.Result
alias Pigeon.CheckResult
alias Pigeon.CheckNothingToReport
alias Pigeon.Domain
alias Pigeon.Http


defmodule Pigeon.Domain do

  def default_ns, do: Application.get_env(:pigeon, :default_nameserver)

  def domain_validity_interval_s, do: Application.get_env(:pigeon, :domain_validity_interval_s)

  def resolve_and_get_record(domain), do: resolve_and_get_record(domain, Domain.default_ns())


  def resolve_and_get_record domain, dns_server, type \\ :a do
    case dns_server |> String.to_charlist |> :inet.parse_address do
      {:ok, erlang_addr} ->
        case DNS.nslookup String.to_charlist(domain), :in, type, [{erlang_addr, 53}] do
          {:ok, msg} ->
            {_, _, _, list, _, _} = msg
            # format:
            # {:dns_rr, 'peter.silkvms.com', :a, :in, 0, 299, {46, 101, 118, 71}, :undefined, [], false}
            case list do
              [{:dns_rr, _res_domain, :cname, :in, _, _, first_resolved_ip, _, _, _} | _tail] ->
                Logger.info "Cname found for domain: #{domain}. Reverse checking."
                resolve_and_get_record("#{first_resolved_ip}", dns_server)

              [{:dns_rr, _, :a, :in, _, _, first_resolved_ip, _, _, _} | _tail] ->
                str_ip = first_resolved_ip |> Tuple.to_list |> Enum.join(".")
                {:true, str_ip}

              [] ->
                {:false, "Empty resolve for domain: #{domain} under DNS server: #{dns_server}"}

            end

          {:error, _msg} ->
            {:false, "No response for #{domain} under DNS server: #{dns_server}"}
        end

      {:error, e} ->
        {:error, "Error resolving #{domain}: #{inspect e}"}
    end
  end


  @spec process_domain(check :: Check.t, domain :: String.t) :: CheckResult.t | CheckNothingToReport.t
  def process_domain check, domain do
    timeout_limit = case :os.type do
      {:unix, :darwin} -> if File.exists?("/usr/local/bin/timeout") do "/usr/local/bin/timeout 9" end
      _ -> "timeout 9" # Exists by default in both FreeBSD and Linux
    end
    case resolve_and_get_record domain, Domain.default_ns() do
      {:true, an_ip} ->
        case Porcelain.shell("echo | #{timeout_limit} openssl s_client -servername #{domain} -connect #{an_ip}:443 2>/dev/null | openssl x509 -noout -checkend #{domain_validity_interval_s()} -dates 2>&1") do

          %Result{out: _, status: 0} ->
            Logger.debug "Domain: #{domain} has correct and valid certificate (IP: #{an_ip})"
            %CheckNothingToReport{}

          %Result{out: output, status: 1} ->
            Logger.debug "Result error output: #{inspect output}"

            if String.contains?(output, "unable to load certificate") do
              Logger.warn "Domain: #{domain} - Unable to load SSL certificate! (#{an_ip}). Skipping!"
              %CheckNothingToReport{}
            end

            if String.contains?(output, "notBefore") and String.contains?(output, "notAfter") do
              %CheckResult{
                check: check,
                result: :failure,
                errors: ["Domain: #{domain} (#{an_ip}) is valid for less than 2 weeks! Command output: '#{output}'"]
              }
            else
              Logger.warn "Domain: #{domain} - nothing to report.. but got error status. This shouldn't happen."
              %CheckNothingToReport{}
            end

          %Result{out: out, status: _} ->
            Logger.debug "Timeout? Output: #{out}. Skipping!"
            %CheckNothingToReport{}
        end

      {:false, cause} ->
        %CheckResult{
          check: check,
          result: :error,
          errors: ["No DNS record for domain: #{domain}? Failure: #{cause}"]
        }

      {:error, cause} ->
        %CheckResult{
          check: check,
          result: :error,
          errors: ["Error resolving domain: #{domain}. Failure: #{cause}"]
        }
    end
  end


  @spec process_domains(check :: Check.t) :: [CheckResult.t | CheckNothingToReport.t]
  def process_domains check do
    Logger.info "Domain content check of domains: #{Enum.join(check.domains, ", ")}"
    for domain <- check.domains do
      Domain.process_domain check, domain
    end
  end


  @doc """
      process_domain_checks function will invoke all defined Domain checks
  """
  @spec process_domain_checks(check :: Check.t, check_country_origin :: String.t) :: :ok | :error
  def process_domain_checks(check, check_country_origin) do
    Logger.info "Domain checks started for client: #{check.client}."
    {time, _} = Timer.tc fn ->

      check
        |> Domain.process_domains()
        |> Enum.reject(fn result -> result == %CheckNothingToReport{} end)
        |> Http.alert(check_country_origin)

    end
    Logger.info "Domain checks took: #{time/1000}ms to process for client: #{check.client}"
    :ok
  end


  @spec check_all_domains :: none
  def check_all_domains do
    {total_time, _} = Timer.tc fn ->
      current_location = Http.get_current_location()
      Logger.debug "Checking all domains from location: #{current_location}"

      for check <- Pigeon.Checks.hosts do
        process_domain_checks check, current_location
      end
    end
    Logger.info "All domain checks took: #{total_time/1000}ms"
  end



end
