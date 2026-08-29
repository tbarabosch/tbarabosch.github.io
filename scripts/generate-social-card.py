#!/usr/bin/env python3
"""Generate a deterministic social card from a Jekyll post."""

from __future__ import annotations

from argparse import ArgumentParser
from dataclasses import dataclass
from hashlib import sha256
from io import BytesIO
import os
from pathlib import Path, PurePosixPath
import re
import sys
import tempfile

try:
    from PIL import Image, ImageDraw, ImageFont
    import yaml
except ModuleNotFoundError as error:
    raise SystemExit(
        "missing artwork dependency; install wheel-only requirements with "
        "'.venv-social-card/bin/python -m pip install --only-binary=:all: "
        "-r scripts/requirements-social-card.txt'"
    ) from error


WIDTH = 1200
HEIGHT = 630
SCALE = 2

PAPER = "#f3eedf"
INK = "#151515"
MUTED = "#5f5f5f"
RULE = "#b9b6ab"
CODE_BG = "#eeece4"
OVERLAY_BG = "#e4d6cf"
ACCENT = "#7a2e2e"

BRAND = "THOMAS BARABOSCH(7)"
DOMAIN = "tbarabosch.com"

MONO_PATH = Path("/System/Library/Fonts/SFNSMono.ttf")
GEORGIA_PATH = Path("/System/Library/Fonts/Supplemental/Georgia.ttf")
GEORGIA_ITALIC_PATH = Path(
    "/System/Library/Fonts/Supplemental/Georgia Italic.ttf"
)

ROOT = Path(__file__).resolve().parents[1]
POSTS = ROOT / "_posts"
POST_NAME = re.compile(r"^\d{4}-\d{2}-\d{2}-(?P<slug>.+)\.md$")
FRONT_MATTER = re.compile(r"\A---\s*\r?\n(?P<yaml>.*?)\r?\n---\s*\r?\n", re.S)
FENCED_BLOCK = re.compile(
    r"^(?P<fence>`{3,}|~{3,})[ \t]*(?P<info>[^\r\n]*)\r?\n"
    r"(?P<content>.*?)^(?P=fence)[ \t]*$",
    re.M | re.S,
)


class CardError(Exception):
    """The post cannot be rendered safely as a social card."""


@dataclass(frozen=True)
class Card:
    post_path: Path
    output_path: Path
    title: str
    subtitle: str
    eyebrow: str
    footer_topic: str
    layout: str
    content: str
    panel_label: str
    highlight: str | None = None
    accent: str | None = None


def px(value: float) -> int:
    """Scale a CSS-like pixel value for supersampled drawing."""
    return round(value * SCALE)


