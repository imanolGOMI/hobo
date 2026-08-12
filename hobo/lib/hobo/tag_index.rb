# Who defines each tag -- `rails hobo:tags`.
#
# A plugin installs itself by being in the Gemfile (piece 17): its engine loads,
# its tag files run, and running them *is* registering the tags. That is the
# whole contract, and it is as small as it is because the registry is global.
#
# Global is also the danger. A tag is looked up by name, so two gems that
# both define `<view-content> for Date` do not collide, do not warn and do not
# fail: the one that loaded last paints every date in the application and the
# other one is simply never called again. When the gems of this repository were
# merged, five tags of a spike turned out to be shadowing five real ones of the
# catalogue, and what noticed was a person looking at a screenshot.
#
# So this exists to make the second owner of a name visible from outside:
#
#   $ bin/rails hobo:tags
#   view_content                    hobo/lib/hobo_rapid/tags/views.rb
#     for Date            shadowed  hobo/lib/hobo_rapid/tags/views.rb
#     for Date                      hobo_timeago/lib/hobo_timeago/tags.rb
#
# It reads Rapid's own record of who defined what; it does not guess.

require "rapid"

module Hobo

  class TagIndex

    # `shadowed` is the point of the whole file: this definition is still in the
    # record and no longer in effect, because a later one took the same name.
    Row = Struct.new(:name, :kind, :type, :owner, :file, :shadowed, :keyword_init => true) do
      def label
        case kind
        when :define_for then "for #{type}"
        when :extend     then "extended by"
        else name.to_s
        end
      end

      def source = [owner, file].compact.join("/")
    end

    def initialize(definitions = Rapid.definitions)
      @definitions = definitions
    end

    # Every definition, in the order it was made, grouped by tag.
    def rows
      @rows ||= begin
        # `extend_tag` prepends a module: two extensions of one tag both run, so
        # an extension never shadows anything and is never shadowed. Only a
        # definition takes a name away from another definition.
        last = {}
        @definitions.each_with_index { |d, i| last[key(d)] = i unless d.kind == :extend }

        @definitions.each_with_index.map do |definition, index|
          owner, file = owner_and_file(definition.source)
          Row.new(:name => definition.name, :kind => definition.kind,
                  :type => definition.type, :owner => owner, :file => file,
                  :shadowed => last.key?(key(definition)) && last[key(definition)] != index)
        end
      end
    end

    # The owners that brought tags, in the order they first did. An application
    # gets to see its plugins as a list, which is the other half of "installing
    # a plugin is adding the gem": you can check what adding it did.
    def owners = rows.map(&:owner).compact.uniq

    def shadowed = rows.select(&:shadowed)

    def render
      lines = rows.group_by(&:name).sort_by { |name, _| name.to_s }.flat_map do |name, group|
        base, rest = group.partition { |row| row.kind == :define }
        (base + rest).map { |row| line(row, :indent => row.kind != :define) }
      end

      (lines + ["", summary]).join("\n")
    end

    private

    def summary
      count = rows.group_by(&:name).size
      note = shadowed.empty? ? "" : ", #{shadowed.size} shadowed"
      "#{count} tags, #{rows.size} definitions#{note} -- #{owners.join(', ')}"
    end

    def line(row, indent:)
      label = (indent ? "  " : "") + row.label
      "#{label.ljust(34)}#{row.shadowed ? 'shadowed  ' : '          '}#{row.source}"
    end

    def key(definition) = [definition.name, definition.kind, definition.type]

    # Which gem -- or the application itself -- a file belongs to.
    #
    # Path gems are in `Gem.loaded_specs` like any other, so a plugin developed
    # from a working tree is named the same as one installed from rubygems. A
    # suite that runs without bundler has no specs at all, and then the gemspec
    # sitting in the tree answers the same question.
    def owner_and_file(path)
      return [nil, "?"] if path.nil?

      spec = gem_for(path)
      return [spec.name, relative(path, spec.full_gem_path)] if spec

      root = defined?(Rails) && Rails.respond_to?(:root) && Rails.root
      return [app_name, relative(path, root)] if root && inside?(path, root.to_s)

      gemspec_for(path) || [nil, path]
    end

    def gem_for(path)
      Gem.loaded_specs.values.find { |spec| inside?(path, spec.full_gem_path) }
    end

    # The nearest directory above the file that holds a gemspec.
    def gemspec_for(path)
      @gemspecs ||= {}
      directory = File.dirname(path)

      while directory != "/" && directory != "."
        found = @gemspecs.fetch(directory) { @gemspecs[directory] = Dir[File.join(directory, "*.gemspec")].first }
        return [File.basename(found, ".gemspec"), relative(path, directory)] if found
        directory = File.dirname(directory)
      end
      nil
    end

    def app_name
      return "(app)" unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application
      Rails.application.class.module_parent_name.underscore
    end

    def inside?(path, root) = path.start_with?(root.to_s.chomp("/") + "/")

    def relative(path, root) = path.delete_prefix(root.to_s.chomp("/") + "/")

  end

end
