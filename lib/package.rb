require 'digest'
require 'yaml'

module Package
  def s3_bucket_prefix
    obj.fetch('s3_bucket_prefix')
  end

  def account_id
    @account_id ||= begin
      caller_id = ::Kernel.send(:`, "aws sts get-caller-identity")
      YAML.load(caller_id)['Account']
    end
  end

  def region
    @region ||= begin
      config_region = ::Kernel.send(:`, "aws configure get region").strip
      config_region.empty? ? 'us-east-1' : config_region
    end
  end

  def s3_file(file, prefix = File.basename(file))
    checksum = Digest::MD5.file(file).hexdigest
    s3_uri = "s3://#{s3_bucket_prefix}-#{region}/#{prefix}#{prefix ? '.' : ''}#{checksum}"

    if system("aws", "s3", "ls", s3_uri)
      ::File.delete(file)
    else 
      unless system("aws", "s3", "mv", file, s3_uri)
        ::Kernel.exit $?.exitstatus
      end
    end

    s3_uri
  end

  def s3_template(file, prefix = File.basename(file))
    outfile = "template.#{Digest::MD5.file(file).hexdigest}"
    File.open(outfile, "w") do |io|
      template = Linecook::Template.new(file)
      io << template.result(obj)
    end
    s3_file outfile, prefix
  end

  def s3_zip(files, prefix = nil)
    zipfile = "package.#{Digest::MD5.hexdigest files.join(',')}.zip"
    unless system("zip", "-r", "-X", zipfile, *files)
      ::Kernel.exit $?.exitstatus
    end
    s3_file zipfile, prefix
  end

  def system(*args)
    $stderr.puts "run: #{args.join(' ')}"
    ::Kernel.system(*args)
  end
end

class Linecook::Context
  include ::Package
end
