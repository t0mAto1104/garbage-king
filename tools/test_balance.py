import unittest
from simulate_balance import validate_config, simulate, CANS, G

class ConfigTests(unittest.TestCase):
    def test_valid_config(self):
        validate_config()
    def test_price_bounds(self):
        self.assertGreater(G['replacement_delay_seconds'],0)
        self.assertGreater(G['base_stomp_cooldown_seconds'],G['minimum_stomp_cooldown_seconds'])
    def test_early_can_hps(self):
        self.assertEqual(CANS['red']['hp'],3)
        self.assertEqual(CANS['blue']['hp'],5)
        self.assertEqual(CANS['gold']['hp'],8)
    def test_guided_progress(self):
        s=simulate(duty=.4,seed=7)
        self.assertTrue(s['unlocks']['auto_stomper'])
        self.assertTrue(s['unlocks']['blue_can'])
        self.assertTrue(s['unlocks']['gold_can'])
        self.assertTrue(s['unlocks']['conveyor'])
        self.assertGreaterEqual(s['crushed'],200)
        self.assertGreaterEqual(s['wallet'],0)
    def test_casual_also_gets_auto(self):
        s=simulate(duty=.32,seed=7)
        self.assertTrue(s['unlocks']['auto_stomper'])
        self.assertGreaterEqual(s['wallet'],0)

if __name__=='__main__':
    unittest.main(verbosity=2)
