#
# Copyright (c) 2010 by RightScale Inc., all rights reserved
#
# Write given user data to files in /var/spool/ec2 in text, shell and ruby 
# script formats

module RightScale

  module MetadataWriters

    # Dictionary (key=value pairs) writer.
    class DictionaryMetadataWriter < MetadataWriter

      # Initializer.
      #
      # === Parameters
      # options[:file_extension](String):: dotted extension for dictionary files or nil
      def initialize(options)
        # defaults
        options = options.dup
        options[:file_extension] ||= '.dict'
        @formatter = FlatMetadataFormatter.new(options)
        # super
        super(options)
      end

      protected

      # Write given metadata to a dictionary file.
      #
      # === Parameters
      # metadata(Hash):: Hash-like metadata to write
      # subpath(Array|String):: subpath or nil
      #
      # === Return
      # always true
      def write_file(metadata)
        return unless @formatter.can_format?(metadata)
        flat_metadata = @formatter.format(metadata)
        File.open(create_full_path(@file_name_prefix), "w", DEFAULT_FILE_MODE) do |f|
          flat_metadata.each do |k, v|
            # ensure value is a single line by truncation since most
            # dictionary format parsers expect literal chars on a single line.
            v = self.class.first_line_of(v)
            f.puts "#{k}=#{v}"
          end
        end
        true
      end

    end  # DictionaryMetadataWriter

  end  # MetadataWriters

end  # RightScale
