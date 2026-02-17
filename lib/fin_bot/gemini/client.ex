defmodule FinBot.Gemini.Client do
  @api_key System.get_env("GEMINI_API_KEY")
  @model "gemini-1.5-flash"

  alias FinBot.Financial.Transaction

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

    with {:ok, structured} <- parse_response(response) do
      Logger.debug("Resposta estruturada recebida da IA: #{inspect(structured)}")
      Transactions.create_transaction(%{
        amount: Decimal.new(structured["amount"]),
        description: structured["description"],
        category: structured["category"],
        type: structured["type"],
        raw_input: text
      })
    else
      {:error, reason} ->
        Logger.error("Erro ao analisar a resposta da IA: #{reason}")
        nil
    end
  end

  defp build_prompt(text) do
    """
    Você é o FinBot, um assistente financeiro inteligente.
    Analise a seguinte mensagem: "#{text}"
    Extraia os dados no formato JSON estrito:
    {
      "amount": (número positivo),
      "description": (string curta),
      "category": (uma das: Alimentação, Lazer, Transporte, Moradia, Outros),
      "type": ("expense" para gastos ou "income" para ganhos)
    }
    Retorne APENAS o JSON, sem markdown ou explicações.
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
