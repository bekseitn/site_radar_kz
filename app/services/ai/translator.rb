module Ai
  # Translates a site's name/description into a target locale with the
  # local model — used when a visitor's UI locale doesn't match the
  # site's own detected language (Site#language).
  #
  # Best-effort — returns {} (not raises) if Ollama isn't reachable or
  # there's nothing worth translating.
  #
  # Single public entry point, per project convention:
  #   Ai::Translator.call(name: "...", description: "...", target_locale: :kk)
  class Translator
    LANGUAGE_NAMES = { kk: "Kazakh", ru: "Russian", en: "English" }.freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      Translate the given website name and description into the target
      language. Keep it natural and concise — this is catalog listing
      copy, not a literal word-for-word translation. Leave a field
      empty in your answer if it was given empty. Answer only with the
      requested JSON.
    PROMPT

    SCHEMA = {
      type: "object",
      properties: { name: { type: "string" }, description: { type: "string" } },
      required: %w[name description]
    }.freeze

    def self.call(...) = new(...).call

    def initialize(name:, description:, target_locale:)
      @name = name.to_s
      @description = description.to_s
      @target_language = LANGUAGE_NAMES.fetch(target_locale.to_sym, target_locale.to_s)
    end

    def call
      return {} if @name.blank? && @description.blank?

      result = Ai::Client.call(system: SYSTEM_PROMPT, prompt: prompt, schema: SCHEMA)
      return {} if result.blank?

      { "name" => result[:name].presence, "description" => result[:description].presence }.compact
    end

    private

    def prompt
      "Target language: #{@target_language}\nName: #{@name}\nDescription: #{@description}"
    end
  end
end
