defmodule Pigeon.ExportServers do
  alias Pigeon.Checks


  def export_filename, do: Application.get_env(:pigeon, :default_servers_list_csv)


  @doc """
  Exports Checks to CSV list that can be imported as spreadsheet
  """
  def export_csv do
    # gather values
    values = Checks.hosts
      |> Enum.map(fn host ->
        client = host.client
        page = host.pages |> List.first()
        domain = host.domains |> List.first()
        "#{client},#{page},#{domain}\n"
      end)

    # now store list in csv file:
    {:ok, pid} = File.open export_filename(), [:write]
    IO.write pid, "Client,Page,Domain\n"
    IO.write pid, values
    File.close pid
  end


end
