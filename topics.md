---
layout: default
title: Topics
description: Browse tbarabosch.com by systems security, reverse engineering, threat research, incident response, and AI engineering.
permalink: /topics/
---

<main id="main-content" class="main-content" tabindex="-1">
  <section class="manual-section" aria-labelledby="name-heading">
    <p class="manual-label">NAME</p>
    <div class="manual-name">
      <h1 id="name-heading" class="manual-title">topics</h1><span class="manual-summary"> - Browse the knowledge base by security discipline.</span>
    </div>
  </section>

  {% assign changed_posts = site.posts | sort: "last_modified_at" | reverse %}
  {% for topic in site.data.topics %}
  <section class="manual-section tag-section" aria-labelledby="{{ topic.slug }}">
    <h2 id="{{ topic.slug }}" class="manual-label">{{ topic.name }}</h2>
    <ol class="article-list compact">
      {% for post in changed_posts %}
        {% assign topic_match = false %}
        {% for tag in post.tags %}
          {% if topic.tags contains tag %}
            {% assign topic_match = true %}
            {% break %}
          {% endif %}
        {% endfor %}
        {% if topic_match %}
          {% assign changed_date = post.last_modified_at | default: post.date | date: "%Y-%m-%d" %}
      <li class="article-row">
        <time class="article-date" datetime="{{ changed_date }}">{{ changed_date }}</time>
        <a class="article-title" href="{{ post.url | relative_url }}" rel="bookmark">{{ post.title }}</a>
      </li>
        {% endif %}
      {% endfor %}
    </ol>
  </section>
  {% endfor %}

  <p class="manual-action"><a href="{{ '/tags/' | relative_url }}">browse all tags -&gt;</a></p>
</main>
