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


if __name__ == "__main__":
    unittest.main()
