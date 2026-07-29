import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import update_liga_tcg_price_cache as updater


class LigaTcgPriceCacheTest(unittest.TestCase):
    def test_lookup_codes_are_namespaced(self):
        self.assertEqual(
            updater.build_lookup_code("pokemon", "PBL", "001"),
            "POKEMON:PBL:1",
        )
        self.assertEqual(
            updater.build_lookup_code("digimon", "EX12", "EX12-001"),
            "DIGIMON:EX12-001",
        )
        self.assertEqual(
            updater.build_lookup_code("magic", "FIN", "065"),
            "MAGIC:FIN:65",
        )

    def test_pokemon_edition_card_maps_prices(self):
        edition = updater.LigaTcgEdition(
            game="pokemon",
            edition_id=792,
            acronym="PBL",
            name="Pitch Black",
            release_date="2026-07-17 00:00:00",
            group="main",
        )
        source = """
        <script>
        cardsjson = [{
          "sN":"001",
          "nPT":"Tropius",
          "precoMenor":"0.15",
          "p1b":"0.56",
          "precoMaior":"4.90",
          "sP":"//example.test/card.jpg"
        }];
        </script>
        """

        rows = updater.parse_edition_cards_page(
            source,
            edition,
            resolved_at="2026-07-28T13:00:00Z",
        )

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["lookup_code"], "POKEMON:PBL:1")
        self.assertEqual(rows[0]["minimum_price"], 0.15)
        self.assertEqual(rows[0]["maximum_price"], 4.9)

    def test_zero_price_is_treated_as_no_available_offer(self):
        self.assertIsNone(updater.safe_price("0"))
        self.assertIsNone(updater.safe_price("R$ 0,00"))
        self.assertEqual(updater.safe_price("1,25"), 1.25)

    def test_future_edition_can_be_explicitly_included(self):
        source = """
        <script>
        jsonEditions = {
          "main": [{
            "id": 7,
            "acronym": "VEN",
            "name": "Vendetta",
            "dtrelease": "2099-07-31 00:00:00"
          }]
        };
        </script>
        """

        self.assertEqual(updater.parse_editions_page(source, "riftbound"), [])
        editions = updater.parse_editions_page(
            source,
            "riftbound",
            include_future=True,
        )

        self.assertEqual([edition.acronym for edition in editions], ["VEN"])

    def test_extracts_cached_edition_id_from_note_or_source_url(self):
        self.assertEqual(
            updater.extract_cached_edition_id(
                {"note": "TCG=magic; coletado de FIN (Liga ID 1234)."}
            ),
            1234,
        )
        self.assertEqual(
            updater.extract_cached_edition_id(
                {
                    "source_url": (
                        "https://example.test/?view=cards%2Fsearch&"
                        "card=edid%3D987+ed%3DFIN"
                    )
                }
            ),
            987,
        )
        self.assertIsNone(updater.extract_cached_edition_id({}))

    def test_missing_editions_are_compared_by_liga_id_not_acronym(self):
        editions = [
            updater.LigaTcgEdition(
                game="yugioh",
                edition_id=1,
                acronym="VOL",
                name="Volume 1",
                release_date="2000-01-01",
                group="main",
            ),
            updater.LigaTcgEdition(
                game="yugioh",
                edition_id=2,
                acronym="VOL",
                name="Volume 2",
                release_date="2000-02-01",
                group="main",
            ),
        ]

        missing = updater.select_missing_editions(editions, {1})

        self.assertEqual([edition.edition_id for edition in missing], [2])


if __name__ == "__main__":
    unittest.main()
