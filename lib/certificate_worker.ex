defmodule CertificationStation.CertificateWorker do
  @spec fetch_cert(String.t(), integer()) :: any()
  def fetch_cert(hostname, port \\ 443) do
    timeout = 10000

    options = [
      cacerts: :public_key.cacerts_get(),
      verify: :verify_peer
    ]

    :ssl.start()

    with {:ok, ssl_socket} <- :ssl.connect(String.to_charlist(hostname), port, options, timeout),
         {:ok, binary_cert} <- :ssl.peercert(ssl_socket),
         {:Certificate,
          {_, _, _, _, _, {:Validity, {:utcTime, valid_from_s}, {:utcTime, valid_to_s}}, _, _, _,
           _, _}, _, _} <- :public_key.pkix_decode_cert(binary_cert, :plain) do
      {:ok, valid_from} = Timex.parse(to_string(valid_from_s), "{ASN1:UTCtime}")
      {:ok, valid_to} = Timex.parse(to_string(valid_to_s), "{ASN1:UTCtime}")

      {:ok, %{valid_from: valid_from, valid_to: valid_to}}
    end
  end
end
