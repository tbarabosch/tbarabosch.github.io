(function () {
  "use strict";

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }

    return new Promise(function (resolve, reject) {
      var textarea = document.createElement("textarea");
      textarea.value = text;
      textarea.setAttribute("readonly", "");
      textarea.style.position = "fixed";
      textarea.style.opacity = "0";
      document.body.appendChild(textarea);
      textarea.select();
      try {
        document.execCommand("copy") ? resolve() : reject(new Error("Copy failed"));
      } catch (error) {
        reject(error);
      } finally {
        textarea.remove();
      }
    });
  }

  document.querySelectorAll(".post-content div.highlighter-rouge").forEach(function (wrapper) {
    var pre = wrapper.querySelector("pre");
    var code = wrapper.querySelector("pre code");
    if (!pre || !code) return;

    pre.tabIndex = 0;
    var button = document.createElement("button");
    button.type = "button";
    button.className = "code-copy";
    button.textContent = "copy";
    button.setAttribute("aria-label", "Copy code block");
    button.addEventListener("click", function () {
      copyText(code.textContent).then(function () {
        button.textContent = "copied";
        window.setTimeout(function () { button.textContent = "copy"; }, 1800);
      }).catch(function () {
        button.textContent = "select text";
      });
    });
    wrapper.appendChild(button);
  });

  document.querySelectorAll(".post-content h2[id], .post-content h3[id]").forEach(function (heading) {
    var permalink = document.createElement("a");
    permalink.className = "heading-permalink";
    permalink.href = "#" + heading.id;
    permalink.textContent = "#";
    permalink.setAttribute("aria-label", "Permanent link to " + heading.textContent.trim());
    heading.appendChild(document.createTextNode(" "));
    heading.appendChild(permalink);
  });

  document.querySelectorAll(".post-content img").forEach(function (img) {
    if (img.closest("a") || !img.getAttribute("alt")) return;
    var src = img.getAttribute("src") || "";
    if (src.indexOf("/") !== 0 && src.indexOf(window.location.origin) !== 0) return;
    var link = document.createElement("a");
    link.className = "full-image-link";
    link.href = img.src;
    link.setAttribute("aria-label", "Open full-resolution image: " + img.alt);
    img.parentNode.insertBefore(link, img);
    link.appendChild(img);
  });

  var searchInput = document.getElementById("search-input");
  if (searchInput) {
    var searchRows = Array.prototype.slice.call(document.querySelectorAll(".search-result"));
    var searchStatus = document.getElementById("search-status");
    var searchEmpty = document.getElementById("search-empty");
    var initialQuery = new URLSearchParams(window.location.search).get("q") || "";

    function applySearch() {
      var query = searchInput.value.trim().toLocaleLowerCase();
      var terms = query.split(/\s+/).filter(Boolean);
      var visible = 0;
      searchRows.forEach(function (row) {
        var haystack = row.getAttribute("data-search") || "";
        var matches = terms.every(function (term) { return haystack.indexOf(term) !== -1; });
        row.hidden = !matches;
        if (matches) visible += 1;
      });
      searchStatus.textContent = query ? visible + " matching article" + (visible === 1 ? "." : "s.") : "Showing all " + visible + " articles.";
      searchEmpty.hidden = visible !== 0;
      var url = new URL(window.location.href);
      query ? url.searchParams.set("q", query) : url.searchParams.delete("q");
      window.history.replaceState(null, "", url.pathname + url.search + url.hash);
    }

    searchInput.value = initialQuery;
    searchInput.addEventListener("input", applySearch);
    applySearch();
  }
}());
