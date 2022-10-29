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
    do: {:critical, "Certificate expires in less than 5 days"}

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
      {{:ok, {:ok, validity}}, domain} -> {domain, {:ok, validate_expiry(validity)}}
    end)
  end

  def print_with_color({:ok, message}), do: IO.ANSI.green() <> message <> IO.ANSI.reset()
  def print_with_color({:info, message}), do: IO.ANSI.blue() <> message <> IO.ANSI.reset()
  def print_with_color({:warn, message}), do: IO.ANSI.yellow() <> message <> IO.ANSI.reset()
  def print_with_color({_, message}), do: IO.ANSI.red() <> message <> IO.ANSI.reset()

  def pretty_print_validity({domain, {:ok, result}}),
    do: IO.puts("#{domain} " <> print_with_color(result))

  def pretty_print_validity({domain, {:error, {:tls_alert, {reason, _}}}}),
    do: IO.puts("#{domain} " <> print_with_color({:error, Atom.to_string(reason)}))

  def start(_type, _args) do
    domains = [
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

    for d <- fetch_domains(domains), do: pretty_print_validity(d)

    {:ok, self()}
  end
end
