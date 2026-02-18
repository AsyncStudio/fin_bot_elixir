defmodule FinBotElixir.Gemini.Client do
  @api_key System.get_env("GEMINI_API_KEY")
  @model "gemini-1.5-flash"

  require Logger

  alias FinBotElixir.Financial
  alias Decimal, as: D

  def analyze_input(text) do
    prompt = build_prompt(text)

    {:ok, response} = Gemini.generate(prompt, [
      response_json_schema: %{
        "type" => "object",
        "properties" => %{
          "amount" => %{"type" => "number"},
          "description" => %{"type" => "string"},
          "category" => %{"type" => "string"},
          "type" => %{"type" => "string"},
        }
      },
      response_mime_type: "application/json",
      temperature: 0.3
    ])

    parse_response(response)
  end

  defp build_prompt(text) do
    """
    Analise: "#{text}"
    Extraia em JSON:
    {
      "amount": positive number,
      "description": string,
      "category": Alimentação|Lazer|Transporte|Moradia|Outros,
      "type": expense|income
    }
    Se dúvida no type, use expense. Retorne APENAS o JSON.
    """
  end

  defp parse_response(body) do
    # O Gemini retorna uma estrutura aninhada: candidates -> content -> parts -> text
    text_response = body.candidates |> List.first() |> get_in([Access.key!(:content), Access.key!(:parts)]) |> List.first()
    IO.puts("\n\n#{inspect(text_response.text)}")

    case Jason.decode(text_response.text) do
      {:ok, data} -> {:ok, data}
      _ -> {:error, "Falha no parse do JSON da IA"}
    end
  end
end
