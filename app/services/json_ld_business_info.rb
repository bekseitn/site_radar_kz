require "json"

# Walks every <script type="application/ld+json"> block on a page,
# collecting schema.org Organization/LocalBusiness-shaped business info:
# address locality, phone, email, logo, geo coordinates, opening hours,
# aggregate rating, "sameAs" profile links, and entity type (filtered to
# an allowlist — see CATEGORY_TYPES). Doesn't assume one specific JSON-LD
# shape (object, array, @graph, ...) — walks the whole parsed tree,
# keeping the first value found per single-value field and every value
# for multi-value ones (sameAs, type).
#
# Single public entry point, per project convention:
#   JsonLdBusinessInfo.extract(doc)
class JsonLdBusinessInfo
  # An allowlist, not a denylist — a JSON-LD document nests many
  # schema.org sub-object types (PostalAddress, ContactPoint, Offer, ...)
  # that say nothing about what kind of business this is.
  CATEGORY_TYPES = %w[
    LocalBusiness Organization Corporation Store OnlineStore Restaurant
    CafeOrCoffeeShop BarOrPub Bakery FoodEstablishment GroceryStore
    ConvenienceStore LiquorStore Hotel LodgingBusiness MedicalBusiness
    MedicalClinic Hospital Dentist Physician Pharmacy VeterinaryCare
    HealthAndBeautyBusiness BeautySalon HairSalon AutomotiveBusiness
    AutoRepair AutoDealer RealEstateAgent FinancialService
    BankOrCreditUnion InsuranceAgency LegalService Attorney
    AccountingService EmploymentAgency TravelAgency
    GymOrFitnessCenter SportsActivityLocation EducationalOrganization
    School CollegeOrUniversity NewsMediaOrganization Newspaper NGO
    GovernmentOrganization ProfessionalService
    HomeAndConstructionBusiness Electrician Plumber HousePainter
    MovingCompany ChildCare ClothingStore ElectronicsStore
    FurnitureStore JewelryStore ShoppingCenter SportingGoodsStore
    Florist HardwareStore PetStore BookStore
  ].freeze

  DAY_ABBREVIATIONS = {
    "Monday" => "Mo", "Tuesday" => "Tu", "Wednesday" => "We", "Thursday" => "Th",
    "Friday" => "Fr", "Saturday" => "Sa", "Sunday" => "Su"
  }.freeze
  DAY_ORDER = DAY_ABBREVIATIONS.keys.freeze

  def self.extract(doc) = new.extract(doc)

  def extract(doc)
    info = {}

    doc.css('script[type="application/ld+json"]').each do |node|
      merge!(info, JSON.parse(node.text))
    rescue JSON::ParserError
      next
    end

    info
  end

  private

  def merge!(info, node)
    case node
    when Hash
      merge_hash!(info, node)
      node.each_value { |value| merge!(info, value) }
    when Array
      node.each { |item| merge!(info, item) }
    end
  end

  def merge_hash!(info, node)
    # A page can list more than one city (multiple branches/addresses),
    # so every distinct locality found is kept, not just the first.
    locality = node["address"]["addressLocality"] if node["address"].is_a?(Hash)
    (info[:cities] ||= []) << locality if locality.present?

    info[:phone] ||= node["telephone"] if node["telephone"].present?
    info[:email] ||= node["email"] if node["email"].present?
    info[:logo] ||= logo_url(node["logo"])

    if node["geo"].is_a?(Hash)
      info[:latitude] ||= node["geo"]["latitude"]
      info[:longitude] ||= node["geo"]["longitude"]
    end

    if node["aggregateRating"].is_a?(Hash)
      rating = node["aggregateRating"]
      info[:rating] ||= rating["ratingValue"]
      info[:review_count] ||= rating["reviewCount"] || rating["ratingCount"]
    end

    info[:opening_hours] ||= opening_hours(node)

    if node["sameAs"].present?
      (info[:same_as] ||= []).concat(Array(node["sameAs"]))
    end

    Array(node["@type"]).each do |type|
      next unless type.is_a?(String) && CATEGORY_TYPES.include?(type)

      (info[:types] ||= []) << type
    end
  end

  def logo_url(logo)
    return logo if logo.is_a?(String)
    return logo["url"] if logo.is_a?(Hash)

    nil
  end

  # "openingHours" is a ready-made compact string (e.g. "Mo-Fr
  # 09:00-18:00"); "openingHoursSpecification" is a list of {dayOfWeek,
  # opens, closes} objects that has to be formatted into one instead.
  def opening_hours(node)
    node["openingHours"].presence || format_specification(node["openingHoursSpecification"])
  end

  def format_specification(spec)
    return nil unless spec.is_a?(Array)

    spec.filter_map { |entry| format_specification_entry(entry) }.presence&.join("; ")
  end

  def format_specification_entry(entry)
    return nil unless entry.is_a?(Hash)

    opens = entry["opens"]
    closes = entry["closes"]
    return nil if opens.blank? || closes.blank?

    days = Array(entry["dayOfWeek"]).map { |day| day.to_s.split("/").last } # some sites use full URIs
    day_label = format_days(days)
    return nil if day_label.blank?

    "#{day_label} #{opens}-#{closes}"
  end

  # Collapses a contiguous run (e.g. Monday..Friday) to "Mo-Fr"; lists
  # anything else out as "Mo,We,Fr".
  def format_days(days)
    indices = days.filter_map { |day| DAY_ORDER.index(day) }.sort.uniq
    return nil if indices.empty?

    if indices == (indices.first..indices.last).to_a
      first, last = DAY_ORDER[indices.first], DAY_ORDER[indices.last]
      first == last ? DAY_ABBREVIATIONS[first] : "#{DAY_ABBREVIATIONS[first]}-#{DAY_ABBREVIATIONS[last]}"
    else
      indices.map { |i| DAY_ABBREVIATIONS[DAY_ORDER[i]] }.join(",")
    end
  end
end
