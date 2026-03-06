defmodule FinBotElixir.Workers.MediaMessageWorkerTest do
  use FinBotElixir.DataCase, async: true
  use Oban.Testing, repo: FinBotElixir.Repo

  alias FinBotElixir.Workers.MediaMessageWorker

  describe "worker configuration" do
    test "uses the :messages queue" do
      changeset = MediaMessageWorker.new(%{"from" => "123", "type" => "image"})
      assert changeset.changes.queue == "messages"
    end

    test "has 3 max attempts" do
      changeset = MediaMessageWorker.new(%{"from" => "123", "type" => "image"})
      assert changeset.changes.max_attempts == 3
    end
  end

  describe "Processor.handle_webhook_message/1 enqueues a media job" do
    test "enqueues a MediaMessageWorker job for an image with correct args" do
      FinBotElixir.Processor.handle_webhook_message(%{
        from: "5511999990001",
        type: :image,
        media_id: "img123",
        url: "https://example.com/image.jpg",
        caption: "recibo"
      })

      assert_enqueued(
        worker: MediaMessageWorker,
        args: %{
          "from" => "5511999990001",
          "type" => "image",
          "media_id" => "img123",
          "url" => "https://example.com/image.jpg",
          "caption" => "recibo"
        }
      )
    end

    test "enqueues a MediaMessageWorker job for an audio message" do
      FinBotElixir.Processor.handle_webhook_message(%{
        from: "5511999990002",
        type: :audio,
        media_id: "aud456",
        url: nil,
        caption: nil
      })

      assert_enqueued(
        worker: MediaMessageWorker,
        args: %{"from" => "5511999990002", "type" => "audio", "media_id" => "aud456"}
      )
    end
  end
end
