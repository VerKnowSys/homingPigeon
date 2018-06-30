defmodule Pigeon do
  use Application

  def start(_type, _args) do
    Pigeon.Supervisor.start_link
  end
end
