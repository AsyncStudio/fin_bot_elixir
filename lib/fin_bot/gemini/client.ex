defmodule FinBot.Gemini.Client do
  @api_key System.get_env("GEMINI_API_KEY")
  @model "gemini-1.5-flash"
  @url "https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent"

  def analyze_input(text) do
    body = %{
      contents: [%{parts: [%{text: build_prompt(text)}]}]
    }

    # Usando o Gemini com System Instructions implícitas no prompt
    case Req.post("#{@url}?key=#{@api_key}", json: body) do
      {:ok, %{status: 200, body: body}} ->
        parse_response(body)
      {:error, reason} ->
        {:error, reason}
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
    text_response = body["candidates"] |> List.first() |> get_in(["content", "parts"]) |> List.first() |> Map.get("text")

    case Jason.decode(text_response) do
      {:ok, data} -> {:ok, data}
      _ -> {:error, "Falha no parse do JSON da IA"}
    end
  end
end
