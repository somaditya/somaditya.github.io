require "json"
require "net/http"
require "open3"
require "uri"

module Jekyll
  class GitHubPortfolioGenerator < Generator
    safe true
    priority :highest

    API_BASE = "https://api.github.com".freeze
    PAGE_SIZE = 100
    PROJECT_LIMIT = 9

    class ApiError < StandardError; end

    def generate(site)
      username = site.config.dig("social-network-links", "github")
      raise ApiError, "GitHub username is not configured in social-network-links.github" if username.to_s.empty?

      projects = fetch_repositories(username)
        .map { |repository| repository.merge("commits_count" => commit_count(repository)) }
        .sort_by do |repository|
          [-repository["commits_count"], -repository["stargazers_count"].to_i, repository["name"].downcase]
        end
        .first(PROJECT_LIMIT)

      site.config["github_projects"] = projects.map do |repository|
        {
          "name" => repository["name"],
          "full_name" => repository["full_name"],
          "description" => repository["description"],
          "html_url" => repository["html_url"],
          "language" => repository["language"],
          "stargazers_count" => repository["stargazers_count"],
          "forks_count" => repository["forks_count"],
          "commits_count" => repository["commits_count"]
        }
      end
    rescue ApiError => error
      raise Jekyll::Errors::FatalException, "Unable to load GitHub portfolio: #{error.message}"
    end

    private

    def fetch_repositories(username)
      repositories = []
      page = 1

      loop do
        response = request(
          "/users/#{URI.encode_www_form_component(username)}/repos",
          "type" => "owner",
          "per_page" => PAGE_SIZE,
          "page" => page
        )
        raise ApiError, "repository response was not an array" unless response.is_a?(Array)

        repositories.concat(response)
        break if response.length < PAGE_SIZE

        page += 1
      end

      repositories
    end

    def commit_count(repository)
      return 0 if repository["default_branch"].to_s.empty?

      uri = api_uri(
        "/repos/#{repository["full_name"]}/commits",
        "per_page" => 1,
        "sha" => repository["default_branch"]
      )
      response = perform_request(uri)
      commits = parse_response(response, uri)
      raise ApiError, "commit response for #{repository["full_name"]} was not an array" unless commits.is_a?(Array)
      return 0 if commits.empty?

      last_page = response["link"].to_s.match(/<[^>]+[?&]page=(\d+)[^>]*>;\s*rel="last"/)
      last_page ? last_page[1].to_i : 1
    end

    def request(path, parameters)
      uri = api_uri(path, parameters)
      parse_response(perform_request(uri), uri)
    end

    def api_uri(path, parameters)
      URI("#{API_BASE}#{path}?#{URI.encode_www_form(parameters)}")
    end

    def perform_request(uri)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      request["User-Agent"] = "somaditya-portfolio"
      token = github_token
      request["Authorization"] = "Bearer #{token}" unless token.to_s.empty?

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 10,
        read_timeout: 30
      ) { |http| http.request(request) }

      unless response.is_a?(Net::HTTPSuccess)
        message = begin
          JSON.parse(response.body)["message"]
        rescue JSON::ParserError
          nil
        end
        if response.code == "403" && message.to_s.downcase.include?("rate limit exceeded")
          raise ApiError,
            "GitHub API rate limit exceeded. Authenticate with `gh auth login` or set GITHUB_TOKEN or GH_TOKEN to a GitHub token, then rebuild. If already authenticated, wait for the rate limit to reset."
        end

        detail = message ? ": #{message}" : ""
        raise ApiError, "GitHub API returned HTTP #{response.code} for #{uri.path}#{detail}"
      end

      response
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => error
      raise ApiError, "GitHub API request failed for #{uri.path}: #{error.message}"
    end

    def github_token
      return @github_token if @github_token_loaded

      @github_token_loaded = true
      @github_token = ENV.values_at("GITHUB_TOKEN", "GH_TOKEN").find { |value| !value.to_s.strip.empty? }
      @github_token ||= github_cli_token
    end

    def github_cli_token
      stdout, _stderr, status = Open3.capture3("gh", "auth", "token")
      status.success? ? stdout.strip : nil
    rescue Errno::ENOENT
      nil
    end

    def parse_response(response, uri)
      JSON.parse(response.body)
    rescue JSON::ParserError => error
      raise ApiError, "GitHub API returned invalid JSON for #{uri.path}: #{error.message}"
    end
  end
end
