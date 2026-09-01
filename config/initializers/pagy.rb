# Pagy has its own tiny built-in i18n by default — switches it to
# Rails' I18n gem so pagination text (info_tag, nav labels) follows
# this app's own locale instead of always English/Russian.
Pagy.translate_with_the_slower_i18n_gem!
