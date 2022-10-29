defmodule CertificationStation do
  use Application

  defp validate_expiry(%{valid_to: valid_to}) do
    days = days_until_expiry(valid_to)

    check_severity(days)
  end

  defp days_until_expiry(valid_to) do
    now = Timex.now()

    Timex.diff(valid_to, now, :days) |> abs()
  end

  defp check_severity(days) when days < 5,
    do: {:error, "Certificate expires in less than 5 days"}

  defp check_severity(days) when days < 15,
    do: {:warn, "Certificate expires in less than 15 days"}

  defp check_severity(30), do: {:info, "Certificate expires in 30 days"}

  defp check_severity(_), do: {:ok, "Certificate is valid"}

  def fetch_domains(domain) when not is_list(domain) do
    fetch_domains([domain]) |> hd()
  end

  def fetch_domains(domains) do
    Task.async_stream(
      domains,
      fn domain ->
        CertificationStation.CertificateWorker.fetch_cert(domain)
      end,
      on_timeout: :kill_task,
      timeout: 10_000
    )
    |> Enum.zip(domains)
    |> Enum.map(fn
      {{:exit, :timeout}, domain} -> {domain, {:error, :timeout}}
      {{:ok, {:error, reason}}, domain} -> {domain, {:error, reason}}
      {{:ok, {:ok, validity}}, domain} -> {domain, validate_expiry(validity)}
    end)
  end

  def start(_type, _args) do
    [
      "google.com",
      "github.com",
      "elixir-lang.org",
      "facebook.com",
      "twitter.com",
      "reddit.com",
      "youtube.com",
      "amazon.com",
      "netflix.com",
      "wikipedia.org"
    ]
    |> fetch_domains()
    |> IO.inspect()

    Task.start(fn ->
      :timer.sleep(1000)
      IO.puts("done sleeping")
    end)
  end
end
