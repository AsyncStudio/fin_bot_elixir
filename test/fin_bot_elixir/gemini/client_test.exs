defmodule FinBotElixir.Gemini.ClientTest do
  use ExUnit.Case, async: true

  alias FinBotElixir.Gemini.Client

  # ---------------------------------------------------------------------------
  # parse_classification_data/2
  # ---------------------------------------------------------------------------

  describe "parse_classification_data/2 – message type detection" do
    test "recognises a transaction message" do
      data = %{"message_type" => "transaction", "transaction_data" => nil, "ai_response" => nil}
      context = Client.parse_classification_data(data, "spent $10")
      assert context.message_type == :transaction
    end

    test "recognises a data_query message" do
      data = %{"message_type" => "data_query", "transaction_data" => nil, "ai_response" => nil}
      context = Client.parse_classification_data(data, "how much did I spend?")
      assert context.message_type == :data_query
    end

    test "recognises a finance_tip message" do
      data = %{
        "message_type" => "finance_tip",
        "transaction_data" => nil,
        "ai_response" => "Save 20% of your income."
      }

      context = Client.parse_classification_data(data, "how do I save money?")
      assert context.message_type == :finance_tip
      assert context.ai_response == "Save 20% of your income."
    end

    test "falls back to :unrelated for unknown message_type" do
      data = %{
        "message_type" => "something_random",
        "transaction_data" => nil,
        "ai_response" => nil
      }

      context = Client.parse_classification_data(data, "hello")
      assert context.message_type == :unrelated
    end

    test "preserves the original text" do
      text = "Gastei R$50 no mercado"
      data = %{"message_type" => "transaction", "transaction_data" => nil, "ai_response" => nil}
      context = Client.parse_classification_data(data, text)
      assert context.original_text == text
    end
  end

  describe "parse_classification_data/2 – category extraction" do
    test "passes through the AI-resolved category label directly" do
      data = %{
        "message_type" => "transaction",
        "transaction_data" => %{
          "amount" => 30.0,
          "description" => "Supermercado",
          "category" => "food",
          "type" => "expense",
          "tags" => ["groceries"]
        },
        "ai_response" => "Registrado!"
      }

      context = Client.parse_classification_data(data, "Gastei 30 no mercado")
      assert context.transaction_data["category"] == "food"
    end

    test "accepts transport category (from Portuguese 'transporte')" do
      data = %{
        "message_type" => "transaction",
        "transaction_data" => %{
          "amount" => 15.0,
          "description" => "Uber",
          "category" => "transport",
          "type" => "expense",
          "tags" => ["uber", "car"]
        },
        "ai_response" => "Gasto de transporte anotado!"
      }

      context = Client.parse_classification_data(data, "Paguei 15 de Uber (transporte)")
      assert context.transaction_data["category"] == "transport"
    end

    test "accepts salary category (from Portuguese 'salário')" do
      data = %{
        "message_type" => "transaction",
        "transaction_data" => %{
          "amount" => 3000.0,
          "description" => "Salário mensal",
          "category" => "salary",
          "type" => "income",
          "tags" => ["work", "monthly"]
        },
        "ai_response" => "Receita registrada!"
      }

      context = Client.parse_classification_data(data, "Recebi meu salário de 3000")
      assert context.transaction_data["category"] == "salary"
      assert context.transaction_data["type"] == "income"
    end

    test "accepts health category (from Spanish 'salud')" do
      data = %{
        "message_type" => "transaction",
        "transaction_data" => %{
          "amount" => 80.0,
          "description" => "Farmacia",
          "category" => "health",
          "type" => "expense",
          "tags" => ["pharmacy", "health"]
        },
        "ai_response" => "Gasto en salud registrado."
      }

      context = Client.parse_classification_data(data, "Gasté 80 en la farmacia (salud)")
      assert context.transaction_data["category"] == "health"
    end

    test "falls through to 'other' when AI cannot determine the category" do
      data = %{
        "message_type" => "transaction",
        "transaction_data" => %{
          "amount" => 10.0,
          "description" => "Random thing",
          "category" => "other",
          "type" => "expense",
          "tags" => []
        },
        "ai_response" => "Recorded!"
      }

      context = Client.parse_classification_data(data, "spent 10 on something weird")
      assert context.transaction_data["category"] == "other"
    end
  end

  describe "parse_classification_data/2 – tag extraction" do
    test "includes tags from the AI response" do
      data = %{
        "message_type" => "transaction",
        "transaction_data" => %{
          "amount" => 45.0,
          "description" => "Gas station",
          "category" => "transport",
          "type" => "expense",
          "tags" => ["car", "fuel"]
        },
        "ai_response" => "Expense recorded!"
      }

      context = Client.parse_classification_data(data, "filled up the car, $45")
      assert context.transaction_data["tags"] == ["car", "fuel"]
    end

    test "handles missing tags gracefully (nil)" do
      data = %{
        "message_type" => "transaction",
        "transaction_data" => %{
          "amount" => 20.0,
          "description" => "Coffee",
          "category" => "food",
          "type" => "expense"
        },
        "ai_response" => "Done!"
      }

      context = Client.parse_classification_data(data, "coffee $20")
      assert is_nil(context.transaction_data["tags"]) or
               is_list(context.transaction_data["tags"])
    end

    test "handles empty tags list" do
      data = %{
        "message_type" => "transaction",
        "transaction_data" => %{
          "amount" => 10.0,
          "description" => "Something",
          "category" => "other",
          "type" => "expense",
          "tags" => []
        },
        "ai_response" => "Recorded."
      }

      context = Client.parse_classification_data(data, "10 on something")
      assert context.transaction_data["tags"] == []
    end
  end

  # ---------------------------------------------------------------------------
  # build_classification_prompt/2
  # ---------------------------------------------------------------------------

  describe "build_classification_prompt/2" do
    test "includes all valid category internal labels" do
      prompt = Client.build_classification_prompt("test message")

      for category <- ~w(food transport housing health education entertainment
                         shopping travel utilities subscriptions salary freelance
                         investments other) do
        assert String.contains?(prompt, category),
               "Expected prompt to include category '#{category}'"
      end
    end

    test "includes multilingual category examples for Portuguese" do
      prompt = Client.build_classification_prompt("test")
      assert String.contains?(prompt, "comida")
      assert String.contains?(prompt, "transporte")
      assert String.contains?(prompt, "saúde")
      assert String.contains?(prompt, "salário")
    end

    test "includes multilingual category examples for Spanish/French/German" do
      prompt = Client.build_classification_prompt("test")
      assert String.contains?(prompt, "essen")
      assert String.contains?(prompt, "nourriture")
      assert String.contains?(prompt, "voyage")
    end

    test "includes the user message in the prompt" do
      message = "Gastei 50 no supermercado"
      prompt = Client.build_classification_prompt(message)
      assert String.contains?(prompt, message)
    end

    test "includes instructions to extract tags" do
      prompt = Client.build_classification_prompt("test")
      assert String.contains?(prompt, "tags")
    end

    test "includes existing tags hint when provided" do
      prompt = Client.build_classification_prompt("bought fuel", ["car", "work"])
      assert String.contains?(prompt, "car")
      assert String.contains?(prompt, "work")
    end

    test "does not include a tags hint when existing_tags is empty" do
      prompt = Client.build_classification_prompt("test", [])
      refute String.contains?(prompt, "The user already has these tags")
    end
  end
end
