defmodule FinBotElixir.Gemini.Client do
  @api_key System.get_env("GEMINI_API_KEY")
  @model "gemini-1.5-flash"

  require Logger

  alias FinBotElixir.Financial
  alias FinBotElixir.Financial.Transaction
  alias Decimal, as: D

  def analyze_input(text) do
    prompt = build_prompt(text)

    {:ok, response} =
      Gemini.generate(prompt,
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
      )

    with {:ok, data} <- parse_response(response) do
      cond do
        data["is_transaction"] == false ->
          Logger.info("Entrada analisada como NÃO transação: #{text}")
          {:error, :not_a_transaction}

        true ->
          Logger.info("Entrada analisada como transação válida: #{text}\nPrompt usado: #{prompt}\nResposta da IA: #{inspect(data)}")
          {:ok, data}
      end
    end
  end

  defp build_prompt(text) do
    categories = Transaction.category_values() |> Enum.join("|")

    """
    Analise: "#{text}". Faça uma inferência para extrair os seguintes dados em JSON:
    {
      "amount": positive number,
      "description": string,
      "category": #{categories},
      "type": expense|income,
      "is_transaction": boolean
    }
    Se dúvida no type, use expense.
    Nunca deixe a categoria em branco. Se dúvida na categoria, use "other". Use as categorias exatamente como fornecidas.
    Análise o contexto da mensagem para determinar a categoria. Exemplo, se a mensagem for "gastei 50 com Uber", a categoria deve ser "transport". Se for "recebi 2000 de salário", a categoria deve ser "salary".
    Para `description`, dê um nome curto baseado no conteúdo da mensagem, como "Uber" ou "Salário". Se não conseguir extrair uma descrição, use o valor da categoria como descrição.
    Se a mensagem não contém uma transação válida (sem valor, descrição vaga, ou claramente não é uma transação), defina "is_transaction" como false.
    Retorne APENAS o JSON.
    """
  end

  defp parse_response(body) do
    # O Gemini retorna uma estrutura aninhada: candidates -> content -> parts -> text
    text_response =
      body.candidates
      |> List.first()
      |> get_in([Access.key!(:content), Access.key!(:parts)])
      |> List.first()

    case Jason.decode(text_response.text) do
      {:ok, data} -> {:ok, data}
      _ -> {:error, "Falha no parse do JSON da IA"}
    end
  end
end
