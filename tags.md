---
layout: default
title: Tags
permalink: /tags/
---

<main class="main-content">
  <section class="manual-section" aria-labelledby="name-heading">
    <h1 id="name-heading" class="manual-label">NAME</h1>
    <p class="manual-copy"><strong>tags</strong> - Browse articles by topic and technology.</p>
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
