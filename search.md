---
layout: default
title: Search
description: Search tbarabosch.com articles locally by title, excerpt, expertise topic, or granular tag.
permalink: /search/
---

<main id="main-content" class="main-content" tabindex="-1">
  <section class="manual-section" aria-labelledby="name-heading">
    <p class="manual-label">NAME</p>
    <div class="manual-name">
      <h1 id="name-heading" class="manual-title">search</h1><span class="manual-summary"> - Filter articles by title, excerpt, topic, or tag.</span>
    </div>
  </section>

  <section class="manual-section" aria-labelledby="query-heading">
    <h2 id="query-heading" class="manual-label">QUERY</h2>
    <div class="search-controls">
      <label for="search-input">Search articles</label>
      <input id="search-input" type="search" autocomplete="off" aria-controls="search-results" placeholder="e.g. FreeBSD, YARA, incident response">
      <p id="search-status" class="search-status" aria-live="polite">Showing all {{ site.posts | size }} articles.</p>
    </div>
  </section>

  <section class="manual-section" aria-labelledby="results-heading">
    <h2 id="results-heading" class="manual-label">RESULTS</h2>
    <ol id="search-results" class="article-list search-results">
      {% for post in site.posts %}
        {% capture topic_names %}
          {% for topic in site.data.topics %}
            {% assign topic_match = false %}
            {% for tag in post.tags %}
              {% if topic.tags contains tag %}
                {% assign topic_match = true %}
                {% break %}
              {% endif %}
            {% endfor %}
            {% if topic_match %} {{ topic.name }}{% endif %}
          {% endfor %}
        {% endcapture %}
        {% capture search_text %}{{ post.title }} {{ post.excerpt | strip_html }} {{ post.tags | join: ' ' }} {{ topic_names }}{% endcapture %}
      <li class="article-row search-result" data-search="{{ search_text | normalize_whitespace | downcase | escape }}">
        <time class="article-date" datetime="{{ post.date | date: "%Y-%m-%d" }}">{{ post.date | date: "%Y-%m-%d" }}</time>
        <a class="article-title" href="{{ post.url | relative_url }}" rel="bookmark">{{ post.title }}</a>
      </li>
      {% endfor %}
    </ol>
    <p id="search-empty" class="search-empty" hidden>No articles matched that query.</p>
    <noscript><p class="search-status">JavaScript is disabled; use your browser's find command to search the complete list.</p></noscript>
  </section>
</main>