def require_mapping(value: object, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise CardError(f"{label} must be a mapping")
    return value


def require_string(mapping: dict[str, object], key: str, label: str) -> str:
    value = mapping.get(key)
    if not isinstance(value, str) or not value.strip():
        raise CardError(f"{label}.{key} must be a nonempty string")
    return value.strip()


def optional_string(mapping: dict[str, object], key: str, label: str) -> str | None:
    value = mapping.get(key)
    if value is None:
        return None
    if not isinstance(value, str) or not value.strip():
        raise CardError(f"{label}.{key} must be a nonempty string when present")
    return value.strip()


def load_font(
    path: Path, size: float, variation: str | None = None
) -> ImageFont.FreeTypeFont:
    if not path.is_file():
        raise CardError(
            f"required macOS font is missing: {path}; generate cards on macOS "
            "with SF Mono and Georgia installed"
        )
    try:
        face = ImageFont.truetype(str(path), px(size))
        if variation is not None:
            face.set_variation_by_name(variation)
        return face
    except OSError as error:
        raise CardError(f"cannot load font {path}: {error}") from error


def parse_front_matter(post_path: Path) -> tuple[dict[str, object], str]:
    try:
        source = post_path.read_text(encoding="utf-8")
    except OSError as error:
        raise CardError(f"cannot read post: {error}") from error

    match = FRONT_MATTER.match(source)
    if match is None:
        raise CardError("post is missing YAML front matter")
    try:
        data = yaml.safe_load(match.group("yaml"))
    except yaml.YAMLError as error:
        raise CardError(f"invalid YAML front matter: {error}") from error
    if not isinstance(data, dict):
        raise CardError("front matter must contain a mapping")
    return data, source[match.end() :]


def extract_fence(body: str, language: str, occurrence: int) -> str:
    matches: list[str] = []
    for match in FENCED_BLOCK.finditer(body):
        info = match.group("info").strip()
        fence_language = info.split(maxsplit=1)[0].lower() if info else ""
        if fence_language == language.lower():
            matches.append(match.group("content"))

    if len(matches) < occurrence:
        raise CardError(
            f"post contains {len(matches)} {language!r} fence(s); "
            f"social_card.source.occurrence requests {occurrence}"
        )
    content = matches[occurrence - 1]
    if not content.strip():
        raise CardError("selected fenced block is empty")
    if "\t" in content:
        raise CardError("selected fenced block contains tabs; use spaces for stable rendering")
    return content


def validate_match(content: str, needle: str | None, label: str) -> None:
    if needle is None:
        return
    count = content.count(needle)
    if count != 1:
        raise CardError(f"social_card.{label} must match exactly once; found {count}")
    if "\n" in needle or "\r" in needle:
        raise CardError(f"social_card.{label} must remain on one line")


def output_path(image: dict[str, object], slug: str) -> Path:
    raw_path = require_string(image, "path", "image")
    if image.get("width") != WIDTH or image.get("height") != HEIGHT:
        raise CardError(f"image dimensions must be {WIDTH}x{HEIGHT}")
    if not raw_path.startswith("/"):
        raise CardError("image.path must be an absolute site path")

    posix_path = PurePosixPath(raw_path)
    expected_parent = PurePosixPath("/assets/images/posts") / slug
    if posix_path.parent != expected_parent or posix_path.suffix.lower() != ".png":
        raise CardError(
            "image.path must be a PNG directly under "
            f"/assets/images/posts/{slug}/"
        )
    if ".." in posix_path.parts:
        raise CardError("image.path must not contain parent traversal")

    candidate = (ROOT / raw_path.removeprefix("/")).resolve(strict=False)
    expected_directory = (ROOT / str(expected_parent).removeprefix("/")).resolve(
        strict=False
    )
    try:
        expected_directory.relative_to(ROOT.resolve())
    except ValueError as error:
        raise CardError("image.path resolves outside the repository") from error
    if candidate.parent != expected_directory:
        raise CardError("image.path resolves outside the post asset directory")
    return candidate


def load_card(raw_post_path: Path) -> Card:
    try:
        post_path = raw_post_path.resolve(strict=True)
    except OSError as error:
        raise CardError(f"cannot resolve post path: {error}") from error
    if not post_path.is_file() or post_path.suffix != ".md":
        raise CardError("post must be a Markdown file")
    try:
        post_path.relative_to(POSTS)
    except ValueError as error:
        raise CardError("post must live under _posts/") from error

    name_match = POST_NAME.match(post_path.name)
    if name_match is None:
        raise CardError("post filename must use YYYY-MM-DD-post-slug.md")
    slug = name_match.group("slug")

    data, body = parse_front_matter(post_path)
    title = require_string(data, "title", "front matter")
    tags = data.get("tags")
    if not isinstance(tags, list) or not tags or not all(
        isinstance(tag, str) and tag.strip() for tag in tags
    ):
        raise CardError("front matter.tags must be a nonempty string list")

    image = require_mapping(data.get("image"), "image")
    social = require_mapping(data.get("social_card"), "social_card")
    layout = require_string(social, "layout", "social_card").lower()
    if layout not in {"ascii", "text"}:
        raise CardError("social_card.layout must be 'ascii' or 'text'")

    subtitle = require_string(social, "subtitle", "social_card")
    eyebrow = require_string(social, "eyebrow", "social_card")
    target = output_path(image, slug)

    if layout == "ascii":
        panel_label = require_string(social, "panel_label", "social_card")
        source = require_mapping(social.get("source"), "social_card.source")
        language = require_string(source, "language", "social_card.source")
        occurrence = source.get("occurrence")
        if type(occurrence) is not int or occurrence < 1:
            raise CardError("social_card.source.occurrence must be a positive integer")
        content = extract_fence(body, language, occurrence)
        highlight = optional_string(social, "highlight", "social_card")
        accent = optional_string(social, "accent", "social_card")
        validate_match(content, highlight, "highlight")
        validate_match(content, accent, "accent")
    else:
        forbidden = [
            key
            for key in ("source", "highlight", "accent")
            if key in social
        ]
        if forbidden:
            raise CardError(
                "text layout does not accept: " + ", ".join(sorted(forbidden))
            )
        panel_label = optional_string(social, "panel_label", "social_card") or "TEXT"
        content = require_string(social, "text", "social_card")
        highlight = None
        accent = None

    return Card(
        post_path=post_path,
        output_path=target,
        title=title,
        subtitle=subtitle,
        eyebrow=eyebrow,
        footer_topic=tags[0],
        layout=layout,
        content=content,
        panel_label=panel_label,
        highlight=highlight,
        accent=accent,
    )


def fit_single_line(
    draw: ImageDraw.ImageDraw,
    text: str,
    path: Path,
    maximum: int,
    minimum: int,
    max_width: int,
    variation: str | None = None,
) -> ImageFont.FreeTypeFont:
    for size in range(maximum, minimum - 1, -1):
        face = load_font(path, size, variation)
        if draw.textlength(text, font=face) <= max_width:
            return face
    raise CardError(f"text is too long to render readably: {text!r}")


def fit_title(
    draw: ImageDraw.ImageDraw, title: str, max_width: int
) -> tuple[list[str], ImageFont.FreeTypeFont, int]:
    words = title.upper().split()
    if not words:
        raise CardError("title contains no renderable words")

    for size in range(52, 37, -1):
        face = load_font(MONO_PATH, size, "Bold")
        full = " ".join(words)
        if draw.textlength(full, font=face) <= max_width:
            return [full], face, px(size * 1.16)

        candidates: list[tuple[float, list[str]]] = []
        for split in range(1, len(words)):
            lines = [" ".join(words[:split]), " ".join(words[split:])]
            widths = [draw.textlength(line, font=face) for line in lines]
            if max(widths) <= max_width:
                candidates.append((abs(widths[0] - widths[1]), lines))
        if candidates:
            _, lines = min(candidates, key=lambda item: item[0])
            return lines, face, px(size * 1.16)

    raise CardError("title is too long to fit in two readable lines")


def wrap_words(
    draw: ImageDraw.ImageDraw,
    text: str,
    face: ImageFont.FreeTypeFont,
    max_width: int,
) -> list[str] | None:
    wrapped: list[str] = []
    for source_line in text.splitlines() or [text]:
        if not source_line.strip():
            wrapped.append("")
            continue
        current = ""
        for word in source_line.split():
            candidate = word if not current else f"{current} {word}"
            if draw.textlength(candidate, font=face) <= max_width:
                current = candidate
            elif current and draw.textlength(word, font=face) <= max_width:
                wrapped.append(current)
                current = word
            else:
                return None
        wrapped.append(current)
    return wrapped


def draw_segmented_line(
    draw: ImageDraw.ImageDraw,
    position: tuple[int, int],
    line: str,
    face: ImageFont.FreeTypeFont,
    accent: str | None,
) -> None:
    x, y = position
    if accent is None or accent not in line:
        draw.text((x, y), line, font=face, fill=INK)
        return
    before, after = line.split(accent, 1)
    draw.text((x, y), before, font=face, fill=INK)
    accent_x = x + round(draw.textlength(before, font=face))
    draw.text((accent_x, y), accent, font=face, fill=ACCENT)
    after_x = accent_x + round(draw.textlength(accent, font=face))
    draw.text((after_x, y), after, font=face, fill=INK)


def draw_panel_label(
    draw: ImageDraw.ImageDraw, label: str, face: ImageFont.FreeTypeFont
) -> None:
    display = f"[ {label.upper()} ]"
    label_x = px(87)
    label_y = px(298)
    width = draw.textlength(display, font=face)
    if width > px(700):
        raise CardError("social_card.panel_label is too long")
    draw.rectangle(
        (
            label_x - px(8),
            label_y - px(1),
            label_x + width + px(8),
            label_y + px(23),
        ),
        fill=PAPER,
    )
    draw.text((label_x, label_y), display, font=face, fill=MUTED)


def draw_ascii_panel(draw: ImageDraw.ImageDraw, card: Card) -> None:
    panel = (px(64), px(310), px(1136), px(560))
    draw.rectangle(panel, fill=CODE_BG, outline=RULE, width=px(1))
    draw_panel_label(draw, card.panel_label, load_font(MONO_PATH, 17))

    lines = card.content.splitlines()
    content_left = px(100)
    content_right = px(1100)
    content_top = px(331)
    content_bottom = px(548)
    face = None
    line_height = 0
    for size in range(28, 17, -1):
        candidate = load_font(MONO_PATH, size)
        candidate_height = px(size * 1.28)
        widest = max(draw.textlength(line, font=candidate) for line in lines)
        if (
            widest <= content_right - content_left
            and candidate_height * len(lines) <= content_bottom - content_top
        ):
            face = candidate
            line_height = candidate_height
            break
    if face is None:
        raise CardError("selected ASCII fence is too large to render readably")

    block_height = line_height * len(lines)
    start_y = content_top + (content_bottom - content_top - block_height) // 2

    if card.highlight is not None:
        for index, line in enumerate(lines):
            if card.highlight not in line:
                continue
            start = line.index(card.highlight)
            highlight_x = content_left + round(
                draw.textlength(line[:start], font=face)
            )
            highlight_width = round(draw.textlength(card.highlight, font=face))
            draw.rectangle(
                (
                    highlight_x - px(5),
                    start_y + line_height * index + px(1),
                    highlight_x + highlight_width + px(5),
                    start_y + line_height * (index + 1) - px(3),
                ),
                fill=OVERLAY_BG,
            )

    for index, line in enumerate(lines):
        draw_segmented_line(
            draw,
            (content_left, start_y + line_height * index),
            line,
            face,
            card.accent,
        )


def draw_text_panel(draw: ImageDraw.ImageDraw, card: Card) -> None:
    panel = (px(64), px(310), px(1136), px(560))
    draw.rectangle(panel, fill=CODE_BG, outline=RULE, width=px(1))
    draw_panel_label(draw, card.panel_label, load_font(MONO_PATH, 17))

    content_left = px(126)
    content_right = px(1095)
    content_top = px(342)
    content_bottom = px(540)
    face = None
    lines = None
    line_height = 0
    for size in range(40, 25, -1):
        candidate = load_font(GEORGIA_PATH, size)
        candidate_lines = wrap_words(
            draw, card.content, candidate, content_right - content_left
        )
        candidate_height = px(size * 1.28)
        if (
            candidate_lines is not None
            and len(candidate_lines) <= 5
            and candidate_height * len(candidate_lines)
            <= content_bottom - content_top
        ):
            face = candidate
            lines = candidate_lines
            line_height = candidate_height
            break
    if face is None or lines is None:
        raise CardError("social_card.text is too long to render readably")

    block_height = line_height * len(lines)
    start_y = content_top + (content_bottom - content_top - block_height) // 2
    draw.rectangle(
        (px(98), start_y, px(103), start_y + block_height - px(5)),
        fill=ACCENT,
    )
    for index, line in enumerate(lines):
        draw.text(
            (content_left, start_y + line_height * index),
            line,
            font=face,
            fill=INK,
        )


def render(card: Card) -> bytes:
    canvas = Image.new("RGB", (px(WIDTH), px(HEIGHT)), PAPER)
    draw = ImageDraw.Draw(canvas)
    margin = px(64)

    brand_face = load_font(MONO_PATH, 20, "Bold")
    meta_face = load_font(MONO_PATH, 17)
    draw.text((margin, px(39)), BRAND, font=brand_face, fill=INK)

    eyebrow = card.eyebrow.upper()
    eyebrow_face = fit_single_line(
        draw, eyebrow, MONO_PATH, 17, 13, px(650)
    )
    eyebrow_width = draw.textlength(eyebrow, font=eyebrow_face)
    draw.text(
        (px(WIDTH - 64) - eyebrow_width, px(42)),
        eyebrow,
        font=eyebrow_face,
        fill=MUTED,
    )
    draw.line((margin, px(80), px(WIDTH - 64), px(80)), fill=RULE, width=px(1))

    title_lines, title_face, title_line_height = fit_title(
        draw, card.title, px(WIDTH - 128)
    )
    title_y = px(105)
    for index, line in enumerate(title_lines):
        draw.text(
            (margin, title_y + title_line_height * index),
            line,
            font=title_face,
            fill=INK,
        )

    subtitle_y = title_y + title_line_height * len(title_lines) + px(12)
    subtitle_face = fit_single_line(
        draw,
        card.subtitle,
        GEORGIA_ITALIC_PATH,
        27,
        20,
        px(WIDTH - 128),
    )
    if subtitle_y + px(34) > px(294):
        raise CardError("title and subtitle exceed the available heading area")
    draw.text(
        (margin, subtitle_y), card.subtitle, font=subtitle_face, fill=MUTED
    )

    if card.layout == "ascii":
        draw_ascii_panel(draw, card)
    else:
        draw_text_panel(draw, card)

    draw.line(
        (margin, px(586), px(WIDTH - 64), px(586)), fill=RULE, width=px(1)
    )
    draw.text((margin, px(599)), DOMAIN, font=meta_face, fill=MUTED)
    footer = f"[ {card.footer_topic.upper()} ]"
    footer_face = fit_single_line(draw, footer, MONO_PATH, 17, 13, px(500))
    footer_width = draw.textlength(footer, font=footer_face)
    draw.text(
        (px(WIDTH - 64) - footer_width, px(599)),
        footer,
        font=footer_face,
        fill=MUTED,
    )

    output = canvas.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
    buffer = BytesIO()
    output.save(buffer, format="PNG", optimize=True, compress_level=9)
    return buffer.getvalue()


def write_atomic(path: Path, data: bytes) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
        )
        try:
            with os.fdopen(descriptor, "wb") as output:
                output.write(data)
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary_name, path)
        except BaseException:
            Path(temporary_name).unlink(missing_ok=True)
            raise
    except OSError as error:
        raise CardError(f"cannot write {path}: {error}") from error


def build_parser() -> ArgumentParser:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("post", type=Path, help="Jekyll post with social_card metadata")
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail without writing when the generated PNG is missing or stale",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        card = load_card(args.post)
        data = render(card)
        digest = sha256(data).hexdigest()
        relative_output = card.output_path.relative_to(ROOT)
        if args.check:
            try:
                current = card.output_path.read_bytes()
            except FileNotFoundError as error:
                raise CardError(f"social card is missing: {relative_output}") from error
            except OSError as error:
                raise CardError(f"cannot read social card: {error}") from error
            if current != data:
                raise CardError(f"social card is stale: {relative_output}")
            print(f"up to date: {relative_output} (sha256={digest})")
            return 0

        write_atomic(card.output_path, data)
        print(f"wrote: {relative_output} (sha256={digest})")
        return 0
    except CardError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
