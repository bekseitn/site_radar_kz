require "json"
require "faraday/follow_redirects"

# Walks every pending Site, fetches its homepage, and runs it through
# Wappalyzer::Analyzer to detect its tech stack. Also fills in business
# info from JSON-LD (see JsonLdBusinessInfo) and probes common paths to
# find a vacancy page that mentions an already-detected technology.
#
# With ai_enabled: true (off by default — see Ai::Client), a local
# Ollama model fills in gaps the deterministic extraction couldn't
# (description, city, categories, parked-domain flag) and helps find
# the vacancy page and other language versions from the homepage's own
# links (Ai::LinkAnalyzer).
#
# Single public entry point, per project convention:
#   TechnologyDetector.call
class TechnologyDetector
  USER_AGENT = "SiteRadarBot/1.0 (+https://github.com/bekseitn/site_radar_kz)".freeze

  OPEN_TIMEOUT = 5
  TIMEOUT = 5
  MAX_ATTEMPTS = 3
  RETRY_BACKOFF = 1 # seconds, multiplied by the attempt number
  REDIRECT_LIMIT = 5
  NAME_MAX_LENGTH = 255
  DESCRIPTION_MAX_LENGTH = 500
  LANGUAGE_MAX_LENGTH = 35 # generous for a BCP 47 tag like "en-US" or "zh-Hans-CN"
  LANGUAGE_DETECTION_SAMPLE_LENGTH = 3000 # plenty for a reliable trigram match, caps the work per page
  LANGUAGE_DETECTION_MIN_CHARS = 30 # below this, statistical detection is unreliable — leave language blank instead
  CITY_MAX_LENGTH = 100
  PHONE_MAX_LENGTH = 40
  EMAIL_MAX_LENGTH = 254 # RFC 5321's own limit on a full email address
  CATEGORY_MAX_LENGTH = 60
  OPENING_HOURS_MAX_LENGTH = 255
  FASTIMAGE_TIMEOUT = 3
  MIN_IMAGE_DIMENSION = 8 # rejects 1x1-ish tracking-pixel "images"

  # Strips Russian/Kazakh city prefix/suffix ("г. Астана", "Астана
  # қаласы") so the same city doesn't fragment into duplicates.
  CITY_PREFIX_PATTERN = /\A(?:г\.?|город|қ\.?)\s+/i
  CITY_SUFFIX_PATTERN = /\s+(?:қаласы|қ\.?)\z/i

  # Too generic to prefer over a more specific type on the same page —
  # used as a fallback only if that's all a page declared.
  LOW_PRIORITY_JSON_LD_TYPES = %w[Organization].freeze
  FAVICON_SELECTORS = [
    'link[rel="icon"]',
    'link[rel="shortcut icon"]',
    'link[rel="apple-touch-icon"]'
  ].freeze

  # English paths plus transliterated Russian/Kazakh ones, since most
  # sites in this dataset are Kazakhstani.
  VACANCY_PATHS = %w[
    /careers /career /jobs /job /vacancies /vacancy
    /about/careers /about-us/careers /company/careers /company/jobs
    /join-us /work-with-us /hiring
    /vakansii /vakansiya /karera /rabota
  ].freeze

  # Last-resort check for other language versions when hreflang and the
  # AI link check both find nothing.
  LOCALE_PATHS = %w[/ru /en /kk /kz].freeze
  LOCALE_SUBDOMAINS = %w[ru en kk kz].freeze

  # Matched against <a href> links and JSON-LD "sameAs" URLs. Excludes
  # share/intent links so a "share this" widget isn't mistaken for the
  # business's own profile.
  SOCIAL_PATTERNS = {
    "facebook" => %r{facebook\.com/(?!sharer|share\.php)}i,
    "instagram" => %r{instagram\.com/}i,
    "whatsapp" => %r{(?:wa\.me/|api\.whatsapp\.com/send)}i,
    "telegram" => %r{t\.me/}i,
    "vk" => %r{vk\.com/(?!share)}i,
    "linkedin" => %r{linkedin\.com/(?!sharing|shareArticle)}i,
    "youtube" => %r{(?:youtube\.com/(?:channel|c|user|@)|youtu\.be/)}i,
    "twitter" => %r{(?:twitter\.com|x\.com)/(?!intent|share)}i
  }.freeze

  def self.call(...) = new(...).call

  # on_progress is called once per processed site, as
  # on_progress.call(done_count, total_count).
  #
  # limit caps how many sites this run processes (nil means all). Every
  # processed site's status moves off "pending", so the next run picks
  # up wherever this one left off.
  #
  # scope defaults to Site.pending, but can be swapped for a re-check of
  # already-checked sites (e.g. scrapers:enrich_with_ai).
  #
  # ai_enabled turns on the local-Ollama fallbacks described above.
  # Stops the run if Ollama isn't reachable — see OllamaUnavailableError.
  def initialize(delay: 1.0, limit: nil, scope: Site.pending, ai_enabled: false, on_progress: ->(*) { })
    @delay = delay
    @limit = limit
    @base_scope = scope
    @ai_enabled = ai_enabled
    @on_progress = on_progress
  end

  # Raised when ai_enabled is on but Ollama isn't reachable. Stops the
  # run instead of continuing without AI; unprocessed sites stay
  # "pending" so a rerun picks up where this left off.
  class OllamaUnavailableError < StandardError; end

  def call
    stats = Hash.new(0)

    if @ai_enabled && !Ai::Client.available?
      raise OllamaUnavailableError, "ai_enabled was set but Ollama isn't reachable at #{Ai::Client::HOST}"
    end

    scope = @limit ? @base_scope.limit(@limit) : @base_scope
    total = @limit ? [ @base_scope.count, @limit ].min : scope.count

    scope.find_each.with_index do |site, index|
      sleep(@delay) if index.positive? && @delay.positive?

      if @ai_enabled && !Ai::Client.available?
        raise OllamaUnavailableError, "Ollama stopped responding at #{Ai::Client::HOST} after #{stats[:checked]} sites this run — #{site.url} onward are still pending"
      end

      begin
        process(site, stats)
      rescue StandardError => e
        stats[:errors] += 1
        Rails.logger.error("[TechnologyDetector] #{site.url} raised #{e.class}: #{e.message}")
      end

      @on_progress.call(index + 1, total)
    end

    log_summary(stats)
    stats
  end

  private

  def process(site, stats)
    response = fetch(site.url)

    if response.nil? || response.status >= 500
      # ai_checked here too — an AI-enabled run did attempt this site,
      # it just found nothing to fetch, so there's no point retrying it
      # for AI enrichment alone (scrapers:enrich_with_ai).
      site.update!(status: :unreachable, last_checked_at: Time.current, ai_checked: @ai_enabled)
      stats[:unreachable] += 1
      return
    end

    doc = Nokogiri::HTML(response.body.to_s.scrub)
    # One AI call (off unless ai_enabled), shared by update_site_metadata
    # and check_vacancy_page below.
    link_analysis = @ai_enabled ? analyze_links(doc) : {}

    detected = Wappalyzer::Analyzer.call(response)
    technologies = save_technologies(site, detected)
    update_site_metadata(site, doc, response, link_analysis)
    check_vacancy_page(site, technologies, link_analysis)

    site.update!(status: :checked, last_checked_at: Time.current, ai_checked: @ai_enabled)
    stats[:checked] += 1
    stats[:with_technology] += 1 if detected.any?
    stats[:with_vacancy] += 1 if site.vacancy_url.present?
  end

  def analyze_links(doc)
    links = doc.css("a[href]").filter_map do |node|
      href = node["href"].to_s.strip
      next if href.blank? || href.start_with?("#", "javascript:", "mailto:", "tel:")

      { text: node.text.to_s.strip.first(80), href: href }
    end.uniq { |link| link[:href] }

    Ai::LinkAnalyzer.call(links: links)
  end

  # Tries the AI-found vacancy link first (off unless ai_enabled), then
  # falls back to blindly probing VACANCY_PATHS. Either way, a candidate
  # page only counts if it mentions a technology already detected on the
  # homepage, which also flags found_in_vacancy on the matching
  # site_technologies.
  def check_vacancy_page(site, technologies, link_analysis)
    return if technologies.empty?

    return if link_analysis[:vacancy_href].present? && try_ai_vacancy_link(site, technologies, link_analysis[:vacancy_href])

    VACANCY_PATHS.each do |path|
      response = fetch(site.url, path: path, retries: false)
      next unless response&.status == 200
      next if redirected_to_root?(response)

      mentioned = mentioned_technologies(response, technologies)
      next if mentioned.empty?

      site.vacancy_url = response.env.url.to_s
      mark_found_in_vacancy(site, mentioned)
      break
    end
  end

  def try_ai_vacancy_link(site, technologies, href)
    url = resolve_url(site.url, href)
    return false if url.blank?

    response = fetch(url, retries: false)
    return false unless response&.status == 200
    return false if redirected_to_root?(response)

    mentioned = mentioned_technologies(response, technologies)
    return false if mentioned.empty?

    site.vacancy_url = response.env.url.to_s
    mark_found_in_vacancy(site, mentioned)
    true
  end

  # A probed vacancy-page candidate that redirects back to the homepage
  # would otherwise falsely "confirm" itself, since the homepage likely
  # mentions its own already-detected technologies somewhere.
  def redirected_to_root?(response)
    response.env.url.path.to_s.in?([ "", "/" ])
  end

  def mentioned_technologies(response, technologies)
    body = response.body.to_s.scrub
    technologies.select { |technology| body.match?(/\b#{Regexp.escape(technology.name)}\b/i) }
  end

  def mark_found_in_vacancy(site, mentioned)
    SiteTechnology.where(site: site, technology: mentioned).update_all(found_in_vacancy: true)
  end

  # Importers only ever have a bare hostname, so fill in everything else
  # findable on the homepage: name, description, preview image, favicon,
  # language, and other language versions of the site.
  def update_site_metadata(site, doc, response, link_analysis)
    name = meta_content(doc, "og:title", property: true).presence || extract_title(doc)
    site.name = clean_text(name, NAME_MAX_LENGTH) if name.present?

    description = meta_content(doc, "og:description", property: true).presence ||
      meta_content(doc, "description")
    site.description = clean_text(description, DESCRIPTION_MAX_LENGTH) if description.present?

    image = meta_content(doc, "og:image", property: true)
    image_url = resolve_image_url(site.url, image)
    site.image_url = image_url if image_url.present?

    favicon = extract_favicon(doc)
    favicon_url = resolve_image_url(site.url, favicon)
    site.favicon_url = favicon_url if favicon_url.present?

    language = doc.at_css("html")&.attr("lang").presence || detect_language(doc)
    available_languages = extract_available_languages(doc) || link_analysis[:language_codes] ||
      probe_locale_paths(site) || probe_locale_subdomains(site)
    assign_languages(site, language, available_languages)

    noindex = noindex?(doc, response)
    site.noindex = noindex unless noindex.nil?

    json_ld = JsonLdBusinessInfo.extract(doc)

    assign_cities(site, json_ld[:cities]) if json_ld[:cities].present?

    phone = normalize_phone(extract_phone(doc) || json_ld[:phone])
    site.phone = clean_text(phone, PHONE_MAX_LENGTH) if phone.present?

    email = extract_email(doc) || json_ld[:email]
    site.email = clean_text(email, EMAIL_MAX_LENGTH) if email.present?

    social_links = extract_social_links(doc, json_ld[:same_as])
    site.social_links = social_links if social_links.present?

    # Skipped when AI will determine categories anyway (see
    # apply_ai_enrichment) — avoids writing the join rows twice.
    unless @ai_enabled
      categories = clean_categories(pick_categories(json_ld[:types]))
      site.categories = categories_for(categories) if categories.present?
    end

    logo = json_ld[:logo]
    logo_url = resolve_image_url(site.url, logo)
    site.logo_url = logo_url if logo_url.present?

    if json_ld[:latitude].present? && json_ld[:longitude].present?
      site.latitude = json_ld[:latitude]
      site.longitude = json_ld[:longitude]
    end

    site.rating = json_ld[:rating] if json_ld[:rating].present?
    site.review_count = json_ld[:review_count] if json_ld[:review_count].present?

    opening_hours = json_ld[:opening_hours]
    site.opening_hours = clean_text(opening_hours, OPENING_HOURS_MAX_LENGTH) if opening_hours.present?

    apply_ai_enrichment(site, doc) if @ai_enabled
  end

  # Runs after everything else — fills in description/cities only if
  # still missing, but categories and likely_parked always.
  def apply_ai_enrichment(site, doc)
    enrichment = Ai::SiteAnalyzer.call(
      text: visible_text(doc),
      need_description: site.description.blank?,
      need_categories: true,
      need_cities: site.cities.empty?
    )
    return if enrichment.blank?

    if site.description.blank? && enrichment[:description].present?
      site.description = clean_text(enrichment[:description], DESCRIPTION_MAX_LENGTH)
    end

    if (categories = clean_categories(enrichment[:categories])).present?
      site.categories = categories_for(categories)
    end

    if site.cities.empty? && enrichment[:cities].present?
      assign_cities(site, enrichment[:cities])
    end

    site.likely_parked = enrichment[:likely_parked] if enrichment.key?(:likely_parked)
  end

  # Keeps every specific type found (a site can be more than one thing);
  # falls back to generic types (LOW_PRIORITY_JSON_LD_TYPES) only if
  # that's all there was.
  def pick_categories(types)
    return [] if types.blank?

    specific = types.reject { |type| LOW_PRIORITY_JSON_LD_TYPES.include?(type) }
    # Titleize PascalCase schema.org types ("LocalBusiness" -> "Local
    # Business") so they read the same as AI-derived categories.
    (specific.presence || types).uniq.map(&:titleize)
  end

  def clean_categories(categories)
    Array(categories).filter_map { |category| clean_text(category, CATEGORY_MAX_LENGTH) }.uniq.presence
  end

  def categories_for(names)
    names.map { |name| Category.find_or_create_by!(name: name) }
  end

  # site.site_languages= (not site.languages=, which can't carry
  # is_primary). Full replace each run, same as categories/technologies.
  def assign_languages(site, primary_code, extra_codes)
    primary_name = clean_text(primary_code, LANGUAGE_MAX_LENGTH)
    extra_names = Array(extra_codes).filter_map { |code| clean_text(code, LANGUAGE_MAX_LENGTH) }.uniq
    all_names = ([ primary_name ] + extra_names).compact.uniq
    return if all_names.empty?

    site.site_languages = all_names.map do |name|
      SiteLanguage.new(language: Language.find_or_create_by!(name: name), is_primary: name == primary_name)
    end
  end

  # site.cities= — a full replace, same reasoning as assign_languages.
  def assign_cities(site, names)
    clean_names = Array(names).filter_map { |name| clean_text(normalize_city(name), CITY_MAX_LENGTH) }.uniq
    return if clean_names.empty?

    site.cities = clean_names.map { |name| City.find_or_create_by!(name: name) }
  end

  def extract_phone(doc)
    href = doc.at_css('a[href^="tel:"]')&.attr("href")
    href&.delete_prefix("tel:")&.strip&.presence
  end

  # Normalizes to E.164 when it parses as a valid Kazakhstani number;
  # falls back to the raw text otherwise.
  def normalize_phone(raw)
    return nil if raw.blank?

    phone = Phonelib.parse(raw, "KZ")
    phone.valid? ? phone.e164 : raw
  end

  def extract_email(doc)
    href = doc.at_css('a[href^="mailto:"]')&.attr("href")
    href&.delete_prefix("mailto:")&.split("?")&.first&.strip&.presence
  end

  # Checks both meta robots and the X-Robots-Tag header. Returns nil
  # (leave stored value alone) when neither is present, rather than
  # false — absence isn't evidence the page allows indexing.
  def noindex?(doc, response)
    meta = meta_content(doc, "robots")
    header = response.headers["x-robots-tag"]
    return nil if meta.blank? && header.blank?

    [ meta, header ].any? { |value| value.to_s.match?(/\bnoindex\b/i) }
  end

  def extract_social_links(doc, same_as_urls)
    candidates = doc.css("a[href]").map { |node| node["href"].to_s } + Array(same_as_urls)

    SOCIAL_PATTERNS.filter_map do |platform, pattern|
      match = candidates.find { |href| href.match?(pattern) }
      [ platform, match ] if match
    end.to_h.presence
  end

  def extract_title(doc)
    doc.at_css("title")&.text
  end

  # Falls back to statistical (trigram) detection over the visible text
  # when <html lang> is missing.
  def detect_language(doc)
    text = visible_text(doc).first(LANGUAGE_DETECTION_SAMPLE_LENGTH)
    return nil if text.length < LANGUAGE_DETECTION_MIN_CHARS

    WhatLanguage.language_iso(text)&.to_s
  end

  # Every visible text node, skipping script/style/noscript. Uses XPath
  # instead of doc.css(...).remove so it doesn't mutate the shared doc
  # other extractors still read from.
  def visible_text(doc)
    doc.xpath("//text()[not(ancestor::script) and not(ancestor::style) and not(ancestor::noscript)]")
       .map(&:text).join(" ").gsub(/\s+/, " ").strip
  end

  # <link rel="alternate" hreflang="..."> is the standard way a site
  # declares it has other language versions of itself.
  def extract_available_languages(doc)
    doc.css('link[rel="alternate"][hreflang]').filter_map { |node| node["hreflang"].presence }.uniq.presence
  end

  # Tries each LOCALE_PATHS entry as a real page, not a redirect back
  # to the homepage.
  def probe_locale_paths(site)
    LOCALE_PATHS.filter_map do |path|
      response = fetch(site.url, path: path, retries: false)
      next unless response&.status == 200
      next if redirected_to_root?(response)

      path.delete_prefix("/")
    end.presence
  end

  # Same idea, but tries ru.example.kz/en.example.kz/... instead of a
  # path. Only counts if the response stayed on that subdomain.
  def probe_locale_subdomains(site)
    host = Addressable::URI.parse(site.url).host
    return nil if host.blank?

    LOCALE_SUBDOMAINS.filter_map do |sub|
      subdomain_host = "#{sub}.#{host}"
      response = fetch("https://#{subdomain_host}/", retries: false)
      next unless response&.status == 200
      next unless response.env.url.host == subdomain_host

      sub
    end.presence
  rescue Addressable::URI::InvalidURIError
    nil
  end

  def extract_favicon(doc)
    FAVICON_SELECTORS.each do |selector|
      href = doc.at_css(selector)&.attr("href")
      return href if href.present?
    end

    "/favicon.ico" # a plausible default guess — resolve_image_url weeds it out if it 404s
  end

  def meta_content(doc, key, property: false)
    selector = property ? %(meta[property="#{key}"]) : %(meta[name="#{key}"])
    doc.at_css(selector)&.attr("content")
  end

  def clean_text(text, max_length)
    text.to_s.gsub(/\s+/, " ").strip.first(max_length).presence
  end

  def normalize_city(raw)
    return nil if raw.blank?

    city = raw.to_s.strip.sub(CITY_PREFIX_PATTERN, "").sub(CITY_SUFFIX_PATTERN, "").strip
    return nil if city.blank?
    return nil unless city.match?(/\p{L}/) # must contain at least one letter — rejects stray digits/codes

    city
  end

  # resolve_url, plus a FastImage check that the URL actually points at
  # a real, non-trivial image (rejects 404s and tracking-pixel images).
  def resolve_image_url(base, candidate)
    url = resolve_url(base, candidate)
    return nil if url.blank?

    valid_image_url?(url) ? url : nil
  end

  def valid_image_url?(url)
    size = FastImage.size(url, timeout: FASTIMAGE_TIMEOUT, raise_on_failure: false)
    size.present? && size.all? { |dimension| dimension >= MIN_IMAGE_DIMENSION }
  rescue *network_rescue_classes(StandardError)
    false
  end

  # Also treats WebMock/VCR's "unstubbed request" errors as network
  # errors, so an unstubbed probe fails gracefully in specs.
  def network_rescue_classes(base)
    [ base, defined?(WebMock::NetConnectNotAllowedError) && WebMock::NetConnectNotAllowedError,
      defined?(VCR::Errors::UnhandledHTTPRequestError) && VCR::Errors::UnhandledHTTPRequestError ].select { |k| k }
  end

  def resolve_url(base, candidate)
    return nil if candidate.blank?

    Addressable::URI.join(base, candidate).to_s
  rescue Addressable::URI::InvalidURIError, ArgumentError
    nil
  end

  def save_technologies(site, detected)
    detected.map do |tech|
      attrs = { category: tech[:category], icon: tech[:icon] }
      technology = Technology.find_or_create_by!(name: tech[:name]) { |t| t.assign_attributes(attrs) }
      technology.update!(attrs) if attrs.any? { |key, value| technology[key] != value }
      SiteTechnology.find_or_create_by!(site: site, technology: technology)
      technology
    end
  end

  # retries: false skips the retry/backoff — for the many throwaway
  # probes (vacancy/locale paths, locale subdomains) where a failure
  # almost always means "doesn't exist", not "worth retrying", and
  # retrying all of them was the main reason a full run was so slow.
  def fetch(url, path: nil, retries: true)
    full_url = build_url(url, path)
    max_attempts = retries ? MAX_ATTEMPTS : 1
    attempts = 0

    begin
      attempts += 1
      connection.get(full_url)
    rescue *network_rescue_classes(Faraday::Error) => e
      if attempts < max_attempts
        sleep(RETRY_BACKOFF * attempts) if @delay.positive?
        retry
      end

      Rails.logger.warn("[TechnologyDetector] #{full_url} unreachable: #{e.class} #{e.message}")
      nil
    end
  end

  def build_url(url, path)
    return url if path.nil?

    "#{url.chomp('/')}#{path}"
  end

  def connection
    @connection ||= Faraday.new do |f|
      f.options.timeout = TIMEOUT
      f.options.open_timeout = OPEN_TIMEOUT
      f.headers["User-Agent"] = USER_AGENT
      # Without this, a redirect response's own tiny body ("301 Moved
      # Permanently") gets scraped as if it were the real homepage.
      f.response :follow_redirects, limit: REDIRECT_LIMIT
      f.adapter Faraday.default_adapter
    end
  end

  def log_summary(stats)
    Rails.logger.info(
      "[TechnologyDetector] checked=#{stats[:checked]} " \
      "with_technology=#{stats[:with_technology]} " \
      "with_vacancy=#{stats[:with_vacancy]} " \
      "unreachable=#{stats[:unreachable]}"
    )
  end
end
