from __future__ import annotations

from typing import Any


DEMO_VIDEO_URL = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

# Picsum Photos — imágenes libres (CC), seed fijo = imagen consistente entre reinicios.
# Formato: https://picsum.photos/seed/{seed}/{width}/{height}
_IMG = {
    "demo-adventure":   "https://picsum.photos/seed/adventure/400/560",
    "sample-future":    "https://picsum.photos/seed/future/400/560",
    "void-chronicles":  "https://picsum.photos/seed/void/400/560",
    "neon-spirits":     "https://picsum.photos/seed/neon/400/560",
    "crimson-protocol": "https://picsum.photos/seed/crimson/400/560",
    "eternal-bloom":    "https://picsum.photos/seed/bloom/400/560",
}
_BANNER = {
    "demo-adventure":   "https://picsum.photos/seed/adventure-b/800/400",
    "sample-future":    "https://picsum.photos/seed/future-b/800/400",
    "void-chronicles":  "https://picsum.photos/seed/void-b/800/400",
    "neon-spirits":     "https://picsum.photos/seed/neon-b/800/400",
    "crimson-protocol": "https://picsum.photos/seed/crimson-b/800/400",
    "eternal-bloom":    "https://picsum.photos/seed/bloom-b/800/400",
}

_ANIMES: list[dict[str, Any]] = [
    {
        "titulo": "Demo Adventure",
        "url": "demo://anime/demo-adventure",
        "imagen": _IMG["demo-adventure"],
        "tipo": "TV",
        "estado": "En emisión",
    },
    {
        "titulo": "Sample Future",
        "url": "demo://anime/sample-future",
        "imagen": _IMG["sample-future"],
        "tipo": "TV",
        "estado": "Finalizado",
    },
    {
        "titulo": "Void Chronicles",
        "url": "demo://anime/void-chronicles",
        "imagen": _IMG["void-chronicles"],
        "tipo": "TV",
        "estado": "En emisión",
    },
    {
        "titulo": "Neon Spirits",
        "url": "demo://anime/neon-spirits",
        "imagen": _IMG["neon-spirits"],
        "tipo": "TV",
        "estado": "Finalizado",
    },
    {
        "titulo": "Crimson Protocol",
        "url": "demo://anime/crimson-protocol",
        "imagen": _IMG["crimson-protocol"],
        "tipo": "TV",
        "estado": "Finalizado",
    },
    {
        "titulo": "Eternal Bloom",
        "url": "demo://anime/eternal-bloom",
        "imagen": _IMG["eternal-bloom"],
        "tipo": "OVA",
        "estado": "En emisión",
    },
]

_DETAILS: dict[str, dict[str, Any]] = {
    "demo://anime/demo-adventure": {
        "titulo": "Demo Adventure",
        "imagen": _IMG["demo-adventure"],
        "imagen_hd": _IMG["demo-adventure"],
        "banner": _BANNER["demo-adventure"],
        "sinopsis": (
            "Un joven héroe embarca en un viaje épico para salvar su mundo de una "
            "oscuridad ancestral. En el camino descubrirá poderes que ni él mismo "
            "conocía y forjará amistades que durarán toda la vida."
        ),
        "generos": ["Acción", "Aventura", "Fantasía"],
        "tags": ["Acción", "Aventura", "Fantasía", "Poderes"],
        "estado": "En emisión",
        "tipo": "TV",
        "episodios_count": 12,
        "rating": "4.2",
        "proximo": "2026-06-01",
        "relaciones": [
            {
                "titulo": "Void Chronicles",
                "url": "demo://anime/void-chronicles",
                "relacion": "Secuela",
                "imagen": _IMG["void-chronicles"],
            },
        ],
    },
    "demo://anime/sample-future": {
        "titulo": "Sample Future",
        "imagen": _IMG["sample-future"],
        "imagen_hd": _IMG["sample-future"],
        "banner": _BANNER["sample-future"],
        "sinopsis": (
            "En un futuro distante, la humanidad coloniza las estrellas. Una joven "
            "científica descubre una señal alienígena que podría cambiar el curso "
            "de la civilización para siempre."
        ),
        "generos": ["Ciencia Ficción", "Drama", "Misterio"],
        "tags": ["Sci-Fi", "Drama", "Espacio", "Misterio"],
        "estado": "Finalizado",
        "tipo": "TV",
        "episodios_count": 24,
        "rating": "4.7",
        "proximo": "",
        "relaciones": [],
    },
    "demo://anime/void-chronicles": {
        "titulo": "Void Chronicles",
        "imagen": _IMG["void-chronicles"],
        "imagen_hd": _IMG["void-chronicles"],
        "banner": _BANNER["void-chronicles"],
        "sinopsis": (
            "Las crónicas de un mundo donde la magia y la tecnología coexisten en "
            "un frágil equilibrio. Los Guardianes del Vacío deben defender su "
            "realidad de entidades que buscan desgarrar el tejido del universo."
        ),
        "generos": ["Fantasía", "Acción", "Aventura"],
        "tags": ["Fantasía", "Magia", "Acción", "Mundo alternativo"],
        "estado": "En emisión",
        "tipo": "TV",
        "episodios_count": 6,
        "rating": "3.9",
        "proximo": "2026-05-31",
        "relaciones": [
            {
                "titulo": "Demo Adventure",
                "url": "demo://anime/demo-adventure",
                "relacion": "Precuela",
                "imagen": _IMG["demo-adventure"],
            },
        ],
    },
    "demo://anime/neon-spirits": {
        "titulo": "Neon Spirits",
        "imagen": _IMG["neon-spirits"],
        "imagen_hd": _IMG["neon-spirits"],
        "banner": _BANNER["neon-spirits"],
        "sinopsis": (
            "Una historia cotidiana sobre cuatro amigos que viven en la ciudad de "
            "Neon, donde los espíritus conviven con los humanos. Entre risas, "
            "lágrimas y ramen, aprenden que la vida ordinaria es la mayor aventura."
        ),
        "generos": ["Slice of Life", "Drama", "Sobrenatural"],
        "tags": ["Slice of Life", "Comedia", "Espíritus", "Amistad"],
        "estado": "Finalizado",
        "tipo": "TV",
        "episodios_count": 24,
        "rating": "4.5",
        "proximo": "",
        "relaciones": [],
    },
    "demo://anime/crimson-protocol": {
        "titulo": "Crimson Protocol",
        "imagen": _IMG["crimson-protocol"],
        "imagen_hd": _IMG["crimson-protocol"],
        "banner": _BANNER["crimson-protocol"],
        "sinopsis": (
            "En un mundo devastado por la guerra entre naciones mecatrónicas, un "
            "piloto élite recibe la misión más peligrosa de su vida: infiltrarse "
            "en el corazón del enemigo con un mecha experimental cuya IA tiene "
            "sus propias intenciones."
        ),
        "generos": ["Mecha", "Thriller", "Acción"],
        "tags": ["Mecha", "Militar", "Thriller", "Inteligencia Artificial"],
        "estado": "Finalizado",
        "tipo": "TV",
        "episodios_count": 13,
        "rating": "4.1",
        "proximo": "",
        "relaciones": [],
    },
    "demo://anime/eternal-bloom": {
        "titulo": "Eternal Bloom",
        "imagen": _IMG["eternal-bloom"],
        "imagen_hd": _IMG["eternal-bloom"],
        "banner": _BANNER["eternal-bloom"],
        "sinopsis": (
            "Una florista con el don de ver las emociones como colores conoce a un "
            "músico que perdió la capacidad de sentir alegría. Juntos descubren que "
            "el arte puede sanar heridas que la medicina no puede alcanzar."
        ),
        "generos": ["Romance", "Fantasía", "Drama"],
        "tags": ["Romance", "Música", "Poderes", "Sanación"],
        "estado": "En emisión",
        "tipo": "OVA",
        "episodios_count": 8,
        "rating": "4.3",
        "proximo": "2026-06-07",
        "relaciones": [],
    },
}

