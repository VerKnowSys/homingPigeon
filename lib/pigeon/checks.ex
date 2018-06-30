defmodule Pigeon.Checks do
  require Logger
  alias Pigeon.Check
  alias Pigeon.Globals


  def global do
    default_globals_json_file = Application.get_env(:pigeon, :globals_file)
    Logger.info "Trying to load global file: '#{default_globals_json_file}'"
    body = case File.read(default_globals_json_file) do
      {:ok, data} -> data
      {:error, cause} ->
        Logger.error "Error reading input file: #{default_globals_json_file}, cause: #{cause}"
        ""
    end
    Poison.decode! body, as: %Globals{}
  end


  def hosts do
    # tODO: add web panel or api
    default_checks_json_file = Application.get_env(:pigeon, :checks_file)
    Logger.info "Trying to load checks-list file: '#{default_checks_json_file}'"
    body = case File.read(default_checks_json_file) do
      {:ok, data} -> data
      {:error, cause} ->
        Logger.error "Error reading input file: #{default_checks_json_file}, cause: #{cause}"
        ""
    end
    Poison.decode! body, as: [%Check{}]
  end


end
