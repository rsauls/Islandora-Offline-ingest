require 'open3'

class Utils

  def Utils.ingest_usage
    program = $0.sub(/.*\//, '')
    STDERR.puts "Usage: #{program} <directory>"
    exit 1
  end


  def Utils.get_manifest config, directory

    manifest_filename = File.join(directory, 'manifest.xml')

    if not File.exists? manifest_filename
      raise PackageError, "Package directory #{directory} does not contain a manifest file."
    end

    manifest = Manifest.new(config, manifest_filename)

    # TODO: log

    if manifest.errors?
      raise PackageError, "Package manifest in #{directory} has errors: " + manifest.errors.join(';   ')
    end

    # TODO: add warnings

    return manifest
  end


  def Utils.get_mods config, directory

    name = File.basename directory
    mods_filename = File.join(directory, "#{name}.xml")

    if not File.exists? mods_filename
      raise PackageError, "Package directory #{directory} does not contain a MODS file named #{name}.xml."
    end

    mods = Mods.new(config, mods_filename)

    # TODO: log

    if mods.errors?
      raise PackageError, "Package MODS file in #{directory} has errors: " + mods.errors.join(';   ')
    end

    return mods
  end




  # from shellwords.rb:

  def Utils.shellescape(str)
    # An empty argument will be skipped, so return empty quotes.
    return "''" if str.empty?

    str = str.dup

    # Process as a single byte sequence because not all shell
    # implementations are multibyte aware.
    str.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/n, "\\\\\\1")

    # A LF cannot be escaped with a backslash because a backslash + LF
    # combo is regarded as line continuation and simply ignored.
    str.gsub!(/\n/, "'\n'")

    return str
  end

  # use the 'file' command to determine a file type. Argument FILE may be a filename or open IO object.  If the latter, and it supports rewind, it will be rewound when finished.

  def Utils.mime_type file

    type = error = nil

    case
    when file.is_a?(Magick::Image)

      error = []
      type = case file.format
             when 'GIF'  ; 'image/gif'
             when 'JP2'  ; 'image/jp2'
             when 'JPEG' ; 'image/jpeg'
             when 'PNG'  ; 'image/png'
             when 'TIFF' ; 'image/tiff'
             else;         'application/octet-stream'
             end

    when file.is_a?(IO)

      Open3.popen3("/usr/bin/file --mime-type -b -") do |stdin, stdout, stderr|

        file.rewind if file.methods.include? 'rewind'

        stdin.write file.read(1024 ** 2)  # don't need too much of this...
        stdin.close

        type   = stdout.read
        error  = stderr.read
      end
      file.rewind if file.methods.include? 'rewind'

    when file.is_a?(String)  # presumed a filename

      raise "file '#{file}' not found"    unless File.exists? file
      raise "file '#{file}' not readable" unless File.readable? file
      Open3.popen3("/usr/bin/file --mime-type -b " + shellescape(file)) do |stdin, stdout, stderr|

        type   = stdout.read
        error  = stderr.read
      end

      if file =~ /\.jp2/i and type.strip == 'application/octet-stream'
        type = 'image/jp2'
      end

    else
      error = "Unexpected input to /usr/bin/file: file argument was a #{file.class}"
    end

    # TODO: better than this.

    raise "Utils.mime_type error: #{error}" if not error.empty?

    return type.strip
  end


end
