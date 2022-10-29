defmodule Mix.Tasks.Example do
  use Mix.Task

  def run(_) do
    CertificationStation.fetch_domains("google.com")
    |> IO.inspect()
  end
end
