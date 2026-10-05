import os
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "app" / "src"))
os.environ["BAMKING_TESTING"] = "1"

from main import app  # noqa: E402


class NumberApiTest(unittest.TestCase):
    def setUp(self):
        self.client = app.test_client()

    def test_health(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"status": "ok"})

    def test_spells_amount(self):
        response = self.client.post(
            "/getSpelledNum", json={"number": "1250", "is_amount": True}
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.get_json()["spelled_number"])

    def test_parses_digit_sequence_in_one_request(self):
        response = self.client.post(
            "/getDigits",
            json={"phrase": "kelen fila saba", "is_amount": False},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["digits"], "123")

    def test_rejects_empty_input(self):
        response = self.client.post(
            "/getDigits", json={"phrase": "", "is_amount": False}
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("error", response.get_json())


if __name__ == "__main__":
    unittest.main()
