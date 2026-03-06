defmodule FinBotElixir.Workers.TextMessageWorkerTest do
  use FinBotElixir.DataCase, async: true
  use Oban.Testing, repo: FinBotElixir.Repo

  alias FinBotElixir.Workers.TextMessageWorker

  describe "worker configuration" do
    test "uses the :messages queue" do
      changeset = TextMessageWorker.new(%{"from" => "123", "text" => "hello"})
      assert changeset.changes.queue == "messages"
    end

    test "has 5 max attempts" do
      changeset = TextMessageWorker.new(%{"from" => "123", "text" => "hello"})
      assert changeset.changes.max_attempts == 5
    end
  end

  describe "Processor.handle_webhook_message/1 enqueues a text job" do
    test "enqueues a TextMessageWorker job with correct args" do
      FinBotElixir.Processor.handle_webhook_message(%{
        from: "5511999990000",
        text: "Gastei 50 no mercado",
        type: :text
      })

      assert_enqueued(
        worker: TextMessageWorker,
        args: %{"from" => "5511999990000", "text" => "Gastei 50 no mercado"}
      )
    end
  end
end
