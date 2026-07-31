import json
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import update_liga_edition_price_cache as edition_cache


class LigaEditionPriceCacheTest(unittest.TestCase):
    def test_normalizes_liga_repository_image_urls(self):
        self.assertEqual(
            (
                "https://repositorio.sbrauble.com/arquivos/in/onepiece/"
                "2/card.jpg"
            ),
            edition_cache.liga.normalize_asset_url(
                "//arquivos/in/onepiece/2/card.jpg"
            ),
        )

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
            [
                "OP16-001",
                "OP16-001@OP-16",
                "OP16-001-AA",
                "OP16-001-AA@OP-16",
            ],
            [row["lookup_code"] for row in rows],
        )
        self.assertEqual(0.19, rows[0]["minimum_price"])
        self.assertEqual(168.99, rows[2]["minimum_price"])
        self.assertEqual(
            "https://example.test/alternate.jpg",
            rows[2]["image_url"],
        )
        self.assertEqual(
            "Portgas.D.Ace (Alternate Art)",
            rows[2]["card_name"],
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

    def test_upsert_consolidates_duplicate_codes_and_keeps_newest_edition(self):
        rows = [
            {
                "lookup_code": "OP01-001",
                "edition_code": "NEWEST",
                "minimum_price": 10,
            },
            {
                "lookup_code": "op01-001",
                "edition_code": "OLDER",
                "minimum_price": 8,
            },
            {
                "lookup_code": "OP01-002",
                "edition_code": "OLDER",
                "minimum_price": 5,
            },
        ]

        with mock.patch.object(
            edition_cache.liga,
            "upsert_supabase_rows",
        ) as upsert:
            written = edition_cache.upsert_rows(rows, batch_size=2)

        self.assertEqual(2, written)
        upsert.assert_called_once()
        batch = upsert.call_args.args[0]
        self.assertEqual(["OP01-001", "OP01-002"], [
            row["lookup_code"] for row in batch
        ])
        self.assertEqual("NEWEST", batch[0]["edition_code"])

    def test_keeps_verified_card_without_public_offer(self):
        edition = edition_cache.LigaEdition(
            81,
            "OP-16",
            "The Time of Battle",
            "2026-06-12 00:00:00",
            "main",
        )
        source = (
            "<script>const cardsjson = "
            + json.dumps(
                [
                    {
                        "sN": "OP16-099",
                        "nEN": "Verified without offer (OP16-099)",
                        "sP": "//example.test/no-offer.jpg",
                        "precoMenor": "0",
                    }
                ]
            )
            + ";</script>"
        )

        rows = edition_cache.parse_edition_cards_page(
            source,
            edition,
            resolved_at="2026-07-23T12:00:00Z",
        )

        self.assertEqual(2, len(rows))
        self.assertEqual("OP16-099", rows[0]["lookup_code"])
        self.assertEqual("OP16-099@OP-16", rows[1]["lookup_code"])
        self.assertIsNone(rows[0]["minimum_price"])
        self.assertEqual(
            "2026-07-23T12:00:00Z",
            rows[0]["resolved_at"],
        )

    def test_auxiliary_editions_use_a_distinct_storage_key(self):
        edition = edition_cache.LigaEdition(
            80,
            "OP-15-RE",
            "Adventure on Kami's Island Release Event Cards",
            "2026-03-27 00:00:00",
            "aux",
        )
        source = (
            '<script>const cardsjson = [{"sN":"OP15-001",'
            '"nPT":"Monkey.D.Luffy","precoMenor":"12,50"}];</script>'
        )

        rows = edition_cache.parse_edition_cards_page(
            source,
            edition,
            resolved_at="2026-07-24T12:00:00Z",
        )

        self.assertEqual("OP15-001@OP-15-RE", rows[0]["lookup_code"])
        self.assertEqual("OP15-001", rows[0]["card_code"])

    def test_main_and_auxiliary_versions_survive_the_same_upsert(self):
        rows = [
            {
                "lookup_code": "OP15-001",
                "card_code": "OP15-001",
                "edition_code": "OP-15",
            },
            {
                "lookup_code": "OP15-001@OP-15-RE",
                "card_code": "OP15-001",
                "edition_code": "OP-15-RE",
            },
        ]

        with mock.patch.object(
            edition_cache.liga,
            "upsert_supabase_rows",
        ) as upsert:
            written = edition_cache.upsert_rows(rows)

        self.assertEqual(2, written)
        stored = upsert.call_args.args[0]
        self.assertEqual(
            ["OP15-001", "OP15-001@OP-15-RE"],
            [row["lookup_code"] for row in stored],
        )

    def test_uses_versioned_catalog_for_requested_edition(self):
        payload = [
            {
                "edition_id": 81,
                "acronym": "OP-16",
                "name": "The Time of Battle",
                "release_date": "2026-06-12 00:00:00",
                "group": "main",
            }
        ]
        with TemporaryDirectory() as directory:
            path = Path(directory) / "editions.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            with mock.patch.object(
                edition_cache.liga,
                "fetch_text",
                side_effect=AssertionError("remote catalog should not be read"),
            ):
                editions, source, request_attempted = (
                    edition_cache.discover_editions(
                        ["OP-16"],
                        fallback_path=path,
                    )
                )

        self.assertEqual("catalogo local versionado", source)
        self.assertFalse(request_attempted)
        self.assertEqual(["OP-16"], [edition.acronym for edition in editions])


if __name__ == "__main__":
    unittest.main()
