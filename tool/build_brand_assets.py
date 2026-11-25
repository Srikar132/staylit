"""Derives every Staylit brand asset from the approved flame source image.

Run from the repository root:

    python tool/build_brand_assets.py

Input : designs/brand/flame-source.png          (1024 px flame, smiling face, white background)
        designs/brand/flame-focused-source.png  (same flame, determined face)
        designs/brand/flame-scroll-source.png   (same flame, scowling face, Scroll damage)
Output: designs/brand/*                  masters (not shipped)
        assets/icons/*, assets/splash/*  generator inputs for flutter_launcher_icons / flutter_native_splash
        assets/images/{brand_mark,lit,lit_focused,lit_scroll}.webp   in-app artwork
        android/app/src/main/res/drawable-*dpi/ic_stat_staylit.png   notification icon

Requires Pillow and numpy. Never upscale: all outputs are made from the 1024 px source.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
BRAND = ROOT / "designs" / "brand"
SOURCE_CALM = BRAND / "flame-source.png"
SOURCE_FOCUSED = BRAND / "flame-focused-source.png"
SOURCE_SCROLL = BRAND / "flame-scroll-source.png"  # scowling pose for Scroll damage

WHITE = (255, 255, 255, 255)
PEACH = (245, 189, 164, 255)  # #F5BDA4, the flame's inner fill

# Flame height inside the 1024 px launcher canvas. Android's visible circle is ~66% of
# the canvas (about 680 px); the flame's tip and base sit on its vertical axis, so
# 660 px fills the icon without being clipped by round masks.
ICON_MARK_HEIGHT = 660


def extract_alpha(source: Image.Image) -> Image.Image:
    """Source on white -> RGBA, colours unmixed from white so edges have no halo."""
    a = np.asarray(source.convert("RGB")).astype(float)
    luma = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    # Fully opaque from the lightest fill (peach, luma ~207) down.
    alpha = np.clip((255 - luma) / (255 - 207), 0, 1)
    safe = np.maximum(alpha[..., None], 0.02)
    rgb = np.clip((a - 255 * (1 - alpha[..., None])) / safe, 0, 255)
    rgb[alpha < 0.02] = 0
    return Image.fromarray(np.dstack([rgb, alpha * 255]).astype("uint8"), "RGBA")


def remove_face(rgba: Image.Image) -> Image.Image:
    """Paints the dark eyes and smile over with the peach fill."""
    arr = np.asarray(rgba).copy()
    luma = 0.299 * arr[..., 0] + 0.587 * arr[..., 1] + 0.114 * arr[..., 2]
    dark = (luma < 110) & (arr[..., 3] > 128)
    grown = np.asarray(
        Image.fromarray((dark * 255).astype("uint8")).filter(ImageFilter.MaxFilter(9))
    ) > 0
    arr[grown] = PEACH
    return Image.fromarray(arr, "RGBA")


def silhouette(rgba: Image.Image, color=(255, 255, 255)) -> Image.Image:
    """Solid single-colour version of the whole flame shape."""
    alpha = rgba.getchannel("A")
    out = Image.new("RGBA", rgba.size, color + (0,))
    out.putalpha(alpha)
    return out


def tight(rgba: Image.Image) -> Image.Image:
    box = rgba.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    return rgba.crop(box)


def place(mark: Image.Image, canvas: int, mark_height: int, background=None) -> Image.Image:
    """Centres the tightly cropped mark on a square canvas at the given height."""
    m = tight(mark)
    k = mark_height / m.height
    m = m.resize((max(1, round(m.width * k)), mark_height), Image.LANCZOS)
    base = Image.new("RGBA", (canvas, canvas), background or (0, 0, 0, 0))
    base.alpha_composite(m, ((canvas - m.width) // 2, (canvas - m.height) // 2))
    return base


def save(img: Image.Image, path: Path, **kwargs) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, **kwargs)
    print("wrote", path.relative_to(ROOT))


def main() -> None:
    # Smiling face: launcher icon, splash, welcome, onboarding (the brand face).
    calm = extract_alpha(Image.open(SOURCE_CALM))
    # Determined face: ONLY the active-session and blocked screens.
    focused = extract_alpha(Image.open(SOURCE_FOCUSED))
    faceless = remove_face(calm)
    white = silhouette(calm)

    # Masters (not shipped)
    save(calm, BRAND / "flame-calm-alpha.png")
    save(focused, BRAND / "flame-focused-alpha.png")
    save(faceless, BRAND / "flame-faceless-alpha.png")
    save(white, BRAND / "flame-silhouette-white.png")

    # Launcher icon: the smiling flame on a white tile.
    save(place(calm, 1024, ICON_MARK_HEIGHT, WHITE).convert("RGB"), ROOT / "assets/icons/icon.png")
    save(place(calm, 1024, ICON_MARK_HEIGHT), ROOT / "assets/icons/icon_foreground.png")
    # Themed (monochrome) icon: Android requires a single-colour shape, so no face.
    save(place(white, 1024, ICON_MARK_HEIGHT), ROOT / "assets/icons/icon_monochrome.png")

    # Play Store listing icon
    save(place(calm, 512, ICON_MARK_HEIGHT // 2, WHITE).convert("RGB"), BRAND / "play-store-icon-512.png")

    # Splash: 1152 px canvas, mark inside the 768 px Android 12 circle.
    save(place(calm, 1152, 560), ROOT / "assets/splash/splash_logo.png")

    # In-app artwork
    def webp(rgba: Image.Image, longest: int, name: str) -> None:
        m = tight(rgba)
        k = longest / max(m.size)
        save(
            m.resize((round(m.width * k), round(m.height * k)), Image.LANCZOS),
            ROOT / "assets/images" / name,
            quality=92,
            method=6,
        )

    # The scowling pose: drop faint matte noise so it sits cleanly on dark cards.
    scroll = extract_alpha(Image.open(SOURCE_SCROLL))
    arr = np.array(scroll)
    arr[arr[..., 3] < 18] = 0
    scroll = Image.fromarray(arr, "RGBA")
    webp(scroll, 768, "lit_scroll.webp")

    webp(calm, 512, "brand_mark.webp")  # in-app loading splash
    webp(calm, 768, "lit.webp")  # welcome hero
    webp(focused, 768, "lit_focused.webp")  # active session, blocked overlays ONLY

    # Notification icon: white silhouette (Android requires a single colour).
    for density, px in {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}.items():
        m = tight(white)
        inner = px - max(2, px // 12)
        k = inner / m.height
        m = m.resize((max(1, round(m.width * k)), inner), Image.LANCZOS)
        icon = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        icon.alpha_composite(m, ((px - m.width) // 2, (px - m.height) // 2))
        save(icon, ROOT / f"android/app/src/main/res/drawable-{density}/ic_stat_staylit.png")


if __name__ == "__main__":
    main()
