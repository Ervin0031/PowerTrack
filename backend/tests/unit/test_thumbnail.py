"""缩略图生成:尺寸上限、格式、宽高比、不放大小图。"""

import io

from PIL import Image

from app.services.storage import StorageService


def _image_bytes(width: int, height: int) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (width, height), "red").save(buf, format="PNG")
    return buf.getvalue()


def test_thumbnail_downscaled_to_jpeg():
    source = _image_bytes(2816, 1536)
    thumb = StorageService.generate_thumbnail(source)
    with Image.open(io.BytesIO(thumb)) as img:
        assert img.format == "JPEG"
        assert max(img.size) == 512
        assert abs(img.size[0] / img.size[1] - 2816 / 1536) < 0.01


def test_thumbnail_does_not_upscale_small_images():
    source = _image_bytes(100, 80)
    thumb = StorageService.generate_thumbnail(source)
    with Image.open(io.BytesIO(thumb)) as img:
        assert img.size == (100, 80)