_ULTIMOS: list[dict[str, Any]] = [
    {"titulo": "Demo Adventure",   "episodio": "12", "url": "demo://episode/demo-adventure-12",   "imagen": _IMG["demo-adventure"]},
    {"titulo": "Void Chronicles",  "episodio": "6",  "url": "demo://episode/void-chronicles-6",  "imagen": _IMG["void-chronicles"]},
    {"titulo": "Eternal Bloom",    "episodio": "8",  "url": "demo://episode/eternal-bloom-8",    "imagen": _IMG["eternal-bloom"]},
    {"titulo": "Sample Future",    "episodio": "24", "url": "demo://episode/sample-future-24",   "imagen": _IMG["sample-future"]},
]


class MockProvider:
    """Proveedor de datos seguro para la versión pública demo."""

    def get_animes(self) -> list[dict[str, Any]]:
        return list(_ANIMES)

    def get_ultimos_episodios(self) -> list[dict[str, Any]]:
        return list(_ULTIMOS)

    def get_en_emision(self) -> list[dict[str, Any]]:
        return [a for a in _ANIMES if a["estado"] == "En emisión"]

    def buscar(self, q: str) -> list[dict[str, Any]]:
        query = q.lower().strip()
        return [a for a in _ANIMES if query in a["titulo"].lower()]

    def get_animes_por_genero(self, genero: str) -> list[dict[str, Any]]:
        g = genero.lower()
        result = []
        for anime in _ANIMES:
            detail = _DETAILS.get(anime["url"], {})
            all_tags = [t.lower() for t in detail.get("generos", []) + detail.get("tags", [])]
            if any(g in tag for tag in all_tags):
                result.append(anime)
        return result or list(_ANIMES)

    def get_anime_detalle(self, url: str) -> dict[str, Any]:
        detail = _DETAILS.get(url)
        if detail:
            return {**detail, "url": url}
        return {
            "titulo": "Demo Anime",
            "url": url,
            "imagen": "https://picsum.photos/seed/default/400/560",
            "imagen_hd": "https://picsum.photos/seed/default/400/560",
            "banner": "",
            "sinopsis": "Contenido demo usado para mostrar arquitectura y telemetría.",
            "generos": ["Demo"],
            "tags": ["Demo"],
            "estado": "Demo",
            "tipo": "TV",
            "episodios_count": 3,
            "rating": "",
            "proximo": "",
            "relaciones": [],
        }

    def get_episodios(self, url: str) -> list[dict[str, Any]]:
        detail = _DETAILS.get(url, {})
        count = detail.get("episodios_count", 3)
        slug = url.split("/")[-1] if "/" in url else "demo"
        return [
            {
                "episodio": str(i),
                "titulo": f"Episodio {i}",
                "url": f"demo://episode/{slug}-{i}",
            }
            for i in range(1, count + 1)
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
