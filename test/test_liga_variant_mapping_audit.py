import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import audit_liga_one_piece_variant_mappings as audit


class LigaVariantMappingAuditTest(unittest.TestCase):
    def test_manga_never_matches_alternate_art(self):
        card = {
            "card_set_id": "EB01-006",
            "card_name": "Tony Tony.Chopper (Alternate Art) (Manga)",
            "set_name": "Extra Booster: Memorial Collection",
            "card_image": "https://catalog.example/EB01-006_p2.jpg",
        }
        rows = [
            {
                "lookup_code": "EB01-006-AA@EB01",
                "card_code": "EB01-006-AA",
                "card_name": "Tony Tony.Chopper (Alternate Art)",
                "edition_code": "EB01",
                "image_url": "https://liga.example/alternate.jpg",
                "minimum_price": 499.99,
            }
        ]

        mapping = audit.build_mapping(card, rows)

        self.assertEqual("missing", mapping["status"])
        self.assertIsNone(mapping["liga_lookup_code"])

    def test_original_edition_resolves_manga_reprint_ambiguity(self):
        card = {
            "card_set_id": "EB01-006",
            "card_name": "Tony Tony.Chopper (Alternate Art) (Manga)",
            "set_name": "Extra Booster: Memorial Collection",
            "card_image": "https://catalog.example/EB01-006_p2.jpg",
        }
        rows = [
            {
                "lookup_code": "EB01-006-MA@EB01",
                "card_code": "EB01-006-MA",
                "card_name": "Tony Tony.Chopper (Alternate Art) (Manga)",
                "edition_code": "EB01",
                "image_url": "https://liga.example/manga-original.jpg",
                "minimum_price": 13000,
            },
            {
                "lookup_code": "EB01-006-MA@PRB",
                "card_code": "EB01-006-MA",
                "card_name": "Tony Tony.Chopper (006) (Manga)",
                "edition_code": "PRB",
                "image_url": "https://liga.example/manga-reprint.jpg",
                "minimum_price": 5700,
            },
        ]

        mapping = audit.build_mapping(card, rows)

        self.assertEqual("confirmed", mapping["status"])
        self.assertEqual("EB01-006-MA@EB01", mapping["liga_lookup_code"])
        self.assertEqual(13000, rows[0]["minimum_price"])

    def test_variant_key_matches_dart_reference_format(self):
        card = {
            "card_set_id": "EB01-006",
            "card_name": "Tony Tony.Chopper (Treasure Cup 2024)",
            "card_image": (
                "https://catalog.example/"
                "Tony_Tony.Chopper_Treasure_Cup_2024_img.jpg"
            ),
        }

        self.assertEqual(
            "EB01-006-TC::IMG::tonytonychoppertreasurecup2024imgjpg",
            audit.variant_key(card),
        )


if __name__ == "__main__":
    unittest.main()
