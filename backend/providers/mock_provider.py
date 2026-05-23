from __future__ import annotations

from typing import Any


DEMO_VIDEO_URL = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"


class MockProvider:
    """Proveedor de datos seguro para la versión pública demo."""

    def get_animes(self) -> list[dict[str, Any]]:
        return [
            {
                "titulo": "Demo Adventure",
                "url": "demo://anime/demo-adventure",
                "imagen": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx1-CXtrrkMpJ8Zq.png",
                "tipo": "TV",
                "estado": "Demo",
            },
            {
                "titulo": "Sample Future",
                "url": "demo://anime/sample-future",
                "imagen": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx5114-Dilr312jctdJ.jpg",
                "tipo": "TV",
                "estado": "Demo",
            },
        ]

    def get_ultimos_episodios(self) -> list[dict[str, Any]]:
        return [
            {
                "titulo": "Demo Adventure",
                "episodio": "1",
                "url": "demo://episode/demo-adventure-1",
                "imagen": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx1-CXtrrkMpJ8Zq.png",
            },
            {
                "titulo": "Sample Future",
                "episodio": "1",
                "url": "demo://episode/sample-future-1",
                "imagen": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx5114-Dilr312jctdJ.jpg",
            },
        ]

    def get_en_emision(self) -> list[dict[str, Any]]:
        return self.get_animes()

    def buscar(self, q: str) -> list[dict[str, Any]]:
        query = q.lower().strip()
        return [
            anime for anime in self.get_animes()
            if query in anime["titulo"].lower()
        ] or self.get_animes()

    def get_animes_por_genero(self, genero: str) -> list[dict[str, Any]]:
        return self.get_animes()

    def get_anime_detalle(self, url: str) -> dict[str, Any]:
        return {
            "titulo": "Demo Adventure",
            "url": url,
            "imagen": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx1-CXtrrkMpJ8Zq.png",
            "sinopsis": "Contenido demo usado únicamente para mostrar arquitectura, caché, telemetría y cliente móvil.",
            "generos": ["Demo", "Adventure", "Technology"],
            "estado": "Demo",
            "tipo": "TV",
            "episodios": 3,
        }

    def get_episodios(self, url: str) -> list[dict[str, Any]]:
        return [
            {
                "episodio": str(i),
                "titulo": f"Demo Episode {i}",
                "url": f"demo://episode/demo-adventure-{i}",
            }
            for i in range(1, 4)
        ]

    def get_servidores(self, url: str) -> list[dict[str, Any]]:
        return [
            {
                "servidor": "Demo Video",
                "enlace": "demo://video/big-buck-bunny",
            }
        ]

    def resolver(self, url: str) -> list[dict[str, Any]]:
        return [
            {
                "quality": "demo",
                "url": DEMO_VIDEO_URL,
                "type": "mp4",
                "server": "Demo Video",
            }
        ]


provider = MockProvider()

