require "json"

module Ai
  # Thin wrapper around a local Ollama server's /api/chat endpoint
  # (github.com/ollama/ollama — run "ollama serve", then e.g.
  # "ollama pull qwen2.5:7b-instruct"). Structured output only: every
  # call passes a JSON schema and gets back parsed JSON, never free text.
  #
  # Best-effort and silent on failure — any error returns nil rather than
  # raising. Nothing in this app should depend on local AI being
  # available; every caller treats nil as "couldn't tell, move on".
  #
  # Single public entry point, per project convention:
  #   Ai::Client.call(system: "...", prompt: "...", schema: { ... })
  class Client
    HOST = ENV.fetch("OLLAMA_HOST", "http://127.0.0.1:11434")
    MODEL = ENV.fetch("OLLAMA_MODEL", "qwen2.5:7b-instruct")
    TIMEOUT = 60
    OPEN_TIMEOUT = 5

    def self.call(...) = new(...).call
    def self.available? = new(system: nil, prompt: nil).available?

    def initialize(system:, prompt:, schema: nil, model: MODEL)
      @system = system
      @prompt = prompt
      @schema = schema
      @model = model
    end

    def call
      response = connection.post("/api/chat") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = {
          model: @model,
          messages: [
            { role: "system", content: @system },
            { role: "user", content: @prompt }
          ],
          format: @schema,
          stream: false
        }.compact.to_json
      end

      return nil unless response.success?

      content = JSON.parse(response.body).dig("message", "content")
      return nil if content.blank?

      JSON.parse(content, symbolize_names: true)
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.warn("[Ai::Client] #{e.class}: #{e.message}")
      nil
    end

    # Cheap reachability check — TechnologyDetector uses this once per
    # run instead of discovering Ollama is down on every site's first call.
    def available?
      connection.get("/api/tags").success?
    rescue Faraday::Error
      false
    end

    private

    def connection
      @connection ||= Faraday.new(HOST) do |f|
        f.options.timeout = TIMEOUT
        f.options.open_timeout = OPEN_TIMEOUT
        f.adapter Faraday.default_adapter
      end
    end
  end
end
