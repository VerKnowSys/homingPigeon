defmodule Pigeon.Monitor do
  @moduledoc """
  Pigeon is monitor module for domain validity and host availability checks
  """
  require Logger
  use GenServer
  alias Pigeon.Domain
  alias Pigeon.Http


  def start_link() do
    GenServer.start_link(__MODULE__, %{})
  end


  def init(state) do
    schedule_work()
    {:ok, state}
  end


  def http_checks_interval_ms, do: Application.get_env(:pigeon, :http_checks_interval_ms)

  def domain_checks_interval_ms, do: Application.get_env(:pigeon, :domain_checks_interval_ms)


  def check_all do
    Domain.check_all_domains()
    Http.check_all_hosts()
  end


  def handle_info(:domain_check, state) do
    Domain.check_all_domains()
    Process.send_after(self(), :domain_check, domain_checks_interval_ms())
    {:noreply, state}
  end


  def handle_info(:http_check, state) do
    Logger.info "Pigeon checks seeking for host troubles.."
    Http.check_all_hosts()
    Process.send_after(self(), :http_check, http_checks_interval_ms())
    {:noreply, state}
  end


  def handle_info({:error, reason}, state) do
    {:ok, hostname} = :inet.gethostname
    Logger.error "Handling Pigeon error: #{inspect reason} on host: #{hostname}"
    {:noreply, state}
  end


  def schedule_work do
    Logger.info "Scheduling work for :http_check (1min) and :domain_check (12h)"
    Process.send_after(self(), :http_check, http_checks_interval_ms())
    Process.send_after(self(), :domain_check, domain_checks_interval_ms())
  end


end
