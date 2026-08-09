require "hobo_rapid/theme"

# The Bootstrap theme: **a table of class names and a stylesheet**.
#
# It used to be a gem with `<page>` inside it, which is why there could only be
# one theme. Now the page is the catalogue's and says the role of each part;
# this says what Bootstrap calls those roles.
#
# Nothing here paints anything. If you want to see what Bootstrap does to a
# page, read the right-hand column.
module HoboBootstrap

  VERSION = File.read(File.expand_path("../../VERSION", __FILE__)).strip rescue "2.2.6"

  COLUMNS = (1..12).to_h { |n| ["content-#{n}", "col-lg-#{n}"] }
                   .merge((1..12).to_h { |n| ["aside-#{n}", "col-lg-#{n}"] })

  CLASSES = {

    # The page
    "navbar"        => "navbar navbar-expand-lg bg-body-tertiary border-bottom mb-4",
    "navbar-inner"  => "container-fluid px-4",
    "brand"         => "navbar-brand",
    "nav"           => "navbar-nav",
    "account-nav"   => "ms-auto align-items-center gap-2",
    "subnav-list"   => "nav-pills",
    "nav-link"      => "nav-link",
    "current"       => "active",
    "nav-item"      => "nav-item",
    "columns"       => "row",
    "aside-box"     => "card p-3",

    # The pages the engine derives
    "content-header" => "card card-body bg-body-tertiary p-3 mb-4",
    "header-line"    => "d-flex justify-content-between align-items-center",
    "count"          => "text-secondary mb-0",
    "empty"          => "text-secondary",
    "filters"        => "mb-3",
    "collection-table" => "table table-striped table-bordered",
    "field-list"     => "row",
    "field-label"    => "col-sm-3",
    "field-value"    => "col-sm-9",
    "card"           => "card",
    "inline"         => "d-inline",

    # What you press
    "action"   => "btn",
    "new"      => "btn-primary",
    "submit"   => "btn-primary",
    "edit"     => "btn-secondary",
    "delete"   => "btn-outline-danger",
    "button"   => "",

    # Forms and filters
    "form-control" => "form-control",
    "form-select"  => "form-select",
    "form-label"   => "form-label mb-0",
    "search"       => "d-inline-flex gap-2 align-items-center",
    **COLUMNS
  }.freeze

  # `HoboBootstrap.dress` for the site, `HoboBootstrap.dress("admin")` for a
  # subsite that wants to look different from the rest.
  def self.dress(subsite = nil)
    HoboRapid::Theme.wears("bootstrap", "hobo", :subsite => subsite, **CLASSES)
  end

end
