defmodule Pdex.Config do
  def default do
    Application.get_all_env(:pdex)
    |> Enum.into(%{
      debug: true,
      converter: :wkhtmltopdf,
      servermode: true,
      page_size: "A4",
      layout: :potrait,
      systemcall: true,
      chrome_sandbox: false,
      shell_params: [],
      engine: %{
        wkhtmltopdf: "/usr/bin/wkhtmltopdf",
        chrome: "/usr/bin/chrome",
        pdftk: "/usr/bin/pdftk",
        xvfb: "/usr/bin/xvfb-run"
      }
    })
  end
end
