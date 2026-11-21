require "net/http"
require "json"
require "yaml"
require "open3"

# Generates game artwork via fal.ai (Flux) from config/art/prompts.yml.
#
#   bin/rails art:generate                       # all missing images
#   bin/rails art:generate GROUP=traps           # one group
#   bin/rails art:generate KEYS=minotaure,ombre  # specific keys (regenerated even if present)
#
# Requires FAL_API_KEY (in .env) and ImageMagick (`magick`) for webp conversion.
namespace :art do
  desc "Generate missing game artwork with fal.ai"
  task :generate do
    api_key = ENV["FAL_API_KEY"] || read_dotenv_key("FAL_API_KEY")
    abort "FAL_API_KEY missing" if api_key.to_s.empty?

    config = YAML.load_file(Rails.root.join("config/art/prompts.yml"))
    only_group = ENV.fetch("GROUP", nil)
    only_keys = ENV["KEYS"]&.split(",")&.map(&:strip)
    model = ENV.fetch("FAL_MODEL", "fal-ai/flux/dev")

    jobs = []
    config["groups"].each do |group_name, group|
      next if only_group && only_group != group_name

      style = config["styles"].fetch(group["style"])
      out_dir = Rails.public_path.join("images", group["dir"])
      FileUtils.mkdir_p(out_dir)

      group["items"].each do |key, subject|
        next if only_keys&.exclude?(key)

        path = out_dir.join("#{key}.webp")
        next if path.exist? && !only_keys

        jobs << { key: key, prompt: "#{subject.strip}, #{style.strip}", size: group["size"],
                  width: group["output_width"], path: path, model: group["model"] || model }
      end
    end

    puts "#{jobs.size} image(s) to generate with #{model}"
    queue = Queue.new
    jobs.each { |j| queue << j }
    queue.close
    failures = []
    mutex = Mutex.new

    workers = Array.new([4, jobs.size].min) do
      Thread.new do
        while (job = queue.pop)
          begin
            generate_image(api_key, job[:model], job)
            mutex.synchronize { puts "  ok  #{job[:key]}" }
          rescue StandardError => e
            mutex.synchronize do
              failures << job[:key]
              puts "  FAIL #{job[:key]}: #{e.message}"
            end
          end
        end
      end
    end
    workers.each(&:join)

    puts failures.empty? ? "Done." : "Done with failures: #{failures.join(', ')}"
  end

  def read_dotenv_key(name)
    env_file = Rails.root.join(".env")
    return unless env_file.exist?

    line = env_file.readlines.find { |l| l.start_with?("#{name}=") }
    line&.split("=", 2)&.last&.strip&.delete("\"'")
  end

  def generate_image(api_key, model, job)
    uri = URI("https://fal.run/#{model}")
    req = Net::HTTP::Post.new(uri, "Authorization" => "Key #{api_key}", "Content-Type" => "application/json")
    req.body = { prompt: job[:prompt], image_size: job[:size], num_images: 1,
                 enable_safety_checker: false }.to_json
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 180) { |http| http.request(req) }
    raise "HTTP #{res.code}: #{res.body[0, 200]}" unless res.is_a?(Net::HTTPSuccess)

    url = JSON.parse(res.body).dig("images", 0, "url") or raise "no image url in response"
    image = Net::HTTP.get_response(URI(url))
    raise "download failed (#{image.code})" unless image.is_a?(Net::HTTPSuccess)

    tmp = "#{job[:path]}.src"
    File.binwrite(tmp, image.body)
    _out, err, status = Open3.capture3("magick", tmp, "-resize", "#{job[:width]}x", "-quality", "82", job[:path].to_s)
    raise "conversion failed: #{err}" unless status.success?
  ensure
    File.delete(tmp) if tmp && File.exist?(tmp)
  end
end
