# frozen_string_literal: true

require 'blueprinter/errors/invalid_root'
require 'blueprinter/errors/meta_requires_root'

module Blueprinter
  # Encapsulates the rendering logic for Blueprinter.
  module Rendering
    include TypeHelpers

    # Generates a JSON formatted String represantation of an Object based on the provided view.
    #
    # @param object [Object] the Object to serialize.
    # @param options [Hash] the options hash which requires a :view. Any
    #   additional key value pairs will be exposed during serialization.
    # @option options [Symbol] :view Defaults to :default.
    #   The view name that corresponds to the group of
    #   fields to be serialized.
    # @option options [Symbol|String] :root Defaults to nil.
    #   Render the json/hash with a root key if provided.
    # @option options [Any] :meta Defaults to nil.
    #   Render the json/hash with a meta attribute with provided value
    #   if both root and meta keys are provided in the options hash.
    #
    # @example Generating JSON with an extended view
    #   post = Post.all
    #   Blueprinter::Base.render post, view: :extended
    #   # => "[{\"id\":1,\"title\":\"Hello\"},{\"id\":2,\"title\":\"My Day\"}]"
    #
    # @return [String] JSON formatted String
    def render(object, options = {})
      # puts <<~MSG
      #   ======================
      #   OPTIONS:
      #     #{options.map { |k, v| "-#{k}: #{v}" }.join("\n")}
      #   ======================
      # MSG

      view_name = options.fetch(:view, :default)

      prepared_object = hashify(
        object,
        view_name: view_name,
        local_options: options.except(:view)
      )
      root, meta = handle_root_and_meta(options)
      prepared_object = prepend_root_and_meta(prepared_object, root, meta)

      jsonify(prepared_object)
    end

    # Generates a hash.
    # Takes a required object and an optional view.
    #
    # @param object [Object] the Object to serialize upon.
    # @param options [Hash] the options hash which requires a :view. Any
    #   additional key value pairs will be exposed during serialization.
    # @option options [Symbol] :view Defaults to :default.
    #   The view name that corresponds to the group of
    #   fields to be serialized.
    # @option options [Symbol|String] :root Defaults to nil.
    #   Render the json/hash with a root key if provided.
    # @option options [Any] :meta Defaults to nil.
    #   Render the json/hash with a meta attribute with provided value
    #   if both root and meta keys are provided in the options hash.
    #
    # @example Generating a hash with an extended view
    #   post = Post.all
    #   Blueprinter::Base.render_as_hash post, view: :extended
    #   # => [{id:1, title: Hello},{id:2, title: My Day}]
    #
    # @return [Hash]
    def render_as_hash(object, options = {})
      view_name = options.fetch(:view, :default)

      hashified_object = hashify(
        object,
        view_name: view_name,
        local_options: options.except(:view)
      )
      root, meta = handle_root_and_meta(options)

      prepend_root_and_meta(hashified_object, root, meta)
    end

    # Generates a JSONified hash.
    # Takes a required object and an optional view.
    #
    # @param object [Object] the Object to serialize upon.
    # @param options [Hash] the options hash which requires a :view. Any
    #   additional key value pairs will be exposed during serialization.
    # @option options [Symbol] :view Defaults to :default.
    #   The view name that corresponds to the group of
    #   fields to be serialized.
    # @option options [Symbol|String] :root Defaults to nil.
    #   Render the json/hash with a root key if provided.
    # @option options [Any] :meta Defaults to nil.
    #   Render the json/hash with a meta attribute with provided value
    #   if both root and meta keys are provided in the options hash.
    #
    # @example Generating a hash with an extended view
    #   post = Post.all
    #   Blueprinter::Base.render_as_json post, view: :extended
    #   # => [{"id" => "1", "title" => "Hello"},{"id" => "2", "title" => "My Day"}]
    #
    # @return [Hash]
    def render_as_json(object, options = {})
      view_name = options.fetch(:view, :default)

      hashfied_object = hashify(
        object,
        view_name: view_name,
        local_options: options.except(:view)
      )

      root, meta = handle_root_and_meta(options)
      prepend_root_and_meta(hashfied_object, root, meta).as_json
    end

    # Converts an object into a hash representation based on provided view.
    #
    # @param object [Object] the Object to convert into a Hash.
    # @param view_name [Symbol] the view
    # @param local_options [Hash] the options hash which requires a :view. Any
    #   additional key value pairs will be exposed during serialization.
    # @return [Hash]
    def hashify(object, view_name:, local_options:)
      raise BlueprinterError, "View '#{view_name}' is not defined" unless view_collection.view?(view_name)

      object = Blueprinter.configuration.extensions.pre_render(object, self, view_name, local_options)
      prepare_data(object, view_name, local_options)
    end

    private

    attr_reader :blueprint, :options

    def handle_root_and_meta(options)
      root = options[:root]
      meta = options[:meta]

      validate_root_and_meta!(root, meta)

      [root, meta]
    end

    def validate_root_and_meta!(root, meta)
      return if root.is_a?(String) || root.is_a?(Symbol)

      raise(Errors::InvalidRoot, 'root should be one of String, Symbol, NilClass') unless root.nil?
      raise(Errors::MetaRequiresRoot, 'meta requires a root to be passed') if meta
    end

    def prepend_root_and_meta(data, root, meta)
      return data unless root

      ret = { root => data }
      meta ? ret.merge!(meta: meta) : ret
    end

    def prepare_data(object, view_name, local_options)
      if array_like?(object)
        object.map do |obj|
          object_to_hash(obj,
                         view_name: view_name,
                         local_options: local_options)
        end
      else
        object_to_hash(object,
                       view_name: view_name,
                       local_options: local_options)
      end
    end

    def object_to_hash(object, view_name:, local_options:)
      result_hash = view_collection.fields_for(view_name).each_with_object({}) do |field, hash|
        next if field.skip?(field.name, object, local_options)

        hash[field.name] = field.extract(object, local_options)
      end
      view_collection.transformers(view_name).each do |transformer|
        transformer.transform(result_hash, object, local_options)
      end
      result_hash
    end

    def jsonify(data)
      Blueprinter.configuration.jsonify(data)
    end
  end
end
