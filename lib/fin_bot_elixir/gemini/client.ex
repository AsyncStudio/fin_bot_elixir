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
          "is_transaction" => %{"type" => "boolean"}
        }
      },
      response_mime_type: "application/json",
      temperature: 0.3
    ])

    with {:ok, data} <- parse_response(response) do
      cond do
        data["is_transaction"] == false ->
          Logger.info("Entrada analisada como NÃO transação: #{text}")
          {:error, :not_a_transaction}

        true ->
          Logger.info("Entrada analisada como transação válida: #{text}")
          {:ok, data}
      end
    end
  end

  defp build_prompt(text) do
    """
    Analise: "#{text}"
    Extraia em JSON:
    {
      "amount": positive number,
      "description": string,
      "category": Alimentação|Lazer|Transporte|Moradia|Outros,
      "type": expense|income,
      "is_transaction": boolean
    }
    Se dúvida no type, use expense.
    Se a mensagem não contém uma transação válida (sem valor, descrição vaga, ou claramente não é uma transação), defina "is_transaction" como false.
    Retorne APENAS o JSON.
    """
  end

  defp parse_response(body) do
    # O Gemini retorna uma estrutura aninhada: candidates -> content -> parts -> text
    text_response = body.candidates |> List.first() |> get_in([Access.key!(:content), Access.key!(:parts)]) |> List.first()

    case Jason.decode(text_response.text) do
      {:ok, data} -> {:ok, data}
      _ -> {:error, "Falha no parse do JSON da IA"}
    end
  end
end
