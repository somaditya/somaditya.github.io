(() => {
  const grid = document.getElementById("portfolio-projects");
  if (!grid || grid.querySelector(".portfolio-card")) {
    return;
  }

  const status = grid.querySelector("[data-portfolio-status]");
  const username = grid.dataset.githubUser;
  const projectLimit = 9;

  const fetchJson = async (url) => {
    const response = await fetch(url, {
      headers: {
        Accept: "application/vnd.github+json"
      }
    });

    if (!response.ok) {
      throw new Error(`GitHub API returned HTTP ${response.status}`);
    }

    return response;
  };

  const fetchRepositories = async () => {
    const repositories = [];
    let page = 1;
    let currentPage;

    do {
      const response = await fetchJson(
        `https://api.github.com/users/${encodeURIComponent(username)}/repos?type=owner&per_page=100&page=${page}`
      );
      currentPage = await response.json();
      if (!Array.isArray(currentPage)) {
        throw new Error("GitHub API returned an invalid repository list");
      }
      repositories.push(...currentPage);
      page += 1;
    } while (currentPage.length === 100);

    return repositories;
  };

  const fetchCommitCount = async (repository) => {
    if (!repository.default_branch || !repository.owner?.login) {
      return 0;
    }

    const url = new URL(
      `https://api.github.com/repos/${encodeURIComponent(repository.owner.login)}/${encodeURIComponent(repository.name)}/commits`
    );
    url.searchParams.set("per_page", "1");
    url.searchParams.set("sha", repository.default_branch);

    const response = await fetchJson(url);
    const commits = await response.json();
    if (!Array.isArray(commits)) {
      throw new Error(`GitHub API returned invalid commits for ${repository.full_name}`);
    }
    if (commits.length === 0) {
      return 0;
    }

    const lastPage = response.headers
      .get("Link")
      ?.match(/[?&]page=(\d+)[^>]*>;\s*rel="last"/);
    return lastPage ? Number(lastPage[1]) : 1;
  };

  const createElement = (tag, className, text) => {
    const element = document.createElement(tag);
    if (className) {
      element.className = className;
    }
    if (text !== undefined) {
      element.textContent = text;
    }
    return element;
  };

  const createStat = (iconClass, label, value) => {
    const stat = createElement("div");
    const term = createElement("dt");
    const icon = createElement("i", iconClass);
    icon.setAttribute("aria-hidden", "true");
    term.append(icon, ` ${label}`);
    stat.append(term, createElement("dd", "", value.toLocaleString()));
    return stat;
  };

  const createCard = (repository) => {
    const card = createElement("a", "portfolio-card");
    card.href = repository.html_url;
    card.target = "_blank";
    card.rel = "noopener noreferrer";

    const heading = createElement("div", "portfolio-card-heading");
    const iconContainer = createElement("span", "portfolio-repo-icon");
    iconContainer.setAttribute("aria-hidden", "true");
    iconContainer.append(createElement("i", "fab fa-github"));
    heading.append(iconContainer, createElement("h2", "", repository.name));

    const arrow = createElement("span", "portfolio-card-arrow");
    arrow.setAttribute("aria-hidden", "true");
    arrow.append(createElement("i", "fas fa-arrow-up-right-from-square"));
    heading.append(arrow);
    card.append(heading);

    card.append(
      createElement(
        "p",
        "portfolio-description",
        repository.description || "No description provided."
      )
    );

    if (repository.language) {
      card.append(createElement("span", "portfolio-language", repository.language));
    }

    const stats = createElement("dl", "portfolio-stats");
    stats.append(
      createStat("fas fa-star", "Stars", repository.stargazers_count || 0),
      createStat("fas fa-code-fork", "Forks", repository.forks_count || 0),
      createStat("fas fa-code-commit", "Commits", repository.commits_count || 0)
    );
    card.append(stats);
    return card;
  };

  const loadPortfolio = async () => {
    if (!username) {
      throw new Error("GitHub username is not configured");
    }

    const repositories = await fetchRepositories();
    const projects = await Promise.all(
      repositories.map(async (repository) => ({
        ...repository,
        commits_count: await fetchCommitCount(repository)
      }))
    );
    projects.sort(
      (left, right) =>
        right.commits_count - left.commits_count ||
        right.stargazers_count - left.stargazers_count ||
        left.name.localeCompare(right.name)
    );

    const fragment = document.createDocumentFragment();
    projects.slice(0, projectLimit).forEach((project) => {
      fragment.append(createCard(project));
    });

    if (projects.length === 0) {
      status.textContent = "No public projects were found.";
      return;
    }

    status.remove();
    grid.append(fragment);
  };

  loadPortfolio().catch((error) => {
    console.error("Unable to load GitHub portfolio:", error);
    status.textContent = "GitHub project data could not be loaded. Please try again later.";
  });
})();
