---
layout: default
title: Tags
permalink: /tags/
---

<main id="main-content" class="main-content">
  <section class="manual-section" aria-labelledby="name-heading">
    <p class="manual-label">NAME</p>
    <div class="manual-name">
      <h1 id="name-heading" class="manual-title">tags</h1><span class="manual-summary"> - Browse articles by topic and technology.</span>
    </div>
  </section>

  <section class="manual-section" aria-labelledby="index-heading">
    <h2 id="index-heading" class="manual-label">INDEX</h2>
    <ul class="tag-list tag-index">
      {% for tag_name in site.data.tags %}
      {% assign tag_posts = site.tags[tag_name] %}
      <li>
        <a class="tag-pill" href="#{{ tag_name | slugify }}">{{ tag_name }} ({{ tag_posts | size }})</a>
      </li>
      {% endfor %}
    </ul>
  </section>

  {% for tag_name in site.data.tags %}
  {% assign tag_posts = site.tags[tag_name] | sort: "date" | reverse %}
  <section class="manual-section tag-section" aria-labelledby="{{ tag_name | slugify }}">
    <h2 id="{{ tag_name | slugify }}" class="manual-label">{{ tag_name }}</h2>
    <ol class="article-list compact">
      {% for post in tag_posts %}
      <li class="article-row">
        <time class="article-date" datetime="{{ post.date | date: "%Y-%m-%d" }}">{{ post.date | date: "%Y-%m-%d" }}</time>
        <a class="article-title" href="{{ post.url | relative_url }}" rel="bookmark">{{ post.title }}</a>
      </li>
      {% endfor %}
    </ol>
  </section>
  {% endfor %}
</main><!-- .main-content -->
