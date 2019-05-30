defmodule Pdex do
  @moduledoc """
  Documentation for Pdex.
  """

  @available [97..122, 48..57, 65..90]
  |> Enum.map(&Enum.to_list/1)
  |> Enum.join()
  |> String.codepoints()

  @type url :: String.t() | URI.t()
  @type html :: String.t()
  @type file :: String.t()

  @doc """
  Generate PDF from given HTML or link
  """
  @spec generate({:html, path :: file()} | {:url, url :: url()} | html()) :: {:ok, file :: file()} | {:error, reason :: String.t()}
  def generate(html_text_file_or_url, options \\ []) do
    with {:ok, html_text} <- string_collector(html_text_file_or_url),
         {:ok, pdf_path, executable} <- caller(html_text, options),
         {:ok, result} <- convert(executable),
         true <- inspect_result(executable, result) do
      {:ok, pdf_path}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, "Page size doesn't fit with the converter"}
    end
  end

  defp string_collector({:html, path}) when is_bitstring(path) do
    case File.exists?(path) do
      true -> {:ok, "file://" <> path}
      _ -> {:error, "File doesn't exists"}
    end
  end

  defp string_collector({:url, url}) when is_bitstring(url) do
    uri = URI.parse(url)

    case uri do
      %URI{scheme: nil} -> {:error, "Provided URI is has invalid scheme"}
      %URI{host: nil} -> {:error, "Provided URI not has invalid host"}
      _ -> {:ok, url}
    end
  end

  defp string_collector(html) when is_bitstring(html) do
    filename = System.tmp_dir <> "/pdex_" <> generate_filename() <> ".html"

    case File.write(filename, html) do
      :ok -> string_collector({:html, filename})
      reason -> reason
    end
  end

  defp string_collector(_), do: {:error, "Provided argument neither html content, html file or url"}
  defp generate_filename(length \\ 10), do: Enum.map_join(1..length, fn _ -> Enum.random(@available) end)

  defp caller(existed_file, opts) do
    opts
    |> Enum.into(Pdex.Config.default())
    |> Map.put(:file, existed_file)
    |> caller()
  end

  defp caller(%{converter: :wkhtmltopdf} = options) do
    executable = find_executable(:wkhtmltopdf, options)

    case File.exists?(executable) do
      true -> call(executable, options)
      _ -> {:error, "Wkhtmltopdf converter found"}
    end
  end

  defp caller(%{converter: :chrome, page_size: size} = options) when is_bitstring(size) do
    options
    |> Map.put(:page_size, dimensions(size))
    |> caller()
  end
  defp caller(%{converter: :chrome, page_size: _size} = options) do
    executable = find_executable(:chrome, options)

    case File.exists?(executable) do
      true -> call(executable, options)
      _ -> {:error, "Chrome converter found"}
    end
  end

  defp call(executable, %{converter: :wkhtmltopdf, servermode: servermode} = options) do
    arguments = build_arguments(options)
    result = case servermode do
      true -> {find_executable(:xvfb, options), ["-a", executable] ++ arguments.args}
      false -> {executable, arguments.args}
    end

    {:ok, arguments.output, result}
  end
  defp call(executable, %{converter: :chrome} = options) do
    arguments = build_arguments(options)

    {:ok, arguments.output, {executable, arguments.args}}
  end
  defp call(_executable, config), do: IO.inspect(config)

  defp build_arguments(%{converter: :wkhtmltopdf, file: file, page_size: page_size, shell_params: params}) do
    pdf_path = System.tmp_dir <> "/pdex_" <> generate_filename() <> ".pdf"
    arguments = List.flatten([
      params,
      "--page-size", page_size,
      file,
      pdf_path
    ])

    %{args: arguments, output: pdf_path}
  end

  defp build_arguments(%{converter: :chrome, chrome_sandbox: false, file: file, page_size: {width, height}, shell_params: params}) do
    pdf_path = System.tmp_dir <> "/pdex_" <> generate_filename() <> ".pdf"
    arguments = List.flatten([
      "--url", file,
      "--pdf", pdf_path,
      "--paper-width", width,
      "--paper-height", height,
      params
    ])

    %{args: arguments, output: pdf_path}
  end

  defp build_arguments(%{converter: :chrome, chrome_sandbox: true, file: file, page_size: {width, height}, shell_params: params}) do
    pdf_path = System.tmp_dir <> "/pdex_" <> generate_filename() <> ".pdf"
    arguments = List.flatten([
      "--url", file,
      "--pdf", pdf_path,
      "--paper-width", width,
      "--paper-height", height,
      params,
      "--chrome-options", "--no-sandbox"
    ])

    %{args: arguments, output: pdf_path}
  end

  defp dimensions("A0"), do: {"33.1", "46.8"}
  defp dimensions("A1"), do: {"23.4", "33.1"}
  defp dimensions("A2"), do: {"16.5", "23.4"}
  defp dimensions("A3"), do: {"11.7", "16.5"}
  defp dimensions("A4"), do: {"8.3", "11.7"}
  defp dimensions("A5"), do: {"5.8", "8.3"}
  defp dimensions("A6"), do: {"4.1", "5.8"}
  defp dimensions("A7"), do: {"2.9", "4.1"}
  defp dimensions("A8"), do: {"2.0", "2.9"}
  defp dimensions("A9"), do: {"1.5", "2.0"}
  defp dimensions("A10"), do: {"1.0", "1.5"}
  defp dimensions("F0"), do: {"33.1", "52"}
  defp dimensions("F1"), do: {"26", "33.1"}
  defp dimensions("F2"), do: {"16.5", "26"}
  defp dimensions("F3"), do: {"13", "16.5"}
  defp dimensions("F4"), do: {"8.3", "13"}
  defp dimensions("F5"), do: {"6.5", "8.3"}
  defp dimensions("F6"), do: {"4.1", "6.5"}
  defp dimensions("F7"), do: {"3.2", "4.1"}
  defp dimensions("F8"), do: {"2", "3.2"}
  defp dimensions("F9"), do: {"1.6", "2"}
  defp dimensions("F10"), do: {"1", "1.6"}
  defp dimensions("Letter"), do: {"8.5", "11"}
  defp dimensions("Legal"), do: {"8.5", "14"}
  defp dimensions("Tabloid"), do: {"11", "17"}
  defp dimensions("Ledger"), do: {"17", "11"}
  defp dimensions(_), do: dimensions("A4")

  defp find_executable(:wkhtmltopdf, %{systemcall: true, engine: %{wkhtmltopdf: path}}), do: System.find_executable("wkhtmltopdf") || path
  defp find_executable(:wkhtmltopdf, %{engine: %{wkhtmltopdf: path}}), do: path
  defp find_executable(:chrome, %{systemcall: true, engine: %{chrome: path}}), do: System.find_executable("chrome-headless-render-pdf") || path
  defp find_executable(:chrome, %{engine: %{chrome: path}}), do: path
  defp find_executable(:pdftk, %{systemcall: true, engine: path}), do: System.find_executable("pdftk") || path
  defp find_executable(:pdftk, %{engine: %{pdftk: path}}), do: path
  defp find_executable(:xvfb, %{engine: %{xvfb: path}}) do
    path = System.find_executable("xvfb-run") || path

    case File.exists?(path) do
      true -> path
      _ -> {:error, "Xvfb-run cannot be found"}
    end
  end

  defp convert({executable, arguments}), do: {:ok, System.cmd(executable, arguments, stderr_to_stdout: true)}
  defp inspect_result({executable, _}, {result, exit_code}) do
    case String.contains?(executable, "chrome") do
      false -> String.match?(result, ~r/Done/ms)
      true -> exit_code == 0
    end
  end

  @spec generate!({:html, path :: file()} | {:url, url :: URI.t() | location :: String.t()} | html :: String.t()) :: file :: file()
  def generate!(html_text_file_or_url, options \\ []) do
    case generate(html_text_file_or_url, options) do
      {:ok, filename} -> filename
      {:error, reason} -> raise ArgumentError, reason
    end
  end
end
