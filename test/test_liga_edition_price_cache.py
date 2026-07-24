import json
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import update_liga_edition_price_cache as edition_cache


class LigaEditionPriceCacheTest(unittest.TestCase):
    def test_parses_and_orders_main_and_aux_editions(self):
        payload = {
            "main": [
                {
                    "id": "80",
                    "acronym": "OP-15",
                    "name": "Older",
                    "dtrelease": "2026-04-03 00:00:00",
                },
                {
                    "id": "81",
                    "acronym": "OP-16",
                    "name": "Newest",
                    "dtrelease": "2026-06-12 00:00:00",
                },
            ],
            "aux": {
                "70": [
                    {
                        "id": "79",
                        "acronym": "PRB-02",
                        "name": "Auxiliary",
                        "dtrelease": "2025-07-01 00:00:00",
                    }
                ]
            },
        }
        source = f"<script>let jsonEditions = {json.dumps(payload)};</script>"

        editions = edition_cache.parse_editions_page(source)

        self.assertEqual(
            ["OP-16", "OP-15", "PRB-02"],
            [edition.acronym for edition in editions],
        )
        self.assertEqual("main", editions[0].group)
        self.assertIn("edid%3D81", editions[0].source_url)

    def test_prioritizes_recent_editions_and_shards_the_rest(self):
        editions = [
            edition_cache.LigaEdition(
                index,
                f"SET-{index}",
                "",
                str(100 - index),
                "main",
            )
            for index in range(8)
        ]

        shard_zero = edition_cache.select_editions(
            editions,
            requested=[],
            shard_count=3,
            shard_index=0,
            priority_count=2,
        )
        shard_one = edition_cache.select_editions(
            editions,
            requested=[],
            shard_count=3,
            shard_index=1,
            priority_count=2,
        )

        self.assertEqual(
            ["SET-0", "SET-1", "SET-2", "SET-5"],
            [edition.acronym for edition in shard_zero],
        )
        self.assertEqual(
            ["SET-0", "SET-1", "SET-3", "SET-6"],
            [edition.acronym for edition in shard_one],
        )

    def test_maps_exact_variants_and_prices_to_existing_cache_schema(self):
        edition = edition_cache.LigaEdition(
            81,
            "OP-16",
            "The Time of Battle",
            "2026-06-12 00:00:00",
            "main",
        )
        cards = [
            {
                "sN": "OP16-001",
                "nEN": "Portgas.D.Ace (001) (OP16-001)",
                "sP": "//example.test/base.jpg",
                "precoMenor": "0.19",
                "p1b": "0.95",
                "precoMaior": "5.00",
            },
            {
                "sN": "OP16-001-AA",
                "nEN": "Portgas.D.Ace (Alternate Art) (OP16-001-AA)",
                "sP": "//example.test/alternate.jpg",
                "precoMenor": "168.99",
                "p1b": "279.21",
                "precoMaior": "580.00",
            },
        ]
        source = f"<script>const cardsjson = {json.dumps(cards)};</script>"

        rows = edition_cache.parse_edition_cards_page(
            source,
            edition,
            resolved_at="2026-07-23T12:00:00Z",
        )

        self.assertEqual(
            ["OP16-001", "OP16-001-AA"],
            [row["lookup_code"] for row in rows],
        )
        self.assertEqual(0.19, rows[0]["minimum_price"])
        self.assertEqual(168.99, rows[1]["minimum_price"])
        self.assertEqual(
            "https://example.test/alternate.jpg",
            rows[1]["image_url"],
        )
        self.assertEqual(
            "Portgas.D.Ace (Alternate Art)",
            rows[1]["card_name"],
        )

    def test_recognizes_known_variant_suffixes(self):
        self.assertEqual(
            "OP16-001",
            edition_cache.base_card_code("OP16-001-AA"),
        )
        self.assertEqual(
            "OP16-119",
            edition_cache.base_card_code("OP16-119-MA"),
        )
        self.assertEqual(
            "OP16-001",
            edition_cache.base_card_code("OP16-001"),
        )


if __name__ == "__main__":
    unittest.main()
