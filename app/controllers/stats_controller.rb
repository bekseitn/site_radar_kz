class StatsController < ApplicationController
  MAX_TECHNOLOGIES_PER_CATEGORY = 10

  def index
    @category_stats = technology_category_stats
    set_meta_tags(title: t("stats.title"))
  end

  private

  # Grouped by Technology#category (CMS, Analytics, ...), not Site's business category.
  def technology_category_stats
    site_counts = Technology.joins(:sites).where.not(category: nil).group(:category).distinct.count("sites.id")
    tech_counts = Technology.joins(:sites).where.not(category: nil).group(:category, :name).count

    by_category = tech_counts.group_by { |(category, _name), _count| category }

    site_counts.map do |category, site_count|
      technologies = (by_category[category] || [])
        .map { |(_category, name), count| [ name, count ] }
        .sort_by { |(_name, count)| -count }
        .first(MAX_TECHNOLOGIES_PER_CATEGORY)

      { category: category, site_count: site_count, technologies: technologies }
    end.sort_by { |entry| -entry[:site_count] }
  end
end
