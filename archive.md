---
layout: default
title: Archive
description: Every tbarabosch.com security and engineering article grouped by original publication year.
permalink: /archive/
---

<main id="main-content" class="main-content" tabindex="-1">
  <section class="manual-section" aria-labelledby="name-heading">
    <p class="manual-label">NAME</p>
    <div class="manual-name">
      <h1 id="name-heading" class="manual-title">archive</h1><span class="manual-summary"> - Every article by original publication date.</span>
    </div>
  </section>

  {% assign posts_by_year = site.posts | group_by_exp: "post", "post.date | date: '%Y'" %}
  {% for year in posts_by_year %}
  <section class="manual-section" aria-labelledby="year-{{ year.name }}">
    <h2 id="year-{{ year.name }}" class="manual-label">{{ year.name }}</h2>
    <ol class="article-list compact">
      {% for post in year.items %}
      <li class="article-row">
        <time class="article-date" datetime="{{ post.date | date: "%Y-%m-%d" }}">{{ post.date | date: "%Y-%m-%d" }}</time>
        <a class="article-title" href="{{ post.url | relative_url }}" rel="bookmark">{{ post.title }}</a>
      </li>
      {% endfor %}
    </ol>
  </section>
  {% endfor %}
</main>
