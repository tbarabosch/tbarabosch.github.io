#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "date"
require "json"
require "open3"
require "pathname"
require "set"
require "uri"
require "yaml"

ROOT = Pathname.new(__dir__).join("..").expand_path
SITE = ROOT.join("_site")
SITE_URL = "https://tbarabosch.com"

errors = []

def load_yaml(path)
  YAML.safe_load(
    path.read,
    permitted_classes: [Date, Time],
    aliases: false
  )
end

def front_matter(path)
  source = path.read
  match = source.match(/\A---\s*\n(.*?)\n---\s*\n/m)
  raise "missing YAML front matter" unless match

  data = YAML.safe_load(
    match[1],
    permitted_classes: [Date, Time],
    aliases: false
  ) || {}
  [data, source[match.end(0)..] || ""]
end

def html_values(html, element, attribute, expected = nil)
  html.scan(/<#{element}\b[^>]*>/i).filter_map do |tag|
    value = tag[/\b#{attribute}\s*=\s*(["'])(.*?)\1/i, 2]
    next unless value
    next if expected && tag !~ expected

    CGI.unescapeHTML(value)
  end
end

def public_path_for(html_path)
  relative = html_path.relative_path_from(SITE).to_s
  return "/" if relative == "index.html"
  return "/#{relative.delete_suffix("index.html")}" if relative.end_with?("/index.html")

  "/#{relative}"
end

def generated_target(path)
  clean = path.sub(%r{\A/+}, "")
  candidate = SITE.join(clean)
  return candidate if candidate.file?
  return candidate.join("index.html") if candidate.directory? && candidate.join("index.html").file?
  return SITE.join(clean, "index.html") if path.end_with?("/") && SITE.join(clean, "index.html").file?

  candidate
end

unless SITE.directory?
  warn "_site is missing; run scripts/build-site.sh first."
  exit 1
end

tracked_posts = Open3.capture2("git", "-C", ROOT.to_s, "ls-files", "--", "_posts/*.md").first.lines.map(&:strip).reject(&:empty?)
errors << "no tracked posts found" if tracked_posts.empty?

topics = load_yaml(ROOT.join("_data/topics.yml"))
unless topics.is_a?(Array) && topics.all? { |topic| topic.is_a?(Hash) }
  errors << "_data/topics.yml must contain a list of topic mappings"
  topics = []
end

topic_names = Set.new
topic_slugs = Set.new
topics.each do |topic|
  %w[name slug tags].each do |key|
    errors << "topic #{topic.inspect} is missing #{key}" unless topic[key]
  end
  errors << "duplicate topic name: #{topic['name']}" unless topic_names.add?(topic["name"])
  errors << "duplicate topic slug: #{topic['slug']}" unless topic_slugs.add?(topic["slug"])
end

catalog_tags = load_yaml(ROOT.join("_data/tags.yml"))
catalog_tags = [] unless catalog_tags.is_a?(Array)
used_tags = Set.new
post_records = []
post_titles = Set.new

tracked_posts.each do |relative|
  path = ROOT.join(relative)
  begin
    data, body = front_matter(path)
  rescue StandardError => e
    errors << "#{relative}: #{e.message}"
    next
  end

  %w[title date last_modified_at author layout tags].each do |key|
    errors << "#{relative}: missing required front matter #{key}" if data[key].nil?
  end
  errors << "#{relative}: layout must be post" unless data["layout"] == "post"

  tags = Array(data["tags"])
  errors << "#{relative}: tags must be a non-empty list" if tags.empty?
  tags.each { |tag| used_tags << tag }

  unless post_titles.add?(data["title"])
    errors << "#{relative}: duplicate post title #{data['title'].inspect}"
  end

  begin
    published = DateTime.parse(data["date"].to_s)
    modified = DateTime.parse(data["last_modified_at"].to_s)
    errors << "#{relative}: last_modified_at precedes date" if modified < published
  rescue Date::Error
    errors << "#{relative}: date and last_modified_at must be valid dates"
  end

  matching_topics = topics.select { |topic| !(tags & Array(topic["tags"])).empty? }
  topic_neutral = tags == ["site notes"]
  if matching_topics.empty? && !topic_neutral
    errors << "#{relative}: does not match a topic and is not an intentional site note"
  elsif topic_neutral && !matching_topics.empty?
    errors << "#{relative}: site notes must remain topic-neutral"
  end

  word_count = body.scan(/[\p{L}\p{N}_'-]+/u).length
  section_count = body.scan(/^##\s+\S/).length
  if word_count >= 1_500 && section_count >= 2 && data["toc"] != true
    errors << "#{relative}: long structured post must set toc: true"
  end

  slug = File.basename(relative, ".md").sub(/\A\d{4}-\d{2}-\d{2}-/, "")
  post_records << { relative: relative, data: data, route: "/#{slug}/" }
end

missing_tags = used_tags - catalog_tags.to_set
unused_tags = catalog_tags.to_set - used_tags
errors << "tag catalog is missing: #{missing_tags.to_a.sort.join(', ')}" unless missing_tags.empty?
errors << "tag catalog contains unused tags: #{unused_tags.to_a.sort.join(', ')}" unless unused_tags.empty?
errors << "tag catalog contains duplicates" unless catalog_tags.uniq.length == catalog_tags.length

required_files = %w[
  sitemap.xml
  robots.txt
  feed.xml
  images/social-card.png
  assets/js/site.js
]
required_files.each do |relative|
  errors << "generated site is missing #{relative}" unless SITE.join(relative).file?
end

social_card = SITE.join("images/social-card.png")
if social_card.file?
  png = social_card.binread
  if png.byteslice(0, 8) != "\x89PNG\r\n\x1a\n".b || png.bytesize < 24
    errors << "default social image is not a valid PNG"
  else
    width, height = png.byteslice(16, 8).unpack("NN")
    errors << "default social image must be 1200x630, got #{width}x#{height}" unless [width, height] == [1_200, 630]
  end
end

html_paths = SITE.glob("**/*.html").sort
errors << "generated site contains no HTML" if html_paths.empty?

seen_titles = {}
seen_descriptions = {}
seen_canonicals = {}

html_paths.each do |path|
  relative = path.relative_path_from(SITE).to_s
  html = path.read
  public_path = public_path_for(path)

  titles = html.scan(/<title\b[^>]*>(.*?)<\/title>/im).flatten.map { |value| CGI.unescapeHTML(value.gsub(/<[^>]+>/, "").strip) }
  descriptions = html_values(html, "meta", "content", /\bname\s*=\s*(["'])description\1/i)
  canonicals = html_values(html, "link", "href", /\brel\s*=\s*(["'])canonical\1/i)
  og_titles = html_values(html, "meta", "content", /\bproperty\s*=\s*(["'])og:title\1/i)
  og_descriptions = html_values(html, "meta", "content", /\bproperty\s*=\s*(["'])og:description\1/i)
  og_urls = html_values(html, "meta", "content", /\bproperty\s*=\s*(["'])og:url\1/i)
  og_images = html_values(html, "meta", "content", /\bproperty\s*=\s*(["'])og:image\1/i)

  {
    "title element" => titles,
    "description element" => descriptions,
    "canonical element" => canonicals,
    "Open Graph title" => og_titles,
    "Open Graph description" => og_descriptions,
    "Open Graph URL" => og_urls,
    "Open Graph image" => og_images
  }.each do |label, values|
    errors << "#{relative}: expected one #{label}, found #{values.length}" unless values.length == 1
    errors << "#{relative}: #{label} is empty" if values.length == 1 && values.first.strip.empty?
  end

  if titles.length == 1
    prior = seen_titles[titles.first]
    errors << "#{relative}: title duplicates #{prior}" if prior
    seen_titles[titles.first] = relative
  end
  if descriptions.length == 1
    prior = seen_descriptions[descriptions.first]
    errors << "#{relative}: description duplicates #{prior}" if prior
    seen_descriptions[descriptions.first] = relative
  end
  if canonicals.length == 1
    expected = "#{SITE_URL}#{public_path}"
    errors << "#{relative}: canonical is #{canonicals.first.inspect}, expected #{expected.inspect}" unless canonicals.first == expected
    prior = seen_canonicals[canonicals.first]
    errors << "#{relative}: canonical duplicates #{prior}" if prior
    seen_canonicals[canonicals.first] = relative
  end

  json_ld_blocks = html.scan(/<script\b[^>]*type\s*=\s*(["'])application\/ld\+json\1[^>]*>(.*?)<\/script>/im).map(&:last)
  errors << "#{relative}: expected one JSON-LD block, found #{json_ld_blocks.length}" unless json_ld_blocks.length == 1
  if json_ld_blocks.length == 1
    begin
      JSON.parse(json_ld_blocks.first)
    rescue JSON::ParserError => e
      errors << "#{relative}: invalid JSON-LD: #{e.message}"
    end
  end

  html.scan(/<script\b[^>]*\bsrc\s*=\s*(["'])(.*?)\1/im).each do |_quote, src|
    errors << "#{relative}: remote script is forbidden: #{src}" if src.match?(%r{\A(?:https?:)?//}i)
  end
  html.scan(/<(?:iframe|embed|object)\b[^>]*\b(?:src|data)\s*=\s*(["'])(.*?)\1/im).each do |_quote, src|
    errors << "#{relative}: automatically loaded third-party resource is forbidden: #{src}" if src.match?(%r{\A(?:https?:)?//}i)
  end
  html.scan(/<(?:img|source|audio|video)\b[^>]*\bsrc\s*=\s*(["'])(.*?)\1/im).each do |_quote, src|
    errors << "#{relative}: automatically loaded third-party media is forbidden: #{src}" if src.match?(%r{\A(?:https?:)?//}i)
  end
  html.scan(/<link\b[^>]*>/im).each do |tag|
    rel = tag[/\brel\s*=\s*(["'])(.*?)\1/i, 2].to_s.downcase
    href = tag[/\bhref\s*=\s*(["'])(.*?)\1/i, 2].to_s
    next unless rel.match?(/\b(?:stylesheet|icon|preload|modulepreload)\b/)

    errors << "#{relative}: automatically loaded third-party link is forbidden: #{href}" if href.match?(%r{\A(?:https?:)?//}i)
  end

  html.scan(/\b(?:href|src)\s*=\s*(["'])(.*?)\1/im).each do |_quote, raw_value|
    value = CGI.unescapeHTML(raw_value).strip
    next if value.empty? || value.start_with?("mailto:", "tel:", "javascript:", "data:")

    begin
      uri = URI.parse(value)
    rescue URI::InvalidURIError
      errors << "#{relative}: invalid internal reference #{value.inspect}"
      next
    end

    if uri.host
      next unless uri.host == "tbarabosch.com"
    elsif uri.scheme || value.start_with?("//")
      next
    end

    path_part = uri.path.to_s
    fragment = uri.fragment
    if path_part.empty? && !uri.host
      target_path = path
    else
      decoded_path = CGI.unescape(path_part.empty? ? "/" : path_part)
      absolute_path = if decoded_path.start_with?("/")
                        decoded_path
                      else
                        base = public_path.end_with?("/") ? public_path : File.dirname(public_path) + "/"
                        Pathname.new(base).join(decoded_path).cleanpath.to_s
                      end
      target_path = generated_target(absolute_path)
    end

    unless target_path.file?
      errors << "#{relative}: broken internal path #{value.inspect}"
      next
    end

    next unless fragment && !fragment.empty? && target_path.extname == ".html"

    target_html = target_path.read
    decoded_fragment = CGI.unescape(fragment)
    ids = target_html.scan(/\bid\s*=\s*(["'])(.*?)\1/im).map { |match| CGI.unescapeHTML(match.last) }.to_set
    errors << "#{relative}: missing fragment ##{decoded_fragment} in #{value.inspect}" unless ids.include?(decoded_fragment)
  end
end

post_records.each do |post|
  output = generated_target(post[:route])
  unless output.file?
    errors << "#{post[:relative]}: generated post is missing at #{post[:route]}"
    next
  end

  html = output.read
  %w[author published length tags].each do |label|
    errors << "#{post[:relative]}: generated metadata is missing #{label}" unless html.match?(/<dt[^>]*>#{label}<\/dt>/i)
  end
  if post[:data]["toc"] == true && !html.include?('class="post-toc"')
    errors << "#{post[:relative]}: toc: true did not generate a contents section"
  end

  json_ld_text = html.scan(/<script\b[^>]*type\s*=\s*(["'])application\/ld\+json\1[^>]*>(.*?)<\/script>/im).map(&:last).first
  next unless json_ld_text

  begin
    json_ld = JSON.parse(json_ld_text)
    types = Array(json_ld["@type"])
    errors << "#{post[:relative]}: JSON-LD must identify a BlogPosting" unless types.include?("BlogPosting")
    %w[datePublished dateModified author].each do |key|
      errors << "#{post[:relative]}: JSON-LD is missing #{key}" unless json_ld[key]
    end
    author_name = json_ld.dig("author", "name")
    errors << "#{post[:relative]}: JSON-LD author must be Thomas Barabosch" unless author_name == "Thomas Barabosch"
  rescue JSON::ParserError
    # The document-level error above is more useful.
  end
end

homepage = SITE.join("index.html")
if homepage.file?
  html = homepage.read
  recent_position = html.index("RECENT CHANGES")
  topics_position = html.index("TOPICS")
  unless recent_position && topics_position && recent_position < topics_position
    errors << "homepage must place RECENT CHANGES before TOPICS"
  end
  errors << "homepage H1 changed unexpectedly" unless html.match?(/<h1[^>]*class="manual-title"[^>]*>Thomas Barabosch<\/h1>/)
end

robots = SITE.join("robots.txt")
if robots.file?
  text = robots.read
  errors << "robots.txt must allow the site" unless text.match?(/^Allow:\s*\/$/)
  errors << "robots.txt must reference the sitemap" unless text.include?("#{SITE_URL}/sitemap.xml")
end

sitemap = SITE.join("sitemap.xml")
if sitemap.file?
  text = sitemap.read
  errors << "sitemap.xml contains no URLs" unless text.include?("<loc>")
  post_records.each do |post|
    errors << "sitemap.xml is missing #{post[:route]}" unless text.include?("<loc>#{SITE_URL}#{post[:route]}</loc>")
  end
end

feed = SITE.join("feed.xml")
if feed.file?
  text = feed.read
  item_descriptions = text.scan(/<item>.*?<description>(.*?)<\/description>.*?<\/item>/m).flatten
  errors << "feed.xml must include full article content" if item_descriptions.empty? || item_descriptions.any? { |content| content.length < 500 }
  errors << "feed.xml must include author metadata" unless text.include?("<dc:creator>")
end

compiled_css = SITE.join("assets/css/style.css")
if compiled_css.file? && compiled_css.read.match?(%r{(?:@import|url\()[^)]*https?://}i)
  errors << "compiled CSS loads a remote resource"
end

search_page = SITE.join("search/index.html")
if search_page.file?
  html = search_page.read
  errors << "search page must expose every article without JavaScript" unless html.scan(/class="article-row search-result"/).length == post_records.length
  errors << "search page must explain its no-JavaScript fallback" unless html.include?("<noscript>")
end

if errors.empty?
  puts "Generated-site validation passed (#{tracked_posts.length} posts, #{catalog_tags.length} tags, #{html_paths.length} HTML pages)."
else
  warn "Generated-site validation failed with #{errors.length} error(s):"
  errors.uniq.sort.each { |error| warn "- #{error}" }
  exit 1
end
