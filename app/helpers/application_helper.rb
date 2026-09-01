module ApplicationHelper
  # Flag emoji by language code. Covers every language seen on the
  # sites so far, not just the app's own 3 UI locales; unknown codes get
  # a generic fallback.
  LANGUAGE_FLAGS = {
    "ru" => "🇷🇺", "kk" => "🇰🇿", "en" => "🇬🇧", "tr" => "🇹🇷", "az" => "🇦🇿",
    "uz" => "🇺🇿", "uk" => "🇺🇦", "de" => "🇩🇪", "fr" => "🇫🇷", "es" => "🇪🇸",
    "it" => "🇮🇹", "pt" => "🇵🇹", "zh" => "🇨🇳", "ja" => "🇯🇵", "ko" => "🇰🇷",
    "ar" => "🇸🇦", "he" => "🇮🇱", "hi" => "🇮🇳"
  }.freeze

  # hreflang's "no matching language, use this by default" marker — not a real language.
  NON_LANGUAGE_CODES = %w[x-default].freeze

  # Normalizes a bare or region-qualified code, and the "kz"/"kk" mix-up, to one lookup key.
  def normalize_language_code(code)
    normalized = code.to_s.split(/[-_]/).first&.downcase
    normalized == "kz" ? "kk" : normalized
  end

  def language_flag(code) = LANGUAGE_FLAGS[normalize_language_code(code)] || "🌐"

  # The language's name translated into the locale currently being viewed.
  def language_display_name(code)
    normalized = normalize_language_code(code)
    t("languages.#{normalized}", default: normalized || code.to_s)
  end

  # Flattens and dedupes language codes, dropping x-default and
  # collapsing region-qualified codes into their bare form.
  def real_language_codes(*code_or_arrays)
    code_or_arrays.flatten.compact.map(&:to_s)
      .reject { |code| NON_LANGUAGE_CODES.include?(code) }
      .uniq { |code| normalize_language_code(code) }
  end

  # The current page's URL switched to another locale, for the language switcher.
  def locale_switch_path(locale)
    path = request.path.sub(%r{\A/(?:#{I18n.available_locales.join('|')})(?=/|\z)}, "")
    path = "/" if path.blank?
    prefix = locale == I18n.default_locale ? "" : "/#{locale}"
    query = request.query_parameters.presence

    "#{prefix}#{path}#{"?#{query.to_query}" if query}"
  end
end
